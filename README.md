# FolderDoubler

I built this because I got tired of manually copying my Development folder to my NAS every time I made changes. Yeah, rsync exists. Yeah, there are a dozen sync tools out there. But I wanted something I could actually see working — a clean UI that shows me exactly what's being synced, when, and where.

FolderDoubler watches a source folder for changes and mirrors them to a destination in real time. Point it at your NAS, iCloud Drive, an external drive — whatever you want to keep in sync.

## How It Works

The app uses macOS FSEvents under the hood — the same kernel-level file system notification system that powers Spotlight and Time Machine. When you start monitoring, it:

1. **Runs an initial full sync** — walks the entire source directory, compares modification dates, and copies anything that's new or changed to the destination.
2. **Starts real-time monitoring** — FSEvents tells us exactly which files changed, so we don't waste time scanning. Changes are debounced (collected for ~1 second) then synced in a batch.
3. **Mirrors deletions** — if you delete a file from the source, it gets removed from the destination too.

The sync is one-way: source always wins. This isn't a two-way merge tool. It's a backup mirror.

## The UI

It lives in your menu bar — no Dock icon, no window to manage. Click the icon, and the full UI drops down as a popover. The menu bar icon changes based on sync status so you always know what's happening at a glance.

The interface follows a Modern Aqua design language — frosted glass panels, the signature blue accent, proper lighting model with top highlights and shadows. It's a utility app, but it doesn't have to look like one.

You get:
- Source and destination folder pickers
- A Start/Stop button with Aqua gel styling
- A live activity log showing every file that gets synced
- Configurable exclusion patterns (`.git`, `node_modules`, `DerivedData`, etc. are excluded by default)
- Settings that persist between launches
- A Quit button (since there's no Dock icon to right-click)

## Building

Open `FolderDoubler.xcodeproj` in Xcode and hit Cmd+R. That's it.

Requires macOS 13.0 or later.

The app runs unsandboxed with local signing — it needs full file system access to do its job. This is a personal utility, not an App Store submission.

## Architecture

Three files do all the work:

- **SyncEngine.swift** — The brain. Owns all sync logic: FSEvents setup, file comparison, copy operations, state management. It's an `ObservableObject` so SwiftUI views react to state changes automatically.
- **ContentView.swift** — The face. Reads from SyncEngine's published properties and renders everything. No business logic lives here.
- **AquaTheme.swift** + **AquaComponents.swift** — The design system. All colors, spacing, radii, and component styles are defined as tokens. Nothing is invented at the component level.

## Version History

### v0.0.2

Converted to a menu bar app. No more Dock icon or standalone window — the entire UI lives in a compact popover that drops from the menu bar. The icon changes based on sync status (outline = idle, filled = monitoring, arrows = syncing, warning = error). Added inline exclusion management via a disclosure group, and a Quit button in the footer.

### v0.0.1

First working version. Core sync engine with FSEvents monitoring, full initial sync, real-time change detection, deletion mirroring, and the Aqua-styled UI. Exclusion pattern management and persistent settings.
