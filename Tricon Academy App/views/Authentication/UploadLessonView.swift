import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Content upload screen for tutors and admins.
/// Supports video lessons and document uploads (PDF / notes).
struct UploadLessonView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var authManager: AuthManager

    enum UploadKind: String, CaseIterable, Identifiable {
        case document = "Document"
        case video = "Video lesson"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .document: return "doc.badge.plus"
            case .video: return "video.badge.plus"
            }
        }
    }

    @State private var uploadKind: UploadKind = .document
    @State private var title = ""
    @State private var description = ""
    @State private var selectedLevel: Level = .form1
    @State private var selectedSubjectName: String = allSubjects.first?.name ?? "Physics"
    @State private var topic = ""

    // Video
    @State private var selectedVideo: PhotosPickerItem?
    @State private var videoFileName: String?

    // Document
    @State private var showDocumentPicker = false
    @State private var documentFileName: String?
    @State private var documentURL: URL?

    @State private var showSuccess = false
    @State private var errorMessage: String?

    private var subjectOptions: [String] {
        allSubjects.filter { $0.name != "Optionals" }.map(\.name)
            + optionalSubjects.map(\.name)
    }

    private var canUpload: Bool {
        guard authManager.currentUser?.canManageContent == true else { return false }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        switch uploadKind {
        case .document:
            return documentURL != nil
        case .video:
            return selectedVideo != nil
        }
    }

    var body: some View {
        NavigationView {
            Form {
                if authManager.currentUser?.canManageContent != true {
                    Section {
                        Label(
                            "Only tutors and admins can upload content.",
                            systemImage: "lock.fill"
                        )
                        .foregroundColor(.secondary)
                    }
                } else {
                    Section {
                        Picker("Content type", selection: $uploadKind) {
                            ForEach(UploadKind.allCases) { kind in
                                Label(kind.rawValue, systemImage: kind.icon).tag(kind)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section("Details") {
                        TextField("Title", text: $title)
                        TextField("Topic (optional)", text: $topic)
                        TextField("Description", text: $description, axis: .vertical)
                            .lineLimit(3...6)

                        Picker("Level", selection: $selectedLevel) {
                            ForEach(Level.allCases) { level in
                                Text(level.rawValue).tag(level)
                            }
                        }

                        Picker("Subject", selection: $selectedSubjectName) {
                            ForEach(subjectOptions, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                    }

                    if uploadKind == .document {
                        Section("Document") {
                            Button {
                                showDocumentPicker = true
                            } label: {
                                Label(
                                    documentFileName ?? "Choose PDF or document",
                                    systemImage: "doc.fill"
                                )
                            }

                            if documentFileName != nil {
                                Text("Ready to upload")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    } else {
                        Section("Video") {
                            PhotosPicker(selection: $selectedVideo, matching: .videos) {
                                Label(videoFileName ?? "Select video", systemImage: "video.fill")
                            }
                            .onChange(of: selectedVideo) { newItem in
                                videoFileName = newItem == nil ? nil : "Video selected ✓"
                            }
                        }
                    }

                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundColor(.red)
                        }
                    }

                    Section {
                        Button {
                            performUpload()
                        } label: {
                            HStack {
                                Spacer()
                                Label(
                                    uploadKind == .document ? "Upload Document" : "Upload Lesson",
                                    systemImage: "arrow.up.circle.fill"
                                )
                                .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                        .disabled(!canUpload)
                    }

                    Section {
                        Text("Uploads are saved locally for this demo build. Connect a backend storage service to publish content to students.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(uploadKind == .document ? "Upload Document" : "New Lesson")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker { url in
                    documentURL = url
                    documentFileName = url.lastPathComponent
                }
            }
            .alert("Upload complete", isPresented: $showSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("“\(title)” was prepared for \(selectedSubjectName) · \(selectedLevel.rawValue).")
            }
        }
    }

    private func performUpload() {
        guard authManager.currentUser?.canManageContent == true else {
            errorMessage = "You don’t have permission to upload content."
            return
        }
        errorMessage = nil
        // Mock success — replace with real storage API when available.
        showSuccess = true
    }
}

// MARK: - Document picker (UIKit bridge)

struct DocumentPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.pdf, .plainText, .rtf, .data, .image]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

struct UploadLessonView_Previews: PreviewProvider {
    static var previews: some View {
        UploadLessonView()
            .environmentObject(AuthManager.shared)
    }
}
