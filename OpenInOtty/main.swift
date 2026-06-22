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

// MARK: - Launch Otty

let path = finderPath()
let ottyCliPath = "/Applications/Otty.app/Contents/MacOS/otty-cli"

guard FileManager.default.fileExists(atPath: ottyCliPath) else { exit(1) }

let isRunning = NSWorkspace.shared.runningApplications
    .contains { $0.bundleIdentifier == "io.appmakes.otty" }

let p = Process()
p.executableURL = URL(fileURLWithPath: ottyCliPath)
p.arguments = isRunning ? ["tab", "new", "--cwd", path] : ["open", path]
p.standardOutput = FileHandle.nullDevice
p.standardError = FileHandle.nullDevice
try? p.run()
