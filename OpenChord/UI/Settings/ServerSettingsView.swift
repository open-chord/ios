import SwiftUI

/// Server configuration and explicit reachability status.
struct ServerSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var catalog: CatalogStore
    @State private var address = ""
    @State private var validationMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    connectionStatus
                }

                Section {
                    TextField("http://192.168.1.20:8080", text: $address)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .accessibilityIdentifier("serverAddress")

                    Button {
                        Task { await connect() }
                    } label: {
                        Label(connectButtonTitle, systemImage: "network")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(catalog.connectionState == .connecting)
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
                    Text("Your iPhone and server must be connected to the same Wi-Fi or wired local network.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("OpenChord Server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear { address = catalog.serverURL.absoluteString }
        }
    }

    private var connectionStatus: some View {
        HStack(spacing: 14) {
            statusIcon
                .font(.title2)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(statusTitle)
                    .font(.headline)
                Text(catalog.serverURL.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch catalog.connectionState {
        case .unknown:
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
        case .connecting:
            ProgressView()
        case .connected:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .unavailable:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    private var statusTitle: String {
        switch catalog.connectionState {
        case .unknown: "Not checked"
        case .connecting: "Checking connection…"
        case .connected: "Server connected"
        case .unavailable: "Server unavailable"
        }
    }

    private var connectButtonTitle: String {
        catalog.connectionState == .connecting ? "Connecting…" : "Test and Connect"
    }

    private func connect() async {
        validationMessage = nil
        do {
            try await catalog.updateServerAddress(address)
            validationMessage = catalog.errorMessage
        } catch {
            validationMessage = error.localizedDescription
        }
    }
}
