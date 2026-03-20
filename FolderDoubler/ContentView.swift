// Copyright (c) 2026 Kyle Blizzard. All Rights Reserved.
// This code is publicly visible for portfolio purposes only.
// Unauthorized copying, forking, or distribution of this file,
// via any medium, is strictly prohibited.

import SwiftUI

// MARK: - ContentView
//
// The main window of FolderDoubler, designed to the Modern Aqua spec.
//
// Layout structure (top to bottom on the base canvas):
// 1. Header — app name, icon, and status badge
// 2. Folder Panel — source and destination selection in a frosted panel
// 3. Controls — Aqua Gel primary button + secondary actions
// 4. Activity Log — scrollable sync history in a frosted panel
// 5. Footer — last sync time and total file count
//
// All spacing uses the 4pt grid from the token system.
// All components use the Aqua material tiers and lighting model.

struct ContentView: View {

    @EnvironmentObject var engine: SyncEngine
    @Environment(\.colorScheme) var colorScheme

    // Local UI state
    @State private var newPattern = ""
    @State private var showingExclusions = false

    /// The resolved theme based on current appearance (light or dark)
    private var theme: AquaTheme { AquaTheme(colorScheme: colorScheme) }

    var body: some View {
        // Tier 1 — Base Canvas: the app background everything sits on
        ZStack {
            theme.bgBase.ignoresSafeArea()

            ScrollView {
                VStack(spacing: AquaTheme.space5) {
                    headerSection
                    folderPanel
                    controlBar
                    if let error = engine.errorMessage {
                        errorBanner(error)
                    }
                    activityPanel
                    footerSection
                }
                .padding(AquaTheme.space6)
            }
        }
        .frame(minWidth: 640, minHeight: 560)
    }

    // MARK: - Header
    // App title with the doc.on.doc icon and the status badge aligned right.

