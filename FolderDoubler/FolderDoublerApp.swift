// Copyright (c) 2026 Kyle Blizzard. All Rights Reserved.
// This code is publicly visible for portfolio purposes only.
// Unauthorized copying, forking, or distribution of this file,
// via any medium, is strictly prohibited.

import SwiftUI

// MARK: - App Entry Point
//
// The @main attribute tells Swift this is where the app starts.
// SwiftUI's App protocol defines the app's structure — which windows to show,
// what data they share, and how the app behaves.
//
// FolderDoubler is a single-window utility app. The SyncEngine is created
// once as a StateObject and shared with all views via .environmentObject().

@main
struct FolderDoublerApp: App {

    // StateObject keeps the SyncEngine alive for the entire lifetime of the app.
    // It's created once here and never recreated, even when views update.
    @StateObject private var syncEngine = SyncEngine()

    var body: some Scene {

        // WindowGroup creates the main app window. macOS will show this when
        // the app launches and allow the user to reopen it from the Window menu.
        WindowGroup {
            ContentView()
                .environmentObject(syncEngine)
        }
        // Default window size that fits the Aqua layout comfortably
        .defaultSize(width: 720, height: 640)
    }
}
