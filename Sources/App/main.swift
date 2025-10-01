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
        let windowSize = NSRect(x: 0, y: 0, width: 720, height: 440)
        window = NSWindow(
            contentRect: windowSize,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Script Panels"
        window.isReleasedWhenClosed = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true

        let contentRect = window.contentRect(forFrameRect: window.frame)
        let gradientView = GradientBackgroundView(frame: NSRect(origin: .zero, size: contentRect.size))
        gradientView.autoresizingMask = [.width, .height]
        window.contentView = gradientView

        let rootStack = NSStackView()
        rootStack.orientation = .vertical
        rootStack.alignment = .centerX
        rootStack.spacing = 28
        rootStack.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "Shell Scripts, Now with UI")
        titleLabel.font = NSFont.systemFont(ofSize: 30, weight: .bold)
        titleLabel.textColor = NSColor.white
        titleLabel.alignment = .center

        let subtitleLabel = NSTextField(labelWithString: "Each panel wraps a script and collects its argument for you.")
        subtitleLabel.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        subtitleLabel.textColor = NSColor.white.withAlphaComponent(0.85)
        subtitleLabel.alignment = .center

        let panelsStack = NSStackView()
        panelsStack.orientation = .horizontal
        panelsStack.alignment = .centerY
        panelsStack.distribution = .fillEqually
        panelsStack.spacing = 20
        panelsStack.translatesAutoresizingMaskIntoConstraints = false

        let scripts = [
            ScriptDefinition(
                title: "What's Your Name?",
                detail: "Echoes the name you provide via `whatsyourname.sh`.",
                resourceFilename: "whatsyourname.sh",
                parameterPrompt: "Enter your name",
                placeholder: "Ada"
            ),
            ScriptDefinition(
                title: "What's Your Date?",
                detail: "Prints a friendly message for the supplied date using `whatsyourdate.sh`.",
                resourceFilename: "whatsyourdate.sh",
                parameterPrompt: "Enter a date",
                placeholder: "2024-12-31"
            )
        ]

        for script in scripts {
            let panel = ScriptPanelView(definition: script)
            panelsStack.addArrangedSubview(panel)
        }

        rootStack.addArrangedSubview(titleLabel)
        rootStack.addArrangedSubview(subtitleLabel)
        rootStack.addArrangedSubview(panelsStack)

        gradientView.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.centerXAnchor.constraint(equalTo: gradientView.centerXAnchor),
            rootStack.centerYAnchor.constraint(equalTo: gradientView.centerYAnchor),
            rootStack.widthAnchor.constraint(lessThanOrEqualTo: gradientView.widthAnchor, multiplier: 0.88),
            panelsStack.widthAnchor.constraint(equalTo: rootStack.widthAnchor)
        ])

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct ScriptDefinition {
    let title: String
    let detail: String
    let resourceFilename: String
    let parameterPrompt: String
    let placeholder: String

    func scriptURL() -> URL? {
        Bundle.main.url(forResource: resourceFilename, withExtension: nil, subdirectory: "Scripts")
    }
}

private final class ScriptPanelView: NSView {
    private let definition: ScriptDefinition
    private let parameterField = NSTextField()
    private let outputTextView = NSTextView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let runButton = NSButton(title: "Run Script", target: nil, action: nil)
    private var activePipe: Pipe?