    private var headerSection: some View {
        HStack(alignment: .center) {
            // App icon — uses a slight aqua tint for brand identity
            Image(systemName: "doc.on.doc.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.aquaPrimary, theme.aquaDeep],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // App title — --type-title-1: 22pt semibold, tracking -0.2
            Text("FolderDoubler")
                .font(.system(size: 22, weight: .semibold))
                .tracking(-0.2)
                .foregroundColor(theme.textPrimary)

            Spacer()

            // Status badge — shows current sync state with colored dot
            AquaStatusBadge(status: engine.status)
        }
    }

    // MARK: - Folder Selection Panel
    // A frosted Aqua panel (Tier 2) containing the source and destination selectors.
    // Folder paths are shown in recessed fields (spec Section 4.5 style).

    private var folderPanel: some View {
        VStack(alignment: .leading, spacing: AquaTheme.space5) {
            // Source folder
            VStack(alignment: .leading, spacing: AquaTheme.space2) {
                AquaSectionHeader(title: "Source")

                HStack(spacing: AquaTheme.space3) {
                    // Folder icon
                    Image(systemName: "folder.fill")
                        .foregroundColor(theme.aquaPrimary)
                        .frame(width: 20)

                    // Path display in a recessed field
                    Text(engine.sourcePath?.path ?? "No folder selected")
                        .font(.system(size: 14))
                        .foregroundColor(
                            engine.sourcePath != nil ? theme.textPrimary : theme.textTertiary
                        )
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .aquaRecessedField()

                    Button("Choose...") { engine.selectSourceFolder() }
                        .buttonStyle(AquaSecondaryButtonStyle())
                        .disabled(engine.isMonitoring)
                }
            }

            // Destination folder
            VStack(alignment: .leading, spacing: AquaTheme.space2) {
                AquaSectionHeader(title: "Destination")

                HStack(spacing: AquaTheme.space3) {
                    Image(systemName: "externaldrive.fill")
                        .foregroundColor(theme.aquaPrimary)
                        .frame(width: 20)

                    Text(engine.destinationPath?.path ?? "No folder selected")
                        .font(.system(size: 14))
                        .foregroundColor(
                            engine.destinationPath != nil ? theme.textPrimary : theme.textTertiary
                        )
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .aquaRecessedField()

                    Button("Choose...") { engine.selectDestinationFolder() }
                        .buttonStyle(AquaSecondaryButtonStyle())
                        .disabled(engine.isMonitoring)
                }
            }
        }
        .aquaPanel()
    }

    // MARK: - Control Bar
    // Primary action (Start/Stop) as an Aqua Gel button, plus secondary actions.
    // These sit directly on the base canvas (not in a panel) so they pop visually.

    private var controlBar: some View {
        HStack(spacing: AquaTheme.space3) {
            // Primary CTA — Aqua Gel (blue to start, red to stop)
            if engine.isMonitoring {
                Button(action: engine.stopMonitoring) {
                    Label("Stop Monitoring", systemImage: "stop.circle.fill")
                }
                .buttonStyle(
                    AquaGelButtonStyle(
                        tint: Color(hex: "D93025"),
                        tintDeep: Color(hex: "B71C1C")
                    )
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            } else {
                Button(action: engine.startMonitoring) {
                    Label("Start Monitoring", systemImage: "play.circle.fill")
                }
                .buttonStyle(AquaGelButtonStyle())
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }

            // Manual full sync — secondary action
            Button(action: engine.runFullSync) {
                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(AquaSecondaryButtonStyle())
            .disabled(
                engine.sourcePath == nil ||
                engine.destinationPath == nil ||
                engine.status == .syncing
            )

            Spacer()

            // Exclusions management — secondary button with count badge
            Button(action: { showingExclusions.toggle() }) {
                HStack(spacing: AquaTheme.space2) {
                    Label("Exclusions", systemImage: "line.3.horizontal.decrease.circle")
                    Text("\(engine.excludePatterns.count)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.aquaPrimary)
                        .clipShape(Capsule())
                }
            }
            .buttonStyle(AquaSecondaryButtonStyle())
            .popover(isPresented: $showingExclusions) {
                exclusionsPopover
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.72), value: engine.isMonitoring)
    }

    // MARK: - Error Banner
    // Red-tinted notification bar for error messages.

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: AquaTheme.space3) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(theme.textDestructive)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(theme.textDestructive)

            Spacer()

            Button("Dismiss") { engine.errorMessage = nil }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(theme.textDestructive)
        }
        .padding(.horizontal, AquaTheme.space5)
        .padding(.vertical, AquaTheme.space3)
        .background(AquaTheme.accentRed.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AquaTheme.radiusMd, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AquaTheme.radiusMd, style: .continuous)
                .strokeBorder(AquaTheme.accentRed.opacity(0.20), lineWidth: 1)
        )
        .transition(
            .asymmetric(
                insertion: .scale(scale: 0.94).combined(with: .opacity)
                    .animation(.spring(response: 0.28, dampingFraction: 0.75)),
                removal: .scale(scale: 0.97).combined(with: .opacity)
                    .animation(.easeIn(duration: 0.15))
            )
        )
    }

    // MARK: - Exclusions Popover
    // Elevated glass (Tier 3) popover for managing file/folder exclusion patterns.

    private var exclusionsPopover: some View {
        VStack(alignment: .leading, spacing: AquaTheme.space4) {
            Text("Exclude Patterns")
                .font(.system(size: 16, weight: .semibold))
                .tracking(-0.1)
                .foregroundColor(theme.textPrimary)

            Text("Files and folders matching these patterns are skipped during sync.")
                .font(.system(size: 12))
                .foregroundColor(theme.textSecondary)

            // Add new pattern field
            HStack(spacing: AquaTheme.space2) {
                TextField("e.g. *.log, .cache, build*", text: $newPattern)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, design: .monospaced))
                    .padding(.horizontal, AquaTheme.space3)
                    .padding(.vertical, AquaTheme.space2)
                    .background(theme.bgRecessed)
                    .clipShape(RoundedRectangle(cornerRadius: AquaTheme.radiusMd, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AquaTheme.radiusMd, style: .continuous)
                            .strokeBorder(theme.strokeSubtle, lineWidth: 1)
                    )
                    .onSubmit { addPattern() }

                Button("Add") { addPattern() }
                    .buttonStyle(AquaGelButtonStyle())
                    .disabled(newPattern.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            // List of current patterns with delete support
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(engine.excludePatterns.enumerated()), id: \.element) { index, pattern in
                        HStack {
                            Text(pattern)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(theme.textPrimary)

                            Spacer()

                            Button(action: {
                                engine.removeExcludePattern(at: IndexSet(integer: index))
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(theme.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, AquaTheme.space3)
                        .padding(.vertical, AquaTheme.space2)
                        .background(
                            index % 2 == 0
                                ? Color.clear
                                : theme.bgRecessed.opacity(0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AquaTheme.radiusSm, style: .continuous))
                    }
                }
            }
            .frame(minHeight: 200, maxHeight: 300)
        }
        .frame(width: 360)
        .aquaPopover()
    }

