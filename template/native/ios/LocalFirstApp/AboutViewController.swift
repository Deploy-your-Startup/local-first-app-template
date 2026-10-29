import UIKit

/// The native destination used to prove native navigation and to show where
/// the web content comes from. Task data never passes through this screen.
final class AboutViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        title = "About"
        view.backgroundColor = .systemBackground

        let heading = UILabel()
        heading.text = "About this application"
        heading.font = .preferredFont(forTextStyle: .title2)
        heading.numberOfLines = 0

        let name = UILabel()
        name.text = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        name.font = .preferredFont(forTextStyle: .headline)
        name.numberOfLines = 0

        let origin = UILabel()
        let rootURL = Bundle.main.object(forInfoDictionaryKey: "HotwireRootURL") as? String ?? ""
        origin.text = "Web content: \(rootURL)"
        origin.font = .preferredFont(forTextStyle: .footnote)
        origin.numberOfLines = 0
        origin.accessibilityIdentifier = "web-origin"

        let storage = UILabel()
        storage.text = "The web runtime stores tasks in this app's WKWebView. This screen is native navigation only."
        storage.font = .preferredFont(forTextStyle: .body)
        storage.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [heading, name, origin, storage])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
        ])
    }
}

/// Shown instead of the web view when the configured origin and the allowed
/// domain disagree, so a misconfiguration is visible rather than blank.
final class StartupErrorViewController: UIViewController {
    private let message: String

    init(message: String) {
        self.message = message
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        let label = UILabel()
        label.text = "Configuration error\n\n\(message)"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.accessibilityIdentifier = "configuration-error"

        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -24),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
    }
}
