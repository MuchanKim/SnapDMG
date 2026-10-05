import Foundation

enum ProjectJSON {
    static func data(iconSize: String? = "128", width: String = "540", height: String = "380",
                     appX: String = "180", appY: String = "190",
                     applicationsX: String = "360", applicationsY: String = "190") -> Data {
        let iconSizeField = iconSize.map { ", \"iconSize\": \($0)" } ?? ""
        return Data("""
        {
            "appName": "OtherApp",
            "windowSize": [\(width), \(height)],
            "backgroundImagePath": null,
            "iconPositions": {
                "app": [\(appX), \(appY)],
                "applications": [\(applicationsX), \(applicationsY)]
            }\(iconSizeField)
        }
        """.utf8)
    }
}
