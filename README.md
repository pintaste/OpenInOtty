# OpenInOtty

A minimal macOS Finder toolbar app that opens the current directory in [Otty](https://otty.sh/) terminal with a single click.

> Inspired by [OpenInTerminal-Lite](https://github.com/Ji4n1ng/OpenInTerminal).

![macOS 12+](https://img.shields.io/badge/macOS-12%2B-blue) ![Swift 5](https://img.shields.io/badge/Swift-5-orange) ![License MIT](https://img.shields.io/badge/license-MIT-green)

---

## Features

- **One click** — click the toolbar icon, Otty opens at the current Finder path
- **Smart behavior**
  - Otty already running → opens a **new tab** in the existing window (`otty-cli tab new --cwd <path>`)
  - Otty not running → launches Otty with the directory (`otty-cli open <path>`)
- **Graceful fallback** — no open Finder window? Opens your Desktop instead
- **No menu bar / Dock icon** — pure toolbar utility (`LSUIElement = true`)
- Quits immediately after dispatching the command (zero background footprint)

---

## Requirements

| Requirement | Version |
|---|---|
| macOS | 12.0 Monterey or later |
| Xcode | 15+ (free from the App Store) |
| [Otty](https://otty.sh/) | Any recent version |

Otty must be installed at `/Applications/Otty.app` (the default location).

---

## Installation

### Option A — Build from source

1. Clone the repo:
   ```bash
   git clone https://github.com/pintaste/OpenInOtty.git
   cd OpenInOtty
   ```

2. Build a Release binary:
   ```bash
   xcodebuild -project OpenInOtty.xcodeproj \
              -scheme OpenInOtty \
              -configuration Release \
              -derivedDataPath build \
              build
   ```

3. Copy to Applications:
   ```bash
   cp -R build/Build/Products/Release/OpenInOtty.app /Applications/
   ```

   Or open `OpenInOtty.xcodeproj` in Xcode, choose **Product → Archive**, and export manually.

### Add to Finder toolbar

Hold **⌘ (Command)** and drag `/Applications/OpenInOtty.app` into the Finder toolbar.

The first time you click the icon, macOS will show an Apple Events permission dialog — click **Allow** to grant Finder access.

### Reset permissions (if you accidentally denied)

```bash
tccutil reset AppleEvents com.local.OpenInOtty
```

Then click the toolbar icon again to re-trigger the prompt.

---

## How It Works

The app is a single Swift file (`main.swift`) — no AppDelegate, no event loop.

```
Click toolbar icon
       │
       ▼
  finderPath()
  ┌─────────────────────────────────────────────────────────┐
  │ SBApplication(bundleIdentifier: "com.apple.Finder")     │
  │ perform(NSSelectorFromString("FinderWindows"))           │
  │   → first window → target → URL → file path             │
  │   → fallback: ~/Desktop                                 │
  └─────────────────────────────────────────────────────────┘
       │
       ▼
  Is Otty running?
  ┌─────────────┬──────────────────────────────────────┐
  │     YES     │  otty-cli tab new --cwd <path>        │
  │     NO      │  otty-cli open <path>                 │
  └─────────────┴──────────────────────────────────────┘
       │
       ▼
    exit(0)
```

**Why `perform(NSSelectorFromString:)` instead of a ScriptingBridge protocol?**

Swift's `@objc optional` protocol calls check `respondsToSelector:` first. ScriptingBridge's private `SBScriptableApplication` subclass returns `false` for dynamically-forwarded Apple Event methods, so every call silently returned `nil` — and critically, the TCC permission dialog never appeared. Using `perform()` bypasses the selector check and lets ScriptingBridge forward the message as a proper Apple Event.

---

## Project Structure

```
OpenInOtty/
├── OpenInOtty.xcodeproj/
│   └── project.pbxproj
└── OpenInOtty/
    ├── main.swift                  # All app logic (~50 lines)
    ├── Info.plist                  # LSUIElement=true, usage descriptions
    ├── OpenInOtty.entitlements     # Apple Events entitlement
    └── Assets.xcassets/
        └── AppIcon.appiconset/     # App icon
```

---

## Troubleshooting

**Nothing happens when I click the icon**

- Make sure Otty is installed at `/Applications/Otty.app`
- Check that you've granted Apple Events permission in **System Settings → Privacy & Security → Automation**
- If the permission entry is missing, run `tccutil reset AppleEvents com.local.OpenInOtty` and click again

**Opens Desktop instead of the current folder**

- You need at least one Finder window open. A minimized window does not count.

---

## License

MIT — see [LICENSE](LICENSE).