    init(definition: ScriptDefinition) {
        self.definition = definition
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        layer?.cornerRadius = 18
        layer?.backgroundColor = NSColor(calibratedWhite: 1.0, alpha: 0.1).cgColor
        layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        layer?.borderWidth = 1.0
        setupSubviews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupSubviews() {
        let title = NSTextField(labelWithString: definition.title)
        title.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        title.textColor = NSColor.white

        let detail = NSTextField(labelWithString: definition.detail)
        detail.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        detail.textColor = NSColor.white.withAlphaComponent(0.75)
        detail.lineBreakMode = .byWordWrapping
        detail.maximumNumberOfLines = 0

        parameterField.placeholderString = definition.placeholder
        parameterField.isBordered = false
        parameterField.isBezeled = false
        parameterField.wantsLayer = true
        parameterField.layer?.cornerRadius = 8
        parameterField.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.18).cgColor
        parameterField.backgroundColor = .clear
        parameterField.textColor = NSColor.white
        parameterField.font = NSFont.systemFont(ofSize: 14)
        parameterField.lineBreakMode = .byTruncatingTail
        parameterField.drawsBackground = false
        parameterField.focusRingType = .none
        parameterField.placeholderAttributedString = NSAttributedString(string: definition.placeholder, attributes: [.foregroundColor: NSColor.white.withAlphaComponent(0.6)])

        let promptLabel = NSTextField(labelWithString: definition.parameterPrompt)
        promptLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        promptLabel.textColor = NSColor.white.withAlphaComponent(0.9)

        runButton.target = self
        runButton.action = #selector(runScript)
        runButton.bezelStyle = .rounded
        runButton.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        runButton.contentTintColor = .white
        runButton.wantsLayer = true
        runButton.layer?.backgroundColor = NSColor.systemBlue.cgColor
        runButton.layer?.cornerRadius = 10
        runButton.layer?.masksToBounds = true
        runButton.focusRingType = .none

        statusLabel.textColor = NSColor.white.withAlphaComponent(0.75)
        statusLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        statusLabel.lineBreakMode = .byTruncatingTail

        outputTextView.isEditable = false
        outputTextView.isSelectable = true
        outputTextView.drawsBackground = false
        outputTextView.textColor = NSColor.white
        outputTextView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        outputTextView.isVerticallyResizable = true
        outputTextView.isHorizontallyResizable = false
        outputTextView.textContainer?.widthTracksTextView = true
        outputTextView.translatesAutoresizingMaskIntoConstraints = false
        outputTextView.string = "Waiting to run."

        let outputScrollView = NSScrollView()
        outputScrollView.translatesAutoresizingMaskIntoConstraints = false
        outputScrollView.drawsBackground = false
        outputScrollView.hasVerticalScroller = true
        outputScrollView.documentView = outputTextView
        outputScrollView.contentView.backgroundColor = .clear
        outputScrollView.borderType = .noBorder

        let controlsStack = NSStackView(views: [promptLabel, parameterField, runButton])
        controlsStack.orientation = .vertical
        controlsStack.spacing = 10
        controlsStack.alignment = .leading

        let stack = NSStackView(views: [title, detail, controlsStack, statusLabel, outputScrollView])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            outputScrollView.heightAnchor.constraint(equalToConstant: 110),
            parameterField.widthAnchor.constraint(greaterThanOrEqualToConstant: 200)
        ])
    }

    private func appendOutput(_ text: String) {
        guard !text.isEmpty else { return }
        if outputTextView.string.isEmpty {
            outputTextView.string = text
        } else {
            outputTextView.string += text
        }
        outputTextView.scrollToEndOfDocument(nil)
    }

    @objc private func runScript() {
        guard let scriptURL = definition.scriptURL() else {
            statusLabel.stringValue = "Script not found in bundle."
            outputTextView.string = ""
            return
        }

        let argument = parameterField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !argument.isEmpty else {
            statusLabel.stringValue = "Enter a value before running."
            return
        }

        runButton.isEnabled = false
        statusLabel.stringValue = "Running…"
        outputTextView.string = ""
        if let existingPipe = activePipe {
            existingPipe.fileHandleForReading.readabilityHandler = nil
            existingPipe.fileHandleForReading.closeFile()
        }
        activePipe = nil

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptURL.path, argument]

        let pipe = Pipe()
        activePipe = pipe
        process.standardOutput = pipe
        process.standardError = pipe

        let fileHandle = pipe.fileHandleForReading
        fileHandle.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            if let chunk = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    self?.appendOutput(chunk)
                }
            }
        }

        process.terminationHandler = { [weak self] process in
            fileHandle.readabilityHandler = nil
            fileHandle.closeFile()
            DispatchQueue.main.async {
                guard let self else { return }
                self.activePipe = nil
                self.runButton.isEnabled = true
                let exitStatus = process.terminationStatus
                self.statusLabel.stringValue = exitStatus == 0 ? "Finished with status 0." : "Exited with status \(exitStatus)."
                if self.outputTextView.string.isEmpty {
                    self.outputTextView.string = "(no output)"
                }
            }
        }

        do {
            try process.run()
        } catch {
            activePipe = nil
            runButton.isEnabled = true
            statusLabel.stringValue = "Failed: \(error.localizedDescription)"
            outputTextView.string = "Failed to launch script."
        }
    }
}

private final class GradientBackgroundView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let gradient = NSGradient(colors: [
            NSColor(calibratedRed: 0.24, green: 0.09, blue: 0.49, alpha: 1.0),
            NSColor.systemIndigo,
            NSColor.systemTeal
        ]) else {
            NSColor.windowBackgroundColor.setFill()
            dirtyRect.fill()
            return
        }

        gradient.draw(in: dirtyRect, angle: 100)

        let overlay = NSBezierPath(roundedRect: bounds.insetBy(dx: 20, dy: 20), xRadius: 24, yRadius: 24)
        NSColor.white.withAlphaComponent(0.08).setStroke()
        overlay.lineWidth = 2
        overlay.stroke()
    }
}
