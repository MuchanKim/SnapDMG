import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("release_metadata", Path(__file__).parents[1] / "release_metadata.py")
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseVersionTests(unittest.TestCase):
    def validate(self, tag="v1.1", version="1.1", build="2", existing=None, latest=None, previous_build="1"):
        feed = f'<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item><sparkle:version>{previous_build}</sparkle:version></item></channel></rss>'
        release.validate_version(tag, {"MARKETING_VERSION": version, "CURRENT_PROJECT_VERSION": build}, existing, latest, feed)

    def test_first_release_and_draft_can_be_published(self):
        self.validate(tag="v1.0", version="1.0", build="1", existing={"draft": True})

    def test_newer_version_and_build_can_update_existing_users(self):
        self.validate(latest={"tag_name": "v1.0"})

    def test_mismatched_tag_is_rejected(self):
        with self.assertRaises(ValueError):
            self.validate(tag="v1.2")

    def test_prerelease_is_rejected(self):
        with self.assertRaises(ValueError):
            self.validate(tag="v1.1-beta", version="1.1-beta")

    def test_published_release_is_immutable(self):
        with self.assertRaises(ValueError):
            self.validate(existing={"draft": False})

    def test_marketing_version_must_increase(self):
        with self.assertRaises(ValueError):
            self.validate(latest={"tag_name": "v1.1.0"})

    def test_build_number_must_increase_even_when_version_changes(self):
        with self.assertRaises(ValueError):
            self.validate(latest={"tag_name": "v1.0"}, previous_build="2")

    def test_build_number_requires_a_positive_integer(self):
        for build in ["0", "1.1", "-1"]:
            with self.subTest(build=build), self.assertRaises(ValueError):
                self.validate(build=build)


if __name__ == "__main__":
    unittest.main()
