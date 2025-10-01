import Cocoa

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow!

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        createMenu()
        createMainWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    @objc private func showHelloAlert() {
        let alert = NSAlert()
        alert.messageText = "Nice to meet you!"
        alert.informativeText = "This is a native macOS window rendered with AppKit."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Cheers")
        alert.beginSheetModal(for: window) { _ in }
    }

    private func createMenu() {
        let mainMenu = NSMenu(title: "MainMenu")

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu(title: "Application")
        let appName = ProcessInfo.processInfo.processName
        appMenu.addItem(withTitle: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }

    private func createMainWindow() {
        let windowSize = NSRect(x: 0, y: 0, width: 520, height: 360)
        window = NSWindow(
            contentRect: windowSize,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Hello World"
        window.isReleasedWhenClosed = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true

        let contentRect = window.contentRect(forFrameRect: window.frame)
        let gradientView = GradientBackgroundView(frame: NSRect(origin: .zero, size: contentRect.size))
        gradientView.autoresizingMask = [.width, .height]
        window.contentView = gradientView

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.distribution = .gravityAreas
        stackView.spacing = 18
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "Hello, macOS!")
        titleLabel.font = NSFont.systemFont(ofSize: 34, weight: .bold)
        titleLabel.textColor = NSColor.white
        titleLabel.alignment = .center

        let subtitleLabel = NSTextField(labelWithString: "A native Swift app with a friendly face.")
        subtitleLabel.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        subtitleLabel.textColor = NSColor.white.withAlphaComponent(0.85)
        subtitleLabel.alignment = .center

        let button = NSButton(title: "Say hello back", target: self, action: #selector(showHelloAlert))
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        button.contentTintColor = .white
        button.wantsLayer = true
        if let layer = button.layer {
            layer.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.9).cgColor
            layer.cornerRadius = 10
            layer.masksToBounds = true
        }
        button.focusRingType = .none

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        stackView.addArrangedSubview(button)

        gradientView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: gradientView.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: gradientView.centerYAnchor),
            stackView.widthAnchor.constraint(lessThanOrEqualTo: gradientView.widthAnchor, multiplier: 0.8)
        ])

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private final class GradientBackgroundView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.29, green: 0.11, blue: 0.54, alpha: 1.0),
            NSColor.systemIndigo,
            NSColor.systemTeal
        ]) else {
            NSColor.windowBackgroundColor.setFill()
            dirtyRect.fill()
            return
        }

        gradient.draw(in: dirtyRect, angle: 90)

        let overlay = NSBezierPath(roundedRect: bounds.insetBy(dx: 24, dy: 24), xRadius: 24, yRadius: 24)
        NSColor.white.withAlphaComponent(0.08).setStroke()
        overlay.lineWidth = 2
        overlay.stroke()
    }
}
