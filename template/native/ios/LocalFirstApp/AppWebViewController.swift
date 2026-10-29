import HotwireNative
import UIKit

/// Web screens keep Hotwire Navigation behaviour and add the one native
/// destination this shell owns.
final class AppWebViewController: HotwireWebViewController {
    private let aboutButton = UIBarButtonItem(title: "About", style: .plain, target: nil, action: nil)

    override func viewDidLoad() {
        super.viewDidLoad()

        aboutButton.target = self
        aboutButton.action = #selector(showAbout)
        aboutButton.accessibilityIdentifier = "about"
        navigationItem.rightBarButtonItem = aboutButton
    }

    @objc private func showAbout() {
        navigationController?.pushViewController(AboutViewController(), animated: true)
    }
}
