//
//  LaunchManager.swift
//  LaunchAgent-Demo
//
//  Created by George Babichev on 7/30/25.
//

// The Enable / Disable service manager.

import Foundation

// Minimal manager for a per-user LaunchAgent that opens this app at login.
// Demo-grade: best-effort ops (no throws), uses `open -a` for resilience if the app moves.
final class LaunchAgentManager {
    // Build a stable job label from the bundle id; fallback for dev builds
    private var label: String {
        (Bundle.main.bundleIdentifier ?? "com.example.MyApp") + ".openatlogin"
    }

    // Path to the user's LaunchAgents plist for this job
    private var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    // Per-user launchd domain (GUI session)
    private var uidDomain: String { "gui/\(getuid())" }

    // Tiny helper to invoke `launchctl` and return its exit status
    @discardableResult
    private func launchctl(_ args: [String]) -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        p.arguments = args
        do { try p.run() } catch { return 127 }   // 127: failed to spawn launchctl
        p.waitUntilExit()
        return p.terminationStatus                // 0 == success, non-zero == error
    }

    // Build a minimal LaunchAgent plist that launches the app via LaunchServices
    // Keys:
    // - Label: unique id for the job
    // - ProgramArguments: `/usr/bin/open -a <App.bundle>` (robust to bundle moves)
    // - RunAtLoad: start at login / when loaded
    // - LimitLoadToSessionType: only in Aqua (GUI) sessions
    private func plistDict() -> [String: Any] {
        [
            "Label": label,
            "ProgramArguments": ["/usr/bin/open", "-a", Bundle.main.bundlePath],
            "RunAtLoad": true,
            "LimitLoadToSessionType": "Aqua"
        ]
    }

    // Enable the login item:
    // 1) ensure ~/Library/LaunchAgents exists
    // 2) write (or overwrite) the plist
    // 3) `bootstrap` it into the per-user domain (fallback to `kickstart` if already present)
    // Best-effort: ignores individual failures (sufficient for a demo)
    func enable() {
        let dir = plistURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        if let data = try? PropertyListSerialization.data(fromPropertyList: plistDict(), format: .xml, options: 0) {
            try? data.write(to: plistURL, options: .atomic)
        }

        if launchctl(["bootstrap", uidDomain, plistURL.path]) != 0 {
            _ = launchctl(["kickstart", "-k", "\(uidDomain)/\(label)"])
        }
    }

    // Disable the login item:
    // 1) `bootout` the job from the per-user domain
    // 2) remove the plist file (ignore if missing)
    func disable() {
        _ = launchctl(["bootout", "\(uidDomain)/\(label)"])
        try? FileManager.default.removeItem(at: plistURL)
    }
}
