import HotwireNative
import UIKit

/// Configures the web origin and the app-bound domain from the same build
/// settings the project and `make.sh` use, and refuses to start when they
/// disagree. A silent mismatch would load nothing and look like a network
/// failure.
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var navigator: Navigator?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        self.window = window

        do {
            let configuration = try Self.webConfiguration()
            let navigator = Navigator(
                configuration: .init(name: "main", startLocation: configuration.origin)
            )
            navigator.start()

            window.rootViewController = navigator.rootViewController
            self.navigator = navigator
        } catch {
            window.rootViewController = StartupErrorViewController(
                message: error.localizedDescription
            )
        }

        window.makeKeyAndVisible()
    }

    struct WebConfiguration {
        let origin: URL
        let appBoundDomain: String
    }

    enum ConfigurationError: LocalizedError {
        case missingOrigin
        case missingDomain
        case invalidOrigin(String)
        case domainMismatch(origin: String, domain: String)

        var errorDescription: String? {
            switch self {
            case .missingOrigin:
                return "Set WEB_ORIGIN to the HTTPS origin that serves the web application."
            case .missingDomain:
                return "Set APP_BOUND_DOMAIN to the hostname of WEB_ORIGIN (WKAppBoundDomains)."
            case let .invalidOrigin(value):
                return "WEB_ORIGIN is not a valid URL: \(value)"
            case let .domainMismatch(origin, domain):
                return "The web origin host does not match WKAppBoundDomains: \(origin) vs \(domain)."
            }
        }
    }

    /// Reads the origin from Info.plist (`HotwireRootURL`, expanded from
    /// `WEB_ORIGIN`) and requires the first `WKAppBoundDomains` entry to be its
    /// hostname.
    static func webConfiguration(bundle: Bundle = .main) throws -> WebConfiguration {
        guard
            let originValue = bundle.object(forInfoDictionaryKey: "HotwireRootURL") as? String,
            !originValue.isEmpty
        else {
            throw ConfigurationError.missingOrigin
        }

        guard let origin = URL(string: originValue), let host = origin.host else {
            throw ConfigurationError.invalidOrigin(originValue)
        }

        guard
            let domains = bundle.object(forInfoDictionaryKey: "WKAppBoundDomains") as? [String],
            let appBoundDomain = domains.first,
            !appBoundDomain.isEmpty
        else {
            throw ConfigurationError.missingDomain
        }

        guard host == appBoundDomain else {
            throw ConfigurationError.domainMismatch(origin: host, domain: appBoundDomain)
        }

        return WebConfiguration(origin: origin, appBoundDomain: appBoundDomain)
    }
}
