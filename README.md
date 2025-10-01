# HelloWorldApp

A minimal but polished native macOS application written in Swift and AppKit. It opens a centered window with a gradient backdrop and renders shell scripts as interactive panels so you can pass arguments without touching the Terminal. The long-term goal is to give shell scripts a friendly face by capturing their parameters in the UI and running the underlying commands for you.

## Highlights
- Native AppKit window with a custom gradient background and rounded overlay
- Two script panels that gather arguments, launch shell scripts, and stream output back in-place
- Bundled sample scripts so you can see end-to-end execution immediately

## Prerequisites
- macOS 10.15 (Catalina) or newer
- Xcode command-line tools (for `swiftc`)

Verify the compiler is available:

```bash
xcode-select --install   # if the command-line tools are missing
swiftc --version
```

## Build

### Quick start

```bash
./build.sh && open build/HelloWorldApp.app
```

The helper script compiles the Swift source, assembles an app bundle in `build/HelloWorldApp.app`, and immediately opens it when the build succeeds. Quit a previous run from the menu bar (`⌘Q`) before rebuilding.

### Manual build

If you prefer the individual commands:

```bash
mkdir -p build/HelloWorldApp.app/Contents/MacOS
cp Resources/Info.plist build/HelloWorldApp.app/Contents/Info.plist
swiftc Sources/App/main.swift \
  -parse-as-library \
  -framework Cocoa \
  -o build/HelloWorldApp.app/Contents/MacOS/HelloWorldApp
open build/HelloWorldApp.app
```

The window activates immediately with the gradient background and shows both script panels. Enter a value, then click **Run Script** to execute the matching shell helper.


## Included sample scripts

The `Scripts` directory ships with two Bash helpers that are bundled into the app automatically when you run `build.sh`:

- `whatsyourname.sh` — echoes back any name you type into the panel.
- `whatsyourdate.sh` — parses a date in `YYYY-MM-DD` format and formats it nicely (using macOS `date`).

At runtime the UI loads each script from `Contents/Resources/Scripts` and calls it with the argument captured from the text field.

### Add your own script
1. Drop your shell script into `Scripts/` and make sure it is executable (`chmod +x`).
2. Declare a new `ScriptDefinition` in `Sources/App/main.swift` with the script filename, prompt text, and placeholder.
3. Rebuild the app (`./build.sh && open build/HelloWorldApp.app`). The new panel appears automatically in the window.


## Project layout

```
.
├── README.md
├── Resources
│   └── Info.plist
├── Scripts
│   ├── whatsyourdate.sh
│   └── whatsyourname.sh
├── Sources
│   └── App
│       └── main.swift
└── build.sh
```

Feel free to tweak the Swift code to experiment with additional controls or animations.

## Wrap a shell command with UI inputs

The app is a natural place to surface parameters that would normally be typed into a shell script. The snippet below shows a lightweight pattern for turning a script like `backup.sh --source /tmp --dest /Volumes/Backup` into UI controls and running it through `Process` when the user clicks a button.

```swift
final class BackupViewController: NSViewController {
    private let sourceField = NSTextField(string: "/tmp")
    private let destinationField = NSTextField(string: "/Volumes/Backup")
    private let runButton = NSButton(title: "Run backup", target: nil, action: nil)
    private let outputTextView = NSTextView()

    override func loadView() {
        view = NSView()

        runButton.target = self
        runButton.action = #selector(runBackup)

        let form = NSStackView(views: [
            labeledRow(title: "Source", control: sourceField),
            labeledRow(title: "Destination", control: destinationField),
            runButton,
            outputTextView
        ])
        form.orientation = .vertical
        form.spacing = 12
        form.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(form)
        NSLayoutConstraint.activate([
            form.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            form.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            form.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            form.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -24)
        ])
    }

    private func labeledRow(title: String, control: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let stack = NSStackView(views: [label, control])
        stack.orientation = .horizontal
        stack.spacing = 12
        return stack
    }

    @objc private func runBackup() {
        let process = Process()
        process.launchPath = "/bin/bash"
        process.arguments = ["backup.sh", "--source", sourceField.stringValue, "--dest", destinationField.stringValue]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.outputTextView.string = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            }
        }

        do {
            try process.run()
        } catch {
            outputTextView.string = "Failed to launch: \(error.localizedDescription)"
        }
    }
}
```

The key steps are:
- Store each script argument in a UI control (text fields, popups, checkboxes, etc.).
- On submit, build the original argument list and launch the script using `Process`.
- Capture stdout/stderr through `Pipe` so you can render progress or errors directly in the app.

You can embed the `BackupViewController` inside the existing window or switch to SwiftUI if you prefer declarative layout.
