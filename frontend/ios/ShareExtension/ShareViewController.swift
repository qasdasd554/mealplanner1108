import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
  private let appGroup = "group.com.meal-planner-polska-v1"
  private let pendingUrlKey = "pending_recipe_url"
  private let statusLabel = UILabel()
  private let doneButton = UIButton(type: .system)

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground

    statusLabel.numberOfLines = 0
    statusLabel.textAlignment = .center
    statusLabel.font = .preferredFont(forTextStyle: .headline)
    statusLabel.text = "Odczytuję link…"

    doneButton.setTitle("Gotowe", for: .normal)
    doneButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
    doneButton.addTarget(self, action: #selector(finish), for: .touchUpInside)
    doneButton.isHidden = true

    let stack = UIStackView(arrangedSubviews: [statusLabel, doneButton])
    stack.axis = .vertical
    stack.alignment = .center
    stack.spacing = 24
    stack.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
      stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
    ])

    readSharedLink()
  }

  private func readSharedLink() {
    guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
      showResult("Nie otrzymano linku do przepisu.")
      return
    }
    let providers = items.flatMap { $0.attachments ?? [] }
    for type in [UTType.url.identifier, UTType.plainText.identifier] {
      if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(type) }) {
        provider.loadItem(forTypeIdentifier: type, options: nil) { [weak self] item, _ in
          let text = (item as? URL)?.absoluteString
            ?? (item as? String)
            ?? (item as? NSAttributedString)?.string
          DispatchQueue.main.async { self?.saveLink(from: text) }
        }
        return
      }
    }
    showResult("Udostępnij link do filmu lub strony z przepisem.")
  }

  private func saveLink(from text: String?) {
    guard let text,
          let range = text.range(of: #"https?://\S+"#, options: .regularExpression) else {
      showResult("Nie znaleziono adresu w udostępnionej treści.")
      return
    }
    let candidate = String(text[range]).trimmingCharacters(in: CharacterSet(charactersIn: ".,;!?)]}"))
    guard let url = URL(string: candidate),
          ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
          url.host != nil else {
      showResult("Udostępniony adres nie jest poprawnym linkiem.")
      return
    }
    guard let sharedDefaults = UserDefaults(suiteName: appGroup) else {
      showResult("Nie można zapisać linku. Sprawdź App Groups w ustawieniach podpisu aplikacji.")
      return
    }
    sharedDefaults.set(url.absoluteString, forKey: pendingUrlKey)
    showResult("Link zapisany. Otwórz Meal Planner Polska — rozpoznawanie przepisu ruszy automatycznie.")
  }

  private func showResult(_ message: String) {
    statusLabel.text = message
    doneButton.isHidden = false
  }

  @objc private func finish() {
    extensionContext?.completeRequest(returningItems: nil)
  }
}
