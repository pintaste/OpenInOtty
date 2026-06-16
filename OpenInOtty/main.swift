// main.swift
// OpenInOtty — Finder toolbar app that opens current directory in Otty

import Cocoa
import ScriptingBridge

// MARK: - Constants

private let ottyBundleId = "io.appmakes.otty"
private let ottyCliName = "otty-cli"
private let defaultOttyAppPath = "/Applications/Otty.app"

// MARK: - Otty location

/// Prefer Launch Services (bundle id), then the default install path.
func resolveOttyAppURL() -> URL? {
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: ottyBundleId) {
        return url
    }
    let fallback = URL(fileURLWithPath: defaultOttyAppPath)
    return FileManager.default.fileExists(atPath: fallback.path) ? fallback : nil
}

func resolveOttyCLIURL() -> URL? {
    guard let appURL = resolveOttyAppURL() else { return nil }
    let cli = appURL.appendingPathComponent("Contents/MacOS/\(ottyCliName)")
    return FileManager.default.fileExists(atPath: cli.path) ? cli : nil
}

// MARK: - Finder path
//
// ScriptingBridge returns SBScriptableApplication (a private subclass of SBApplication).
// Swift's @objc optional protocol calls use respondsToSelector: first, which returns
// false for ScriptingBridge's dynamically-forwarded methods. We bypass this by using
// perform(_:) to send the ObjC message directly, letting ScriptingBridge forward it
// as an Apple Event — which is what triggers the TCC permission dialog.

func desktopPath() -> String {
    FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)
        .first?.path ?? NSHomeDirectory() + "/Desktop"
}

/// If the URL is a file, return its parent directory; if a folder, return itself.
func directoryPath(from url: URL) -> String {
    var isDirectory: ObjCBool = false
    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
       !isDirectory.boolValue {
        return url.deletingLastPathComponent().path
    }
    return url.path
}

func urlFromFinderItem(_ item: NSObject) -> URL? {
    if let urlStr = item.value(forKey: "URL") as? String, let url = URL(string: urlStr) {
        return url
    }
    // Some items need an extra get() to resolve the SBObject proxy.
    if let resolved = (item as? SBObject)?.get() as? NSObject,
       let urlStr = resolved.value(forKey: "URL") as? String,
       let url = URL(string: urlStr) {
        return url
    }
    return nil
}

func finderItems(from raw: Any?) -> [NSObject] {
    if let arr = raw as? [NSObject] { return arr }
    if let nsa = raw as? NSArray { return nsa.compactMap { $0 as? NSObject } }
    if let sb = raw as? SBElementArray {
        return (0..<sb.count).compactMap { sb.object(at: $0) as? NSObject }
    }
    return []
}

/// Selection first (file → parent), then front Finder window, then Desktop.
func finderPath() -> String {
    let desktop = desktopPath()
    guard let app = SBApplication(bundleIdentifier: "com.apple.Finder") else { return desktop }

    // 1) Selected items (OpenInTerminal-style)
    if let selection = app.perform(NSSelectorFromString("selection"))?
        .takeUnretainedValue() as? SBObject {
        let items = finderItems(from: selection.get())
        if let first = items.first, let url = urlFromFinderItem(first) {
            return directoryPath(from: url)
        }
    }

    // 2) Frontmost Finder window target
    if let windows = app.perform(NSSelectorFromString("FinderWindows"))?
        .takeUnretainedValue() as? SBElementArray,
       windows.count > 0,
       let firstWindow = windows.firstObject as? NSObject,
       let target = firstWindow.value(forKey: "target") as? SBObject,
       let item = target.get() as? NSObject,
       let url = urlFromFinderItem(item) {
        return directoryPath(from: url)
    }

    return desktop
}

// MARK: - Process helpers

@discardableResult
func runProcess(executable: URL, arguments: [String]) -> (output: String, status: Int32) {
    let p = Process()
    p.executableURL = executable
    p.arguments = arguments
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = pipe
    do {
        try p.run()
    } catch {
        return ("", 1)
    }
    p.waitUntilExit()
    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return (output, p.terminationStatus)
}

func ottyCLI(_ cli: URL, _ args: [String]) -> (output: String, status: Int32) {
    runProcess(executable: cli, arguments: args)
}

/// Launch Services fallback — same injection-safe discrete args as OpenInTerminal.
func openOttyViaLaunchServices(appURL: URL, path: String) -> Bool {
    let result = runProcess(
        executable: URL(fileURLWithPath: "/usr/bin/open"),
        arguments: ["-a", appURL.path, path]
    )
    return result.status == 0
}

