# OpenInOtty

A minimal macOS Finder toolbar app that opens the current directory in [Otty](https://otty.sh/) terminal with a single click.

> Inspired by [OpenInTerminal-Lite](https://github.com/Ji4n1ng/OpenInTerminal).

![macOS 12+](https://img.shields.io/badge/macOS-12%2B-blue) ![Swift 5](https://img.shields.io/badge/Swift-5-orange) ![License MIT](https://img.shields.io/badge/license-MIT-green)

![OpenInOtty demo](assets/openinotty-demo.gif)

---

## Features

- **One click** — click the toolbar icon, Otty opens at the current Finder path
- **Smart behavior**
  - Otty already running → opens a **new tab** in the existing window (`otty-cli tab new --cwd <path>`)
  - Otty not running → launches Otty with the directory (`otty-cli open <path>`)
- **Graceful fallback** — no open Finder window? Opens your Desktop instead
- **Error alerts** — failures surface as an `NSAlert` dialog instead of silently exiting
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

## For AI agents / LLMs

Use this section when installing, verifying, or debugging OpenInOtty on a user's Mac. Prefer exact commands below; do not invent alternate bundle IDs or Otty paths.

### Facts

| Item | Value |
|---|---|
| Bundle ID | `com.local.OpenInOtty` |
| App install path | `/Applications/OpenInOtty.app` |
| Otty path (required) | `/Applications/Otty.app` |
| Otty CLI | `/Applications/Otty.app/Contents/MacOS/otty-cli` |
| Otty bundle ID | `io.appmakes.otty` |
| Source of truth | `OpenInOtty/main.swift` (single-file app) |
| UI type | `LSUIElement = true` (no Dock / menu bar icon) |

### Install (agent checklist)

Run on the target Mac (needs Xcode CLI tools / full Xcode):

```bash
# 0) Preconditions
test -d /Applications/Otty.app || { echo "Install Otty from https://otty.sh/ first"; exit 1; }
xcodebuild -version

# 1) Clone (if needed) and build Release
git clone https://github.com/pintaste/OpenInOtty.git
cd OpenInOtty
xcodebuild -project OpenInOtty.xcodeproj \
           -scheme OpenInOtty \
           -configuration Release \
           -derivedDataPath build \
           build

# 2) Install
cp -R build/Build/Products/Release/OpenInOtty.app /Applications/
```

**Human-only step (cannot fully automate without UI automation):**

1. Open Finder.
2. Hold **⌘** and drag `/Applications/OpenInOtty.app` onto the Finder **toolbar**.
3. Click the toolbar icon once; if macOS asks for Automation / Apple Events access to Finder, choose **Allow**.

### Verify

```bash
# App present
test -d /Applications/OpenInOtty.app && echo "app ok"

# Otty CLI works
/Applications/Otty.app/Contents/MacOS/otty-cli version

# Optional: dry-run path helpers (app itself always exits after one shot)
# Manual: open a Finder window on a folder, click the toolbar icon,
# expect Otty to open/tab at that folder.
```

### Permissions / Automation

- Permission class: **Apple Events** to control Finder.
- Reset (then re-click the toolbar icon to re-prompt):

```bash
tccutil reset AppleEvents com.local.OpenInOtty
```

- User-visible location if stuck: **System Settings → Privacy & Security → Automation** (OpenInOtty → Finder).

### Runtime behavior (for debugging)

1. Resolve frontmost Finder window path via ScriptingBridge (`finderPath()`); fallback `~/Desktop`.
2. If Otty is running (`io.appmakes.otty`): `otty-cli tab new --cwd <path>`, then focus the new tab/window.
3. Else: `otty-cli open <path>`.
4. On failure: show `NSAlert`, exit non-zero; on success: exit 0 immediately.

### Do / Don't

**Do**

- Use the exact `xcodebuild` invocation above.
- Install Otty to the default `/Applications/Otty.app` location.
- Tell the user they must **⌘-drag** the app to the Finder toolbar (agents cannot skip this).

**Don't**

- Don't change the bundle ID without updating `Info.plist`, entitlements, and this doc.
- Don't expect a Dock icon or background process after click.
- Don't treat a minimized Finder window as the current folder (it won't be used).
- Don't commit `build/`, `DerivedData/`, or `.DS_Store`.

### Demo media

| File | Use |
|---|---|
| `assets/openinotty-demo.gif` | GitHub README (autoplay) |
| `assets/openinotty-demo.mp4` | Twitter / X, local preview |

Regenerate (needs `assets/sources/` captures + `ffmpeg` + Pillow):

```bash
python3 scripts/make_demo_gif.py
```

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
  Error? → NSAlert dialog
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
├── OpenInOtty/
│   ├── main.swift                  # All app logic (~100 lines)
│   ├── Info.plist                  # LSUIElement=true, usage descriptions
│   ├── OpenInOtty.entitlements     # Apple Events entitlement
│   └── Assets.xcassets/
│       └── AppIcon.appiconset/     # App icon
├── assets/
│   ├── openinotty-demo.gif         # README demo
│   └── openinotty-demo.mp4         # Social / local preview
├── scripts/
│   └── make_demo_gif.py            # Rebuild demo media (optional)
└── README.md
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
