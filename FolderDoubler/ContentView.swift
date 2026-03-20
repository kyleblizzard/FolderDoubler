// Copyright (c) 2026 Kyle Blizzard. All Rights Reserved.
// This code is publicly visible for portfolio purposes only.
// Unauthorized copying, forking, or distribution of this file,
// via any medium, is strictly prohibited.

import SwiftUI

// MARK: - MenuBarPopoverView
//
// The main UI that appears when you click the menu bar icon. Everything lives
// in this single popover — no separate windows or sheets. The layout is compact
// to fit comfortably in a menu bar popover while still following the Aqua spec.
//
// Sections (top to bottom):
// 1. Header — app name + status badge
// 2. Folder panel — source and destination in a frosted panel
// 3. Controls — primary start/stop + sync now
// 4. Activity log — recent sync events in a frosted panel
// 5. Footer — stats, exclusions toggle, and quit button
//
// Exclusions are shown inline via a disclosure group to avoid
// popover-inside-popover issues with MenuBarExtra.

struct MenuBarPopoverView: View {

    @EnvironmentObject var engine: SyncEngine
    @Environment(\.colorScheme) var colorScheme

    // Tracks whether the exclusions section is expanded
    @State private var showingExclusions = false
    @State private var newPattern = ""

    private var theme: AquaTheme { AquaTheme(colorScheme: colorScheme) }

    var body: some View {
        ZStack {
            // Tier 1 — Base Canvas
            theme.bgBase.ignoresSafeArea()

            VStack(spacing: AquaTheme.space3) {
                headerSection
                folderPanel
                controlBar

                if let error = engine.errorMessage {
                    errorBanner(error)
                }

                activityPanel
                exclusionsSection
                footerSection
            }
            .padding(AquaTheme.space4)
        }
        .frame(width: 420)
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center) {
            Image(systemName: "doc.on.doc.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [theme.aquaPrimary, theme.aquaDeep],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            // --type-title-2: 18pt semibold
            Text("FolderDoubler")
                .font(.system(size: 18, weight: .semibold))
                .tracking(-0.2)
                .foregroundColor(theme.textPrimary)

            Spacer()

            AquaStatusBadge(status: engine.status)
        }
    }

    // MARK: - Folder Panel
    // Compact frosted panel with source and destination rows.

    private var folderPanel: some View {
        VStack(alignment: .leading, spacing: AquaTheme.space3) {
            folderRow(
                label: "Source",
                icon: "folder.fill",
                path: engine.sourcePath,
                action: engine.selectSourceFolder
            )

            // Subtle divider between the two rows
            Rectangle()
                .fill(theme.strokeSubtle)
                .frame(height: 1)

            folderRow(
                label: "Destination",
                icon: "externaldrive.fill",
                path: engine.destinationPath,
                action: engine.selectDestinationFolder
            )
        }
        .aquaPanel(padding: AquaTheme.space4)
    }

