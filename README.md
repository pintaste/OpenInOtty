# OpenInOtty

[English](./README.md) | [中文](./README-zh.md)

A minimal macOS Finder toolbar app that opens the current directory in [Otty](https://otty.sh/) with a single click.

> Inspired by [OpenInTerminal-Lite](https://github.com/Ji4n1ng/OpenInTerminal).  
> If you already use OpenInTerminal and switch between several terminals, you can use upstream Otty support instead — see **OpenInOtty vs OpenInTerminal** below.

![macOS 12+](https://img.shields.io/badge/macOS-12%2B-blue) ![Swift 5](https://img.shields.io/badge/Swift-5-orange) ![License MIT](https://img.shields.io/badge/license-MIT-green)

![OpenInOtty demo](assets/openinotty-demo.gif)

---

## OpenInOtty vs OpenInTerminal

| Your situation | Use |
|---|---|
| **Otty only**, want the lightest one-click toolbar (new tab + focus when possible) | **OpenInOtty** (this project) |
| Already on **OpenInTerminal / Lite**, switching Terminal / iTerm / Ghostty / Otty, etc. | [OpenInTerminal](https://github.com/Ji4n1ng/OpenInTerminal) ([Otty support PR #276](https://github.com/Ji4n1ng/OpenInTerminal/pull/276)) |
| Both installed | Fine — they don’t conflict. This app is Otty-only; upstream is a multi-terminal suite |

In short:

- **OpenInOtty** = Otty remote (`otty-cli`: if Otty is running, open a new tab and focus it)
- **OpenInTerminal** = multi-app toolbox (`open -a Otty` works, but does not use Otty’s tab CLI)

---

## Features

- **One click** — toolbar icon opens Otty at the current Finder path
- **Smart path**
  - Selection → use selected item (if it’s a **file**, use the **parent folder**)
  - No selection → current Finder window folder
  - No usable window → Desktop
- **Smart Otty**
  - Otty already running → `otty-cli tab new --cwd <path>`, then match by cwd and `tab focus`
  - Otty not running → `otty-cli open <path>`
  - CLI missing or fails → fall back to `open -a <Otty.app> <path>` (Otty accepts folders as documents)
- **Find Otty by bundle id** — not hard-coded to `/Applications` only (Launch Services first, then default path)
- **Error alerts** — failures show an `NSAlert` instead of failing silently
- **No menu bar / Dock icon** — `LSUIElement = true`; quits right after dispatch

---

## Requirements

| Requirement | Version |
|---|---|
| macOS | 12.0 Monterey or later |
| Xcode | 15+ (free from the App Store) |
| [Otty](https://otty.sh/) | Any recent version |

Otty is usually at `/Applications/Otty.app`. Any location Launch Services can find is fine.

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

Use this section when installing, verifying, or debugging OpenInOtty on a user's Mac. Prefer exact commands below; do not invent alternate bundle IDs.

### Facts

| Item | Value |
|---|---|
| Bundle ID | `com.local.OpenInOtty` |
| App install path | `/Applications/OpenInOtty.app` |
| Otty discovery | `NSWorkspace.urlForApplication(withBundleIdentifier: "io.appmakes.otty")`, else `/Applications/Otty.app` |
| Otty CLI | `<Otty.app>/Contents/MacOS/otty-cli` (optional; falls back to `open -a`) |
| Otty bundle ID | `io.appmakes.otty` |
| Source of truth | `OpenInOtty/main.swift` (single-file app) |
| UI type | `LSUIElement = true` (no Dock / menu bar icon) |

### Install (agent checklist)

Run on the target Mac (needs Xcode CLI tools / full Xcode):

```bash
# 0) Preconditions — Otty via Launch Services or default path
mdfind "kMDItemCFBundleIdentifier == 'io.appmakes.otty'" | head -1
# or: test -d /Applications/Otty.app
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

# Otty discoverable
mdfind "kMDItemCFBundleIdentifier == 'io.appmakes.otty'" | head -1

# Otty CLI (if present)
CLI="$(mdfind "kMDItemCFBundleIdentifier == 'io.appmakes.otty'" | head -1)/Contents/MacOS/otty-cli"
test -x "$CLI" && "$CLI" version

# Manual: open a Finder window on a folder (or select a file), click the toolbar icon,
# expect Otty to open/tab at that folder (file → parent directory).
```

### Permissions / Automation

- Permission class: **Apple Events** to control Finder.
- Reset (then re-click the toolbar icon to re-prompt):

```bash
tccutil reset AppleEvents com.local.OpenInOtty
```

- User-visible location if stuck: **System Settings → Privacy & Security → Automation** (OpenInOtty → Finder).

### Runtime behavior (for debugging)

1. Resolve path via ScriptingBridge (`finderPath()`):
   - selection first (file → parent directory)
   - else front Finder window folder
   - else `~/Desktop`
2. Resolve Otty.app by bundle id, else `/Applications/Otty.app`.
3. If `otty-cli` exists:
   - Otty running → `tab new --cwd` → `tab list --json` match cwd → `tab focus <id>`
   - else → `otty-cli open <path>`
4. If CLI missing or fails → `/usr/bin/open -a <Otty.app> <path>`.
5. On total failure: `NSAlert`, exit non-zero; on success: exit 0 immediately.

### Do / Don't

**Do**

- Use the exact `xcodebuild` invocation above.
- Prefer discovering Otty by bundle id; don’t assume only `/Applications`.
- Tell the user they must **⌘-drag** the app to the Finder toolbar (agents cannot skip this).

**Don't**

- Don't change the bundle ID without updating `Info.plist`, entitlements, and this doc.
- Don't expect a Dock icon or background process after click.
- Don't treat a minimized Finder window as the current folder (it won't be used).
- Don't commit `build/`, `DerivedData/`, or `.DS_Store`.
- Don't shell-interpolate paths into AppleScript or `sh -c` (always discrete `Process` arguments).

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
  │ selection? → first item URL (file → parent dir)         │
  │ else FinderWindows → first window target URL            │
  │ else ~/Desktop                                          │
  └─────────────────────────────────────────────────────────┘
       │
       ▼
  resolve Otty.app (bundle id → default path)
       │
       ▼
  otty-cli available?
  ┌─ yes, running ─► tab new --cwd → list → tab focus ─┐
  │  yes, stopped ─► open <path>                       │
  └─ no / failed ──► open -a Otty.app <path> ──────────┤
                                                       ▼
                                              Error? → NSAlert
                                                       │
                                                     exit
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
│   ├── main.swift                  # All app logic
│   ├── Info.plist                  # LSUIElement=true, usage descriptions
│   ├── OpenInOtty.entitlements     # Apple Events entitlement
│   └── Assets.xcassets/
│       └── AppIcon.appiconset/     # App icon
├── assets/
│   ├── openinotty-demo.gif         # README demo
│   └── openinotty-demo.mp4         # Social / local preview
├── scripts/
│   └── make_demo_gif.py            # Rebuild demo media (optional)
├── README.md                       # English (default)
└── README-zh.md                    # Chinese
```

---

## Troubleshooting

**Nothing happens when I click the icon**

- Make sure Otty is installed (Spotlight / Launchpad is enough; `/Applications` is not required)
- Check **System Settings → Privacy & Security → Automation** (OpenInOtty → Finder)
- If the permission entry is missing: `tccutil reset AppleEvents com.local.OpenInOtty`, then click again

**Opens Desktop instead of the current folder**

- You need at least one non-minimized Finder window, or a selected file/folder

**Otty opens a new window instead of a tab**

- Otty was not running, or `otty-cli` was unavailable and the app fell back to `open -a`. Launch Otty once, then click the toolbar icon again for tab behavior.

---

## License

MIT — see [LICENSE](LICENSE).
