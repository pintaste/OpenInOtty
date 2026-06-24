// main.swift
// OpenInOtty — Finder toolbar app that opens current directory in Otty

import Cocoa
import ScriptingBridge

// MARK: - Get current Finder directory
//
// ScriptingBridge returns SBScriptableApplication (a private subclass of SBApplication).
// Swift's @objc optional protocol calls use respondsToSelector: first, which returns
// false for ScriptingBridge's dynamically-forwarded methods. We bypass this by using
// perform(_:) to send the ObjC message directly, letting ScriptingBridge forward it
// as an Apple Event — which is what triggers the TCC permission dialog.

func finderPath() -> String {
    let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)
        .first?.path ?? NSHomeDirectory() + "/Desktop"

    guard let app = SBApplication(bundleIdentifier: "com.apple.Finder") else { return desktop }

    // Bypass respondsToSelector: — send directly, ScriptingBridge will forward via Apple Event
    guard let windows = app.perform(NSSelectorFromString("FinderWindows"))?
                           .takeUnretainedValue() as? SBElementArray,
          windows.count > 0,
          let firstWindow = windows.firstObject as? NSObject,
          let target = firstWindow.value(forKey: "target") as? SBObject,
          let item = target.get() as? NSObject,
          let urlStr = item.value(forKey: "URL") as? String,
          let url = URL(string: urlStr)
    else { return desktop }

    return url.path
}

@discardableResult
func otty(_ args: [String]) -> (output: String, status: Int32) {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/Applications/Otty.app/Contents/MacOS/otty-cli")
    p.arguments = args
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = pipe
    try? p.run()
    p.waitUntilExit()
    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    return (output, p.terminationStatus)
}

// MARK: - Show user-visible error via notification

func notifyError(_ message: String) {
    let notif = NSUserNotification()
    notif.title = "OpenInOtty"
    notif.informativeText = message
    NSUserNotificationCenter.default.deliver(notif)
}

// MARK: - Launch Otty

let path = finderPath()
let ottyCliPath = "/Applications/Otty.app/Contents/MacOS/otty-cli"

guard FileManager.default.fileExists(atPath: ottyCliPath) else {
    notifyError("Otty 未找到，请从 otty.sh 下载安装")
    exit(1)
}

let isRunning = NSWorkspace.shared.runningApplications
    .contains { $0.bundleIdentifier == "io.appmakes.otty" }

if isRunning {
    // Create tab in the current window
    let (_, tabStatus) = otty(["tab", "new", "--cwd", path])
    guard tabStatus == 0 else {
        notifyError("无法在 Otty 中创建新标签页")
        exit(1)
    }

    // Find the newly created tab: it has the highest index among all tabs
    // (new tabs are appended, so max index == just-created tab)
    let (json, _) = otty(["tab", "list", "--json"])
    if let data = json.data(using: .utf8),
       let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let tabs = root["data"] as? [[String: Any]] {
        let newTab = tabs.max { ($0["index"] as? Int ?? 0) < ($1["index"] as? Int ?? 0) }
        if let windowId = newTab?["window_id"] as? String {
            otty(["window", "focus", windowId])
        }
    }

    NSWorkspace.shared.runningApplications
        .first { $0.bundleIdentifier == "io.appmakes.otty" }?
        .activate(options: .activateIgnoringOtherApps)
} else {
    otty(["open", path])
}
