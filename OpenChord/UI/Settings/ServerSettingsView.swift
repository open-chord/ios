import SwiftUI

struct ServerSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var catalog: CatalogStore
    @State private var address = ""
    @State private var validationMessage: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("http://192.168.1.20:8080", text: $address)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .accessibilityIdentifier("serverAddress")
                } header: {
                    Text("Server address")
                } footer: {
                    Text("Use the address printed by ./scripts/lan-up.sh on the computer running OpenChord.")
                }

                if let validationMessage {
                    Section {
                        Label(validationMessage, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }

                Section("Local network") {
                    LabeledContent("Current server", value: catalog.serverURL.absoluteString)
                    Text("Your iPhone and server must be connected to the same Wi-Fi or wired local network.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("OpenChord Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Connect") {
                        Task { await connect() }
                    }
                    .disabled(isSaving)
                }
            }
            .overlay {
                if isSaving {
                    ProgressView("Connecting…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            .onAppear { address = catalog.serverURL.absoluteString }
        }
    }

    private func connect() async {
        isSaving = true
        validationMessage = nil
        do {
            try await catalog.updateServerAddress(address)
            if let error = catalog.errorMessage {
                validationMessage = error
            } else {
                dismiss()
            }
        } catch {
            validationMessage = error.localizedDescription
        }
        isSaving = false
    }
}
