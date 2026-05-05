import SwiftUI

struct HistorySettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store:    HistoryStore
    @State private var showingClearConfirm = false
    @State private var showingDemoConfirm = false
    @State private var isSeedingDemo = false

    var body: some View {
        Form {
            Section {
                LimitField(
                    label: "Max items",
                    unit: "items",
                    value: $settings.historyCountLimit,
                    range: 0...100_000,
                    step: 10
                )
            } header: {
                Text("Count Limit")
            } footer: {
                Text("0 = no limit")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Enable size limit", isOn: $settings.historySizeLimitEnabled)
                if settings.historySizeLimitEnabled {
                    LimitField(
                        label: "Max total size",
                        unit: "MB",
                        value: $settings.historySizeLimitMB,
                        range: 0...100_000,
                        step: 50
                    )
                }
            } header: {
                Text("Size Limit")
            } footer: {
                if settings.historySizeLimitEnabled {
                    Text("Applies to stored images. 0 = no limit")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle("Enable age limit", isOn: $settings.historyAgeLimitEnabled)
                LimitField(
                    label: "Keep for",
                    unit: "days",
                    value: $settings.historyAgeLimitDays,
                    range: 1...3_650,
                    step: 1
                )
                .disabled(!settings.historyAgeLimitEnabled)
                .foregroundStyle(settings.historyAgeLimitEnabled ? .primary : .tertiary)
            } header: {
                Text("Age Limit")
            } footer: {
                Text(settings.historyAgeLimitEnabled
                     ? "Items older than \(settings.historyAgeLimitDays) day\(settings.historyAgeLimitDays == 1 ? "" : "s") are pruned on next capture."
                     : "Enable to automatically remove items older than a set number of days.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    showingDemoConfirm = true
                } label: {
                    Label("Add App Store demo clips…", systemImage: "photo.on.rectangle.angled")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .disabled(isSeedingDemo)
                .confirmationDialog(
                    "Add App Store demo clips?",
                    isPresented: $showingDemoConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Add Demo Clips") {
                        Task { @MainActor in
                            isSeedingDemo = true
                            await AppStoreDemoHistory.appendDemoItemsForScreenshots(in: store)
                            isSeedingDemo = false
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Prepends fictional demo clips (with one image on top) ahead of everything else. Your existing items stay below; count/size limits may still trim the oldest entries afterward.")
                }
            } header: {
                Text("App Store snapshots")
            } footer: {
                Text("Adds demo rows at the top of MRU; does not erase your clipboard history.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Button(role: .destructive) {
                    showingClearConfirm = true
                } label: {
                    Label("Clear All History", systemImage: "trash")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .confirmationDialog(
                    "Clear all clipboard history?",
                    isPresented: $showingClearConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Clear All History", role: .destructive) {
                        store.deleteAll()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This permanently deletes all \(store.totalCount()) items and cannot be undone.")
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Reusable TextField + Stepper combo

private struct LimitField: View {
    let label: String
    let unit: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            HStack(spacing: 6) {
                TextField("", value: $value, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 76)
                    .multilineTextAlignment(.trailing)
                    // Clamp on commit so the user can't type out-of-range values
                    .onChange(of: value) { _, new in
                        if !range.contains(new) {
                            value = min(max(new, range.lowerBound), range.upperBound)
                        }
                    }
                Stepper("", value: $value, in: range, step: step)
                    .labelsHidden()
                Text(unit)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 32, alignment: .leading)
            }
        }
    }
}