func activateOtty() {
    let ottyApp = NSWorkspace.shared.runningApplications
        .first { $0.bundleIdentifier == ottyBundleId }
    if #available(macOS 14.0, *) {
        ottyApp?.activate()
    } else {
        ottyApp?.activate(options: .activateIgnoringOtherApps)
    }
}

func isOttyRunning() -> Bool {
    NSWorkspace.shared.runningApplications
        .contains { $0.bundleIdentifier == ottyBundleId }
}

// MARK: - Focus after tab new
//
// `tab new --json` only returns a success string, not a tab id. We list tabs and
// prefer a cwd match (most reliable), then fall back to highest index.

struct OttyTab {
    let id: String
    let index: Int
    let cwd: String
    let windowId: String?
}

func parseTabs(from jsonText: String) -> [OttyTab] {
    guard let data = jsonText.data(using: .utf8),
          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let rows = root["data"] as? [[String: Any]] else {
        return []
    }
    return rows.compactMap { row in
        guard let id = row["id"] as? String else { return nil }
        let index = row["index"] as? Int ?? 0
        let cwd = row["cwd"] as? String ?? ""
        let windowId = row["window_id"] as? String
        return OttyTab(id: id, index: index, cwd: cwd, windowId: windowId)
    }
}

func normalizedPath(_ path: String) -> String {
    // Resolve /tmp → /private/tmp etc. so Finder paths match Otty's reported cwd.
    URL(fileURLWithPath: path).resolvingSymlinksInPath().path
}

/// Pick the tab we just created: same cwd preferred; otherwise highest index.
func pickNewTab(tabs: [OttyTab], path: String) -> OttyTab? {
    let want = normalizedPath(path)
    let byCwd = tabs.filter { normalizedPath($0.cwd) == want }
    if let best = byCwd.max(by: { $0.index < $1.index }) {
        return best
    }
    return tabs.max(by: { $0.index < $1.index })
}

func focusTab(cli: URL, tab: OttyTab) {
    // Prefer tab focus by id (activates the right tab + window).
    let focus = ottyCLI(cli, ["tab", "focus", tab.id, "-q"])
    if focus.status == 0 { return }
    if let windowId = tab.windowId {
        _ = ottyCLI(cli, ["window", "focus", windowId, "-q"])
    }
}

// MARK: - Errors

func notifyError(_ message: String) {
    let alert = NSAlert()
    alert.messageText = "OpenInOtty"
    alert.informativeText = message
    alert.alertStyle = .warning
    alert.runModal()
}

// MARK: - Main

let path = finderPath()

guard let appURL = resolveOttyAppURL() else {
    notifyError("找不到 Otty。请从 https://otty.sh/ 安装后重试（支持 /Applications 或其它 Launch Services 可发现的位置）。")
    exit(1)
}

let cliURL = resolveOttyCLIURL()

/// Try CLI first (better tab UX). On any failure, fall back to `open -a Otty.app <path>`.
func openPathInOtty(path: String, appURL: URL, cliURL: URL?) -> Bool {
    if let cli = cliURL {
        if isOttyRunning() {
            let (_, tabStatus) = ottyCLI(cli, ["tab", "new", "--cwd", path, "-q"])
            if tabStatus == 0 {
                let (listJSON, _) = ottyCLI(cli, ["tab", "list", "--json", "-q"])
                if let tab = pickNewTab(tabs: parseTabs(from: listJSON), path: path) {
                    focusTab(cli: cli, tab: tab)
                }
                activateOtty()
                return true
            }
            // tab new failed — try CLI open window, then Launch Services
            let (_, openStatus) = ottyCLI(cli, ["open", path, "-q"])
            if openStatus == 0 {
                activateOtty()
                return true
            }
        } else {
            let (_, openStatus) = ottyCLI(cli, ["open", path, "-q"])
            if openStatus == 0 { return true }
        }
    }

    // Fallback: Launch Services (works because Otty registers public.folder)
    if openOttyViaLaunchServices(appURL: appURL, path: path) {
        activateOtty()
        return true
    }
    return false
}

if openPathInOtty(path: path, appURL: appURL, cliURL: cliURL) {
    exit(0)
}

var detail = "无法在 Otty 中打开：\n\(path)"
if cliURL == nil {
    detail += "\n\n未找到 otty-cli，且 open -a 也失败了。请确认 Otty 安装完整。"
} else {
    detail += "\n\n若刚拒绝过权限：系统设置 → 隐私与安全性 → 自动化 → OpenInOtty → Finder。\n也可运行：tccutil reset AppleEvents com.local.OpenInOtty"
}
notifyError(detail)
exit(1)
