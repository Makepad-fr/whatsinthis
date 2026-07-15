import Foundation

enum OpenPanelAnalytics {
    private static let apiURL = URL(string: "https://analytics.makepad.fr/api/track")!
    private static let clientId = "9984265b-caf4-4fb8-bb4b-6b412a80a29b"
    private static let origin = "https://ios.whatsinthis.makepad.fr"

    static func trackAppOpened() {
        track("app_opened")
    }

    static func trackAppClosed() {
        track("app_closed")
    }

    static func track(_ name: String, properties: [String: String] = [:]) {
        guard !isDisabled else {
            return
        }

        var eventProperties = defaultProperties()
        properties.forEach { key, value in
            eventProperties[key] = value
        }

        let body: [String: Any] = [
            "type": "track",
            "payload": [
                "name": name,
                "properties": eventProperties,
            ],
        ]

        guard JSONSerialization.isValidJSONObject(body),
              let bodyData = try? JSONSerialization.data(withJSONObject: body)
        else {
            return
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 5
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(clientId, forHTTPHeaderField: "openpanel-client-id")
        request.setValue("makepad-ios", forHTTPHeaderField: "openpanel-sdk-name")
        request.setValue("1", forHTTPHeaderField: "openpanel-sdk-version")
        request.setValue(origin, forHTTPHeaderField: "Origin")

        URLSession.shared.dataTask(with: request).resume()
    }

    private static var isDisabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-disableOpenPanelAnalytics") ||
            ProcessInfo.processInfo.environment["DISABLE_OPENPANEL_ANALYTICS"] == "1"
    }

    private static func defaultProperties() -> [String: String] {
        let info = Bundle.main.infoDictionary ?? [:]
        return [
            "app": "whatsinthis-ios",
            "platform": "ios",
            "app_version": info["CFBundleShortVersionString"] as? String ?? "unknown",
            "app_build": info["CFBundleVersion"] as? String ?? "unknown",
        ]
    }
}
