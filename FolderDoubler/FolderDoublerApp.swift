// Copyright (c) 2026 Kyle Blizzard. All Rights Reserved.
// This code is publicly visible for portfolio purposes only.
// Unauthorized copying, forking, or distribution of this file,
// via any medium, is strictly prohibited.

import SwiftUI

// MARK: - App Entry Point
//
// FolderDoubler lives in the menu bar, not the Dock. Clicking the menu bar
// icon opens a popover with the full sync UI. The app uses MenuBarExtra with
// .menuBarExtraStyle(.window) to get a proper SwiftUI popover rather than
// a dropdown menu.
//
// LSUIElement is set to YES in the build settings (project.yml) so the app
// doesn't appear in the Dock or the Cmd+Tab switcher. The menu bar icon is
// the only entry point.

@main
struct FolderDoublerApp: App {

    // StateObject keeps the SyncEngine alive for the entire app lifetime.
    @StateObject private var syncEngine = SyncEngine()

    var body: some Scene {
        // MenuBarExtra creates a persistent menu bar item. The label closure
        // defines the icon shown in the menu bar, and the content closure
        // defines what appears in the popover when clicked.
        MenuBarExtra {
            MenuBarPopoverView()
                .environmentObject(syncEngine)
        } label: {
            // The menu bar icon changes based on sync status to give
            // at-a-glance feedback without opening the popover.
            Label("FolderDoubler", systemImage: menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }

    /// Resolves the SF Symbol based on current sync status.
    /// - Idle: outline document pair
    /// - Monitoring: filled document pair (active)
    /// - Syncing: rotating arrows (work in progress)
    /// - Error: warning triangle
    private var menuBarIcon: String {
        switch syncEngine.status {
        case .idle:       return "doc.on.doc"
        case .monitoring: return "doc.on.doc.fill"
        case .syncing:    return "arrow.triangle.2.circlepath"
        case .error:      return "exclamationmark.triangle"
        }
    }
}
