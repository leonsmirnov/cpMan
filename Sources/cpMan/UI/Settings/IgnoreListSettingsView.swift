import SwiftUI
import AppKit

struct IgnoreListSettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var showingAppPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Clipboard activity from these apps will not be captured.")
                .font(.callout)
                .foregroundStyle(.secondary)

            List {
                ForEach(settings.ignoredBundleIds, id: \.self) { bundleId in
                    IgnoredAppRow(bundleId: bundleId)
                }
                .onDelete { indexSet in
                    settings.ignoredBundleIds.remove(atOffsets: indexSet)
                }
            }
            .frame(minHeight: 180)
            .listStyle(.bordered)

            Button("Add App…") { showingAppPicker = true }
        }
        .padding()
        .sheet(isPresented: $showingAppPicker) {
            AppPickerSheet(isPresented: $showingAppPicker)
                .environmentObject(settings)
        }
    }
}

// MARK: - Row

struct IgnoredAppRow: View {
    let bundleId: String

    private var runningApp: NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first
    }

    var body: some View {
        HStack(spacing: 8) {
            if let icon = runningApp?.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 20, height: 20)
            } else {
                Image(systemName: "app.dashed")
                    .frame(width: 20, height: 20)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(runningApp?.localizedName ?? bundleId)
                    .font(.system(size: 13))
                Text(bundleId)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - App picker sheet

struct AppPickerSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var settings: AppSettings

    private var runningApps: [NSRunningApplication] {
        IgnoreListService.shared.runningApps()
            .filter { app in
                guard let id = app.bundleIdentifier else { return false }
                return !settings.ignoredBundleIds.contains(id)
            }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("Select an app to ignore")
                .font(.headline)
                .padding()

            Divider()

            List(runningApps, id: \.bundleIdentifier) { app in
                Button {
                    if let id = app.bundleIdentifier {
                        IgnoreListService.shared.add(bundleId: id)
                    }
                    isPresented = false
                } label: {
                    HStack(spacing: 8) {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 20, height: 20)
                        }
                        Text(app.localizedName ?? app.bundleIdentifier ?? "Unknown")
                            .font(.system(size: 13))
                    }
                }
                .buttonStyle(.plain)
            }

            Divider()

            Button("Cancel") { isPresented = false }
                .padding(10)
        }
        .frame(width: 300, height: 380)
    }
}
