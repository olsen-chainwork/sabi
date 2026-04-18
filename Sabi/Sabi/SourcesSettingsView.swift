//
//  SourcesSettingsView.swift
//  Sabi
//
//  Slice 6 — `.settings { }` scene body.
//
//  Shows the curated baseline with per-row on/off toggles, the user's own
//  additions (with a trash button), and a text field to add new domains.
//  A "Reset to defaults" button nukes user edits back to the curated list.
//
//  Design choices:
//    - Disabled curated domains stay visible with toggle off, so users can
//      see what they've turned off and flip it back inline (vs. hiding and
//      making them hunt for a "restore" screen).
//    - User additions render in a separate section above curated so they
//      feel like a first-class user space, not a footnote.
//    - Monospaced domain text — reads as configuration, not prose.
//

import SwiftUI

struct SourcesSettingsView: View {
    @State private var store = SourcesStore.shared
    @State private var newDomain: String = ""
    @State private var showResetConfirm: Bool = false
    @State private var addError: String? = nil

    var body: some View {
        Form {
            Section {
                Text("Sabi only searches the sites listed below. Turn any off, or add your own — bare hostnames like `example.com` work; full URLs get normalized to the host.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            addSection

            if !store.userAdditions.isEmpty {
                Section("Your additions (\(store.userAdditions.count))") {
                    ForEach(store.userAdditions, id: \.self) { domain in
                        userRow(domain)
                    }
                }
            }

            Section("Curated defaults (\(DomainAllowlist.suffixes.count))") {
                ForEach(DomainAllowlist.suffixes, id: \.self) { domain in
                    curatedRow(domain)
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
                    Text("Removes every domain you've added and re-enables every curated source you've turned off. Can't be undone.")
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 620)
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
