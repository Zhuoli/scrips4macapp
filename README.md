# HelloWorldApp

A minimal but polished native macOS application written in Swift and AppKit. It opens a centered window with a gradient backdrop, friendly copy, and an interactive button that presents a sheeted welcome alert.

## Highlights
- Native AppKit window with a custom gradient background and rounded overlay
- Centered typography and a styled call-to-action button for a modern feel
- Sheet-based alert interaction to keep the experience inside the app window

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
./build.sh
```

The script compiles the Swift source, assembles an app bundle in `build/HelloWorldApp.app`, and prints the path when finished.

### Manual build

If you prefer the individual commands:

```bash
mkdir -p build/HelloWorldApp.app/Contents/MacOS
cp Resources/Info.plist build/HelloWorldApp.app/Contents/Info.plist
swiftc Sources/App/main.swift \
  -parse-as-library \
  -framework Cocoa \
  -o build/HelloWorldApp.app/Contents/MacOS/HelloWorldApp
```

## Launch

```bash
open build/HelloWorldApp.app
```

The window activates immediately with the gradient background. Click **Say hello back** to see the informational sheet.

## Project layout

```
.
├── README.md
├── Resources
│   └── Info.plist
├── Sources
│   └── App
│       └── main.swift
└── build.sh
```

Feel free to tweak the Swift code to experiment with additional controls or animations.
