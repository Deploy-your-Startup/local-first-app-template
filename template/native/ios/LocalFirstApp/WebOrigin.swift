import Foundation

/// Resolves the web origin the shell loads. The generated default lives in
/// Info.plist; development and tests can override it without rebuilding.
enum WebOrigin {
    static var url: URL {
        let environment = ProcessInfo.processInfo.environment["WEB_ORIGIN"]
        let configured = Bundle.main.object(forInfoDictionaryKey: "WebOrigin") as? String

        guard
            let value = environment ?? configured,
            let url = URL(string: value),
            let scheme = url.scheme,
            scheme == "https"
        else {
            fatalError("WebOrigin must be an https URL configured in Info.plist.")
        }

        return url
    }

    static var appTitle: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? "Local First App"
    }

    static var limitsNavigationsToAppBoundDomains: Bool {
        Bundle.main.object(forInfoDictionaryKey: "LimitToAppBoundDomains") as? Bool
            ?? false
    }
}
