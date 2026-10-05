"""Validate release boundaries and publish only verified update assets."""

import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

SPARKLE = "{http://www.andymatuschak.org/xml-namespaces/sparkle}"


def gh(*args):
    return subprocess.check_output(["gh", *args], text=True)


def release_info(repository, tag):
    result = subprocess.run(
        ["gh", "api", f"repos/{repository}/releases/{tag}"],
        text=True, capture_output=True,
    )
    if result.returncode:
        error = json.loads(result.stdout)
        if str(error.get("status")) == "404":
            return None
        raise RuntimeError(f"GitHub release lookup failed: {result.stderr.strip()}")
    return json.loads(result.stdout)


def version_tuple(version):
    if not re.fullmatch(r"[0-9]+\.[0-9]+(?:\.[0-9]+)?", version):
        raise ValueError("Use a stable version such as 1.0 or 1.0.1")
    parts = tuple(int(part) for part in version.split("."))
    return parts + (0,) * (3 - len(parts))


def validate_version(tag, settings, existing, latest, latest_feed):
    version = settings["MARKETING_VERSION"]
    version_tuple(version)
    if tag != f"v{version}":
        raise ValueError("Release tag must equal v + MARKETING_VERSION")
    build = settings["CURRENT_PROJECT_VERSION"]
    if not re.fullmatch(r"[1-9][0-9]*", build):
        raise ValueError("CURRENT_PROJECT_VERSION must be a positive integer")
    if existing and not existing["draft"]:
        raise ValueError("A published release cannot be overwritten")
    if latest:
        if version_tuple(version) <= version_tuple(latest["tag_name"].removeprefix("v")):
            raise ValueError("Release version must be newer than the latest release")
        versions = [int(item.text) for item in ET.fromstring(latest_feed).findall(f"./channel/item/{SPARKLE}version")]
        if not versions or int(build) <= max(versions):
            raise ValueError("Build number must be newer than the current Sparkle feed")


def prepare(tag, settings_path, release_dir):
    if not re.fullmatch(r"v[0-9]+\.[0-9]+(?:\.[0-9]+)?", tag):
        raise ValueError("Only stable release tags such as v1.0 are supported")
    tagged_sha = gh("api", f"repos/{os.environ['GITHUB_REPOSITORY']}/commits/{tag}")
    if json.loads(tagged_sha)["sha"] != gh_git_sha():
        raise ValueError("Checked-out source must match the release tag")
    settings = next(item["buildSettings"] for item in json.loads(Path(settings_path).read_text()) if item["target"] == "SnapDMG")
    repository = os.environ["GITHUB_REPOSITORY"]
    existing = release_info(repository, f"tags/{tag}")
    latest = release_info(repository, "latest")
    release_dir = Path(release_dir)
    release_dir.mkdir(parents=True, exist_ok=True)
    latest_feed = None
    if latest:
        gh("release", "download", latest["tag_name"], "--repo", repository,
           "--pattern", "appcast.xml", "--output", str(release_dir / "previous-appcast.xml"), "--clobber")
        latest_feed = (release_dir / "previous-appcast.xml").read_text()
    validate_version(tag, settings, existing, latest, latest_feed)
    metadata = {"version": settings["MARKETING_VERSION"], "build": settings["CURRENT_PROJECT_VERSION"],
                "team": settings["DEVELOPMENT_TEAM"], "sha": gh_git_sha(), "draft_id": existing["id"] if existing else None}
    (release_dir / "metadata.json").write_text(json.dumps(metadata))
    notes = existing.get("body") if existing else None
    if not notes:
        generated = json.loads(gh("api", "--method", "POST", f"repos/{repository}/releases/generate-notes",
                                  "-f", f"tag_name={tag}", "-f", f"target_commitish={metadata['sha']}"))
        notes = generated["body"]
    (release_dir / "release-notes.md").write_text(notes)
    print(f"Validated {tag}, build {metadata['build']}, commit {metadata['sha']}")


def gh_git_sha():
    return subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()


def verify(tag, release_dir, info_path):
    release_dir = Path(release_dir)
    metadata = json.loads((release_dir / "metadata.json").read_text())
    with open(info_path, "rb") as file:
        info = plistlib.load(file)
    repository = os.environ["GITHUB_REPOSITORY"]
    if (info["CFBundleShortVersionString"], info["CFBundleVersion"]) != (metadata["version"], metadata["build"]):
        raise ValueError("Exported app version does not match validated source settings")
    if info["SUFeedURL"] != f"https://github.com/{repository}/releases/latest/download/appcast.xml":
        raise ValueError("Exported app points to the wrong update feed")
    assets = release_dir / "assets"
    archive = assets / f"SnapDMG-{metadata['version']}.zip"
    items = ET.parse(assets / "appcast.xml").findall("./channel/item")
    if len(items) != 1:
        raise ValueError("Expected one release item in the generated feed")
    item = items[0]
    if item.findtext(f"{SPARKLE}version") != metadata["build"]:
        raise ValueError("Sparkle feed has the wrong build number")
    enclosure = item.find("enclosure")
    if enclosure.get("url") != f"https://github.com/{repository}/releases/download/{tag}/{archive.name}":
        raise ValueError("Sparkle feed has the wrong download URL")
    if int(enclosure.get("length")) != archive.stat().st_size:
        raise ValueError("Sparkle feed has the wrong ZIP length")
    subprocess.run(["swift", "-swift-version", "6", "scripts/verify-update.swift", info["SUPublicEDKey"],
                    enclosure.get(f"{SPARKLE}edSignature"), str(archive)], check=True)
    (release_dir / "verified.json").write_text(json.dumps({"sha": metadata["sha"], "tag": tag}))


def publish(tag, release_dir):
    release_dir = Path(release_dir)
    verified = json.loads((release_dir / "verified.json").read_text())
    metadata = json.loads((release_dir / "metadata.json").read_text())
    if verified != {"sha": gh_git_sha(), "tag": tag}:
        raise ValueError("Release verification does not match this tag and source")
    repository = os.environ["GITHUB_REPOSITORY"]
    existing = release_info(repository, f"tags/{tag}")
    if existing and not existing["draft"]:
        raise ValueError("A published release cannot be overwritten")
    if existing:
        if existing["id"] != metadata["draft_id"]:
            raise ValueError("Draft release changed while the workflow was running")
        gh("release", "edit", tag, "--repo", repository, "--notes-file", str(release_dir / "release-notes.md"))
    else:
        gh("release", "create", tag, "--repo", repository, "--verify-tag", "--draft",
           "--title", f"SnapDMG {metadata['version']}", "--notes-file", str(release_dir / "release-notes.md"))
    assets = release_dir / "assets"
    gh("release", "upload", tag, "--repo", repository, "--clobber",
       str(assets / f"SnapDMG-{metadata['version']}.zip"), str(assets / "appcast.xml"), str(assets / "SHA256SUMS"))
    gh("release", "edit", tag, "--repo", repository, "--draft=false", "--latest")
    print(f"Published https://github.com/{repository}/releases/tag/{tag}")


if __name__ == "__main__":
    commands = {"prepare": prepare, "verify": verify, "publish": publish}
    try:
        commands[sys.argv[1]](*sys.argv[2:])
    except (ValueError, RuntimeError) as error:
        raise SystemExit(str(error))