    private func addPattern() {
        engine.addExcludePattern(newPattern)
        newPattern = ""
    }

    // MARK: - Activity Log Panel
    // Frosted panel (Tier 2) containing a scrollable list of sync events.
    // No heavy separators between rows (per spec sidebar guidance).

    private var activityPanel: some View {
        VStack(alignment: .leading, spacing: AquaTheme.space3) {
            // Section header with clear button
            HStack {
                AquaSectionHeader(title: "Activity Log")
                Spacer()
                if !engine.events.isEmpty {
                    Button("Clear") { engine.clearLog() }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(theme.textLink)
                        .buttonStyle(.plain)
                }
            }

            if engine.events.isEmpty {
                // Empty state placeholder
                VStack(spacing: AquaTheme.space3) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 28))
                        .foregroundColor(theme.textTertiary)
                    Text("No sync activity yet")
                        .font(.system(size: 14))
                        .foregroundColor(theme.textTertiary)
                    Text("Start monitoring to see file changes here")
                        .font(.system(size: 12))
                        .foregroundColor(theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
            } else {
                // Scrollable event list
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(engine.events.prefix(200)) { event in
                            eventRow(event)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
        .aquaPanel()
    }

    /// A single row in the activity log.
    /// Shows: action icon, timestamp, action label, relative path, and file size.
    private func eventRow(_ event: SyncEvent) -> some View {
        HStack(spacing: AquaTheme.space2) {
            // Colored action icon
            Image(systemName: actionIcon(event.action))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(actionColor(event.action))
                .frame(width: 18)

            // Timestamp — --type-caption: 12pt regular
            Text(event.timestamp, style: .time)
                .font(.system(size: 12))
                .foregroundColor(theme.textTertiary)
                .frame(width: 65, alignment: .leading)

            // Action label
            Text(event.action.rawValue)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(actionColor(event.action))
                .frame(width: 52, alignment: .leading)

            // Relative file path — monospaced for readability
            Text(event.relativePath)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            // File size (skip for deletions and errors)
            if event.action != .deleted && event.action != .error && event.fileSize > 0 {
                Text(formatFileSize(event.fileSize))
                    .font(.system(size: 11))
                    .foregroundColor(theme.textTertiary)
            }
        }
        .padding(.horizontal, AquaTheme.space3)
        .padding(.vertical, AquaTheme.space1 + 2)
    }

    // MARK: - Footer
    // Stats bar showing last sync time and total synced count.
    // Uses --type-caption with secondary color.

    private var footerSection: some View {
        HStack {
            if let lastSync = engine.lastSyncDate {
                Label {
                    Text("Last sync: \(lastSync, style: .relative) ago")
                } icon: {
                    Image(systemName: "clock")
                }
                .font(.system(size: 12))
                .foregroundColor(theme.textSecondary)
            } else {
                Label("Waiting for first sync", systemImage: "clock")
                    .font(.system(size: 12))
                    .foregroundColor(theme.textTertiary)
            }

            Spacer()

            Label("\(engine.totalFilesSynced) files synced", systemImage: "doc.circle")
                .font(.system(size: 12))
                .foregroundColor(theme.textSecondary)
        }
        .padding(.horizontal, AquaTheme.space2)
    }

    // MARK: - Helpers

    /// Maps a sync action to an SF Symbol name
    private func actionIcon(_ action: SyncAction) -> String {
        switch action {
        case .copied:  return "plus.circle.fill"
        case .updated: return "arrow.triangle.2.circlepath.circle.fill"
        case .deleted: return "trash.circle.fill"
        case .error:   return "exclamationmark.triangle.fill"
        }
    }

    /// Maps a sync action to a semantic color from the token system
    private func actionColor(_ action: SyncAction) -> Color {
        switch action {
        case .copied:  return AquaTheme.accentMint
        case .updated: return theme.aquaPrimary
        case .deleted: return AquaTheme.accentAmber
        case .error:   return AquaTheme.accentRed
        }
    }

    /// Formats bytes into a human-readable string (e.g. "2.1 KB")
    private func formatFileSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
