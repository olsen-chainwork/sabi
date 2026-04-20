//
//  SourcesSettingsView.swift
//  Sabi
//
//  Slice 6 — `.settings { }` scene body.
//
//  Shows the curated baseline with per-row on/off toggles AND a trash
//  icon for hard-delete, the user's own additions (each with a trash
//  button, plus a "Clear all" destructive action in the section header),
//  and a text field to add new domains. A "Reset to defaults" button at
//  the bottom brings back everything the user has deleted or toggled off.
//
//  Design choices:
//    - Toggle-off keeps the row visible in the curated list (so the user
//      can flip it back inline). Trash-delete hides it entirely — useful
//      when a source is wrong/outdated and the user wants it gone.
//    - User additions render in a separate section above curated so they
//      feel like a first-class user space, not a footnote.
//    - "Clear all" on the additions header carries a warning triangle and
//      a confirmation dialog because it can't be undone. Per-row trash
//      has no confirmation because "Reset to defaults" is the undo.
//    - Monospaced domain text — reads as configuration, not prose.
//

import SwiftUI

struct SourcesSettingsView: View {
    @State private var store = SourcesStore.shared
    @State private var polling = PollingPrefs.shared
    @State private var newDomain: String = ""
    @State private var showResetConfirm: Bool = false
    @State private var showClearAdditionsConfirm: Bool = false
    @State private var addError: String? = nil
    @State private var isChecking: Bool = false
    @State private var lastCheckMessage: String? = nil

    var body: some View {
        Form {
            Section {
                Text("Sabi only searches the sites listed below. Turn any off, or add your own — bare hostnames like `example.com` work; full URLs get normalized to the host.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            pollingSection

            addSection

            if !store.userAdditions.isEmpty {
                Section {
                    ForEach(store.userAdditions, id: \.self) { domain in
                        userRow(domain)
                    }
                } header: {
                    HStack(spacing: 8) {
                        Text("Your additions (\(store.userAdditions.count))")
                        Spacer()
                        Button(role: .destructive) {
                            showClearAdditionsConfirm = true
                        } label: {
                            Label("Clear all", systemImage: "exclamationmark.triangle.fill")
                                .labelStyle(.titleAndIcon)
                        }
                        .buttonStyle(.borderless)
                        .font(.callout)
                        .help("Removes every domain you've added. Can't be undone.")
                    }
                }
                .confirmationDialog(
                    "Clear all \(store.userAdditions.count) domains you've added?",
                    isPresented: $showClearAdditionsConfirm
                ) {
                    Button("Clear all", role: .destructive) {
                        store.clearUserAdditions()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This will permanently remove every domain you've added. Curated sources and their on/off states aren't touched. Can't be undone.")
                }
            }

            Section {
                ForEach(store.visibleCurated, id: \.self) { domain in
                    curatedRow(domain)
                }
            } header: {
                HStack(spacing: 8) {
                    Text("Curated defaults (\(store.visibleCurated.count))")
                    if !store.curatedDeletions.isEmpty {
                        Text("\(store.curatedDeletions.count) deleted")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            } footer: {
                if !store.curatedDeletions.isEmpty {
                    Text("\(store.curatedDeletions.count) curated source\(store.curatedDeletions.count == 1 ? "" : "s") hidden. \"Reset to defaults\" below brings them back.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button("Reset to defaults", role: .destructive) {
                    showResetConfirm = true
                }
                .confirmationDialog(
                    "Reset all source edits?",
                    isPresented: $showResetConfirm
                ) {
                    Button("Reset", role: .destructive) {
                        store.resetToDefaults()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Removes every domain you've added, re-enables every curated source you've turned off, and restores any curated defaults you've deleted. Can't be undone.")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 620)
    }

    // MARK: - Polling section

    private var pollingSection: some View {
        Section("Background polling") {
            Toggle("Ping me when there's something new", isOn: $polling.isEnabled)
                .toggleStyle(.switch)
            Text("While Sabi is running, it checks your sources every few hours for fresh content on your focus. You'll get one notification only if something brand-new cracks the top 5.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Button(action: checkNow) {
                    if isChecking {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Checking…")
                        }
                    } else {
                        Text("Check now")
                    }
                }
                .disabled(isChecking)

                if let lastCheckMessage {
                    Text(lastCheckMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func checkNow() {
        isChecking = true
        lastCheckMessage = nil
        Task {
            await BackgroundPoller.shared.tick()
            isChecking = false
            // End-user copy. If anything brand-new cracked the top 5, Notifier
            // already fired a banner; silence means "nothing new this pass,"
            // not a failure. Either way, the UX promise holds.
            lastCheckMessage = "Checked — I'll ping you if anything new surfaces."
        }
    }

    // MARK: - Add section

    private var addSection: some View {
        Section("Add a source") {
            HStack(spacing: 8) {
                TextField("example.com", text: $newDomain)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit(addNew)
                Button("Add", action: addNew)
                    .disabled(trimmedNewDomain.isEmpty)
                    .keyboardShortcut(.return, modifiers: [])
            }
            if let addError {
                Text(addError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Rows

    private func curatedRow(_ domain: String) -> some View {
        HStack {
            Toggle(isOn: toggleBinding(for: domain)) {
                Text(domain)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(store.isDisabled(domain) ? .tertiary : .primary)
                    .strikethrough(store.isDisabled(domain))
            }
            .toggleStyle(.switch)
            Spacer()
            Button(role: .destructive) {
                store.deleteCuratedDomain(domain)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Delete this curated source. \"Reset to defaults\" brings it back.")
        }
    }

    private func userRow(_ domain: String) -> some View {
        HStack {
            Toggle(isOn: toggleBinding(for: domain)) {
                Text(domain)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(store.isDisabled(domain) ? .tertiary : .primary)
                    .strikethrough(store.isDisabled(domain))
            }
            .toggleStyle(.switch)
            Spacer()
            Button(role: .destructive) {
                store.removeUserDomain(domain)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remove this domain entirely")
        }
    }

    private func toggleBinding(for domain: String) -> Binding<Bool> {
        Binding(
            get: { !store.isDisabled(domain) },
            set: { store.setEnabled(domain, enabled: $0) }
        )
    }

    // MARK: - Add logic

    private var trimmedNewDomain: String {
        newDomain.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func addNew() {
        guard !trimmedNewDomain.isEmpty else { return }
        addError = nil
        let ok = store.addDomain(trimmedNewDomain)
        if ok {
            newDomain = ""
        } else {
            addError = "Couldn't parse that as a domain. Try something like `example.com`."
        }
    }
}

#Preview {
    SourcesSettingsView()
}
