import HotwireNative
import UIKit
import WebKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // WKWebView exposes service workers only when navigation is limited to
        // app-bound domains. The allowed hostname is configured in Info.plist
        // from the same origin the shell loads (see SceneDelegate).
        Hotwire.config.makeCustomWebView = { configuration in
            configuration.limitsNavigationsToAppBoundDomains = true
            return WKWebView(frame: .zero, configuration: configuration)
        }

        // Show a native "About" button on every web screen. This is the small
        // native navigation surface the shell owns.
        Hotwire.config.defaultViewController = { url in
            AppWebViewController(url: url)
        }

        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default", sessionRole: connectingSceneSession.role)
    }
}
