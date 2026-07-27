import PhotosUI
import SwiftUI
import UIKit

/// Full creation flow for playlist identity and optional custom artwork.
struct CreatePlaylistView: View {
    @EnvironmentObject private var catalog: CatalogStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var playlistDescription = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var artworkImage: UIImage?
    @State private var artworkData: Data?
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                VStack(spacing: 16) {
                    artwork
                        .frame(width: 220, height: 220)

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack {
                            Image(systemName: "photo")
                            Text("Choose or Change Artwork")
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)

                ZStack(alignment: .topLeading) {
                    if playlistDescription.isEmpty {
                        Text("Description")
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                    }
                    TextEditor(text: $playlistDescription)
                        .frame(minHeight: 90)
                        .scrollContentBackground(.hidden)
                }
            } header: {
                Text("Playlist")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("New Playlist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") { create() }
                    .fontWeight(.semibold)
                    .disabled(!canCreate)
            }
        }
        .disabled(isSaving)
        .overlay {
            if isSaving {
                ProgressView("Creating Playlist…")
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
        }
        .task(id: selectedPhoto) {
            guard
                let data = try? await selectedPhoto?.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else { return }
            artworkImage = image
            artworkData = image.jpegData(compressionQuality: 0.86)
        }
        .alert(
            "Could Not Create Playlist",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let artworkImage {
            Image(uiImage: artworkImage)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        } else {
            ArtworkView(
                style: ArtworkStyle(
                    symbol: "music.note.list",
                    colors: [.indigo, .violet]
                )
            )
        }
    }

    private var canCreate: Bool {
        !isSaving
            && !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && playlistDescription.count <= 500
    }

    private func create() {
        isSaving = true
        let creation = PlaylistCreation(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            description: playlistDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            artworkData: artworkData
        )
        Task {
            do {
                try await catalog.createPlaylist(creation)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}
