//
//  ContentView.swift
//  LaunchAgent-Demo
//
//  Created by George Babichev on 7/30/25.
//

// The UI of the App. 

// Import SwiftUI for declarative macOS UI
import SwiftUI

// Mark the whole view as main-actor isolated since it mutates UI state
@MainActor
struct ContentView: View {
    // Persist only the user's preference; we do not query launchd at launch
    @AppStorage("openAtLogin.requested") private var requestedOpenAtLogin = false

    // Minimal manager that writes/removes the LaunchAgent and calls launchctl
    private let agent = LaunchAgentManager()

    var body: some View {
        // Simple vertical layout with left alignment and comfortable spacing
        VStack(alignment: .leading, spacing: 16) {
            // The single setting the app exposes: open at login
            Toggle("Open at login", isOn: $requestedOpenAtLogin)
                // Use macOS checkbox styling
                .toggleStyle(.checkbox)
                // React only to user changes; we don't programmatically change this at launch
                .onChange(of: requestedOpenAtLogin) { _, newValue in
                    Task(priority: .utility) {
                        if newValue {
                            agent.enable()
                        } else {
                            agent.disable()
                        }
                    }
                }
        }
        // Standard padding around the content
        .padding()
        // Fixed width to look like a small settings pane
        .frame(width: 250)
    }
}