    /// A single folder selection row — label above, path + button below
    private func folderRow(label: String, icon: String, path: URL?, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: AquaTheme.space1) {
            AquaSectionHeader(title: label)

            HStack(spacing: AquaTheme.space2) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundColor(theme.aquaPrimary)
                    .frame(width: 16)

                Text(path?.path ?? "Not selected")
                    .font(.system(size: 13))
                    .foregroundColor(path != nil ? theme.textPrimary : theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .aquaRecessedField()

                Button("Choose") { action() }
                    .buttonStyle(AquaSecondaryButtonStyle())
                    .controlSize(.small)
                    .disabled(engine.isMonitoring)
            }
        }
    }

    // MARK: - Controls

    private var controlBar: some View {
        HStack(spacing: AquaTheme.space2) {
            if engine.isMonitoring {
                Button(action: engine.stopMonitoring) {
                    Label("Stop", systemImage: "stop.circle.fill")
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
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.72), value: engine.isMonitoring)
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: AquaTheme.space2) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(theme.textDestructive)
                .font(.system(size: 12))

            Text(message)
                .font(.system(size: 12))
                .foregroundColor(theme.textDestructive)
                .lineLimit(2)

            Spacer()

            Button("Dismiss") { engine.errorMessage = nil }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(theme.textDestructive)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, AquaTheme.space3)
        .padding(.vertical, AquaTheme.space2)
        .background(AquaTheme.accentRed.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AquaTheme.radiusSm, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AquaTheme.radiusSm, style: .continuous)
                .strokeBorder(AquaTheme.accentRed.opacity(0.20), lineWidth: 1)
        )
    }

    // MARK: - Activity Log
    // Compact frosted panel showing recent sync events.

    private var activityPanel: some View {
        VStack(alignment: .leading, spacing: AquaTheme.space2) {
            HStack {
                AquaSectionHeader(title: "Activity")
                Spacer()
                if !engine.events.isEmpty {
                    Button("Clear") { engine.clearLog() }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(theme.textLink)
                        .buttonStyle(.plain)
                }
            }

            if engine.events.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: AquaTheme.space2) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 20))
                            .foregroundColor(theme.textTertiary)
                        Text("No activity yet")
                            .font(.system(size: 12))
                            .foregroundColor(theme.textTertiary)
                    }
                    Spacer()
                }
                .frame(height: 60)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(engine.events.prefix(100)) { event in
                            eventRow(event)
                        }
                    }
                }
                .frame(maxHeight: 160)
            }
        }
        .aquaPanel(padding: AquaTheme.space3)
    }

    private func eventRow(_ event: SyncEvent) -> some View {
        HStack(spacing: AquaTheme.space1 + 2) {
            Image(systemName: actionIcon(event.action))
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(actionColor(event.action))
                .frame(width: 14)

            Text(event.timestamp, style: .time)
                .font(.system(size: 11))
                .foregroundColor(theme.textTertiary)
                .frame(width: 58, alignment: .leading)

            Text(event.action.rawValue)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(actionColor(event.action))
                .frame(width: 46, alignment: .leading)

            Text(event.relativePath)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if event.action != .deleted && event.action != .error && event.fileSize > 0 {
                Text(formatFileSize(event.fileSize))
                    .font(.system(size: 10))
                    .foregroundColor(theme.textTertiary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Exclusions (Inline Disclosure)
    // Expands in-place to show and manage exclusion patterns.

    private var exclusionsSection: some View {
        DisclosureGroup(isExpanded: $showingExclusions) {
            VStack(spacing: AquaTheme.space2) {
                // Add new pattern
                HStack(spacing: AquaTheme.space2) {
                    TextField("e.g. *.log, .cache", text: $newPattern)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(.horizontal, AquaTheme.space2)
                        .padding(.vertical, AquaTheme.space1 + 2)
                        .background(theme.bgRecessed)
                        .clipShape(RoundedRectangle(cornerRadius: AquaTheme.radiusSm, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AquaTheme.radiusSm, style: .continuous)
                                .strokeBorder(theme.strokeSubtle, lineWidth: 1)
                        )
                        .onSubmit { addPattern() }

                    Button("Add") { addPattern() }
                        .buttonStyle(AquaGelButtonStyle())
                        .controlSize(.small)
                        .disabled(newPattern.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                // Pattern list
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(Array(engine.excludePatterns.enumerated()), id: \.element) { index, pattern in
                            HStack {
                                Text(pattern)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundColor(theme.textSecondary)
                                Spacer()
                                Button {
                                    engine.removeExcludePattern(at: IndexSet(integer: index))
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(theme.textTertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, AquaTheme.space2)
                            .padding(.vertical, 3)
                        }
                    }
                }
                .frame(maxHeight: 120)
            }
            .padding(.top, AquaTheme.space2)
        } label: {
            HStack(spacing: AquaTheme.space2) {
                Text("Exclusions")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                Text("\(engine.excludePatterns.count)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(theme.aquaPrimary)
                    .clipShape(Capsule())
            }
        }
        .tint(theme.textSecondary)
    }

    private func addPattern() {
        engine.addExcludePattern(newPattern)
        newPattern = ""
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack(spacing: AquaTheme.space2) {
            if let lastSync = engine.lastSyncDate {
                Label {
                    Text("\(lastSync, style: .relative) ago")
                } icon: {
                    Image(systemName: "clock")
                }
                .font(.system(size: 11))
                .foregroundColor(theme.textTertiary)
            }

            Spacer()

            Text("\(engine.totalFilesSynced) synced")
                .font(.system(size: 11))
                .foregroundColor(theme.textTertiary)

            // Quit button — important for menu bar apps since there's
            // no standard Cmd+Q accessible without a main menu
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func actionIcon(_ action: SyncAction) -> String {
        switch action {
        case .copied:  return "plus.circle.fill"
        case .updated: return "arrow.triangle.2.circlepath.circle.fill"
        case .deleted: return "trash.circle.fill"
        case .error:   return "exclamationmark.triangle.fill"
        }
    }

    private func actionColor(_ action: SyncAction) -> Color {
        switch action {
        case .copied:  return AquaTheme.accentMint
        case .updated: return theme.aquaPrimary
        case .deleted: return AquaTheme.accentAmber
        case .error:   return AquaTheme.accentRed
        }
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
