import HotwireNative
import UIKit
import WebKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var navigator: Navigator?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let origin = WebOrigin.url

        Hotwire.config.applicationUserAgentPrefix = WebOrigin.appTitle
        Hotwire.config.backButtonDisplayMode = .minimal
        Hotwire.config.makeCustomWebView = { configuration in
            // WKWebView only exposes service workers to app-bound domains.
            // The allowed hosts are declared in Info.plist.
            configuration.limitsNavigationsToAppBoundDomains =
                WebOrigin.limitsNavigationsToAppBoundDomains

            let webView = WKWebView(frame: .zero, configuration: configuration)
            if #available(iOS 16.4, *) {
                webView.isInspectable = true
            }
            return webView
        }

        let navigator = Navigator(
            configuration: .init(name: WebOrigin.appTitle, startLocation: origin)
        )
        self.navigator = navigator
        navigator.start()

        if let root = navigator.rootViewController.viewControllers.first {
            root.navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "About",
                style: .plain,
                target: self,
                action: #selector(showAbout)
            )
        }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = navigator.rootViewController
        window.makeKeyAndVisible()
        self.window = window
    }

    @objc private func showAbout() {
        let about = WebOrigin.url.appendingPathComponent("about.html")
        navigator?.route(about, options: VisitOptions(action: .advance))
    }
}
