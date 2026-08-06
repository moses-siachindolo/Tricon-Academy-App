import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Content upload screen for tutors and admins.
/// Supports past papers, study notes, and video lessons — optionally into a folder.
struct UploadLessonView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject private var library = ContentLibrary.shared

    enum UploadKind: String, CaseIterable, Identifiable {
        case paper = "Past paper"
        case note = "Notes"
        case video = "Video lesson"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .paper: return "doc.badge.plus"
            case .note: return "note.text.badge.plus"
            case .video: return "video.badge.plus"
            }
        }

        var section: ContentSection {
            switch self {
            case .paper: return .papers
            case .note: return .notes
            case .video: return .videos
            }
        }
    }

    @State private var uploadKind: UploadKind = .paper
    @State private var title = ""
    @State private var description = ""
    @State private var selectedLevel: Level = .form1
    @State private var selectedSubjectName: String = allSubjects.first?.name ?? "Physics"
    @State private var topic = ""
    @State private var selectedFolderId: UUID? = nil

    // Video
    @State private var selectedVideo: PhotosPickerItem?
    @State private var videoFileName: String?
    @State private var videoData: Data?
    @State private var isLoadingVideo = false

    // Document
    @State private var showDocumentPicker = false
    @State private var documentFileName: String?
    @State private var documentURL: URL?

    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var isUploading = false
    @State private var showNewFolderAlert = false
    @State private var newFolderName = ""

    private var allCatalogueSubjects: [String] {
        allSubjects.filter { $0.name != "Optionals" }.map(\.name)
            + optionalSubjects.map(\.name)
    }

    /// Tutors only see their specialist subjects; admins see the full catalogue.
    private var subjectOptions: [String] {
        guard let user = authManager.currentUser else { return [] }
        if user.isAdmin { return allCatalogueSubjects }
        if user.isTutor {
            let managed = user.managedSubjectNames
            return managed.isEmpty ? [] : managed
        }
        return []
    }

    private var availableFolders: [(folder: ContentFolder, path: String)] {
        library.allFoldersFlat(
            level: selectedLevel,
            subject: selectedSubjectName,
            section: uploadKind.section
        )
    }

    private var canUpload: Bool {
        guard let user = authManager.currentUser, user.canManageContent else { return false }
        guard user.canManageSubject(selectedSubjectName) else { return false }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard !isUploading else { return false }
        switch uploadKind {
        case .paper, .note:
            return documentURL != nil
        case .video:
            return videoData != nil && !isLoadingVideo
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
                } else if subjectOptions.isEmpty {
                    Section {
                        Label(
                            "No specialist subjects on your profile. Set your subject major (e.g. Mathematics, Physics) so you can upload and delete for those courses only. You can still view every subject as a learner.",
                            systemImage: "lock.fill"
                        )
                        .foregroundColor(.secondary)
                        .font(.footnote)
                    }
                } else {
                    if authManager.currentUser?.isTutor == true {
                        Section {
                            Text("You may upload or delete only for: \(subjectOptions.joined(separator: ", ")). All other subjects stay view-only.")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }

                    Section {
                        Picker("Content type", selection: $uploadKind) {
                            ForEach(UploadKind.allCases) { kind in
                                Label(kind.rawValue, systemImage: kind.icon).tag(kind)
                            }
                        }
                        .onChange(of: uploadKind) { _ in
                            selectedFolderId = nil
                        }
                    }

                    Section("Details") {
                        TextField("Title", text: $title)
                        TextField(
                            uploadKind == .paper ? "Year (optional)" : "Topic (optional)",
                            text: $topic
                        )
                        TextField("Description", text: $description, axis: .vertical)
                            .lineLimit(3...6)

                        Picker("Level", selection: $selectedLevel) {
                            ForEach(Level.activeCases) { level in
                                Text(level.rawValue).tag(level)
                            }
                        }
                        .onChange(of: selectedLevel) { _ in
                            selectedFolderId = nil
                        }

                        Picker("Subject", selection: $selectedSubjectName) {
                            ForEach(subjectOptions, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .onChange(of: selectedSubjectName) { _ in
                            selectedFolderId = nil
                        }
                    }

                    Section {
                        Picker("Folder", selection: $selectedFolderId) {
                            Text("No folder (root)").tag(nil as UUID?)
                            ForEach(availableFolders, id: \.folder.id) { entry in
                                Text(entry.path).tag(entry.folder.id as UUID?)
                            }
                        }

                        Button {
                            newFolderName = ""
                            showNewFolderAlert = true
                        } label: {
                            Label("Create new folder…", systemImage: "folder.badge.plus")
                        }
                    } header: {
                        Text("Organize")
                    } footer: {
                        Text("You can also open a folder and create mini folders inside it. Pick any folder in the list (including nested ones).")
                    }

                    if uploadKind == .paper || uploadKind == .note {
                        Section(uploadKind == .paper ? "Past paper file" : "Notes file") {
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
                                    .foregroundColor(AppTheme.brand)
                            }
                        }
                    } else {
                        Section("Video") {
                            PhotosPicker(selection: $selectedVideo, matching: .videos) {
                                Label(videoFileName ?? "Select video", systemImage: "video.fill")
                            }
                            .onChange(of: selectedVideo) { newItem in
                                videoData = nil
                                videoFileName = nil
                                guard let newItem else { return }
                                isLoadingVideo = true
                                Task {
                                    // Prefer Movie so we get a real file URL + filename when possible.
                                    if let movie = try? await newItem.loadTransferable(type: UploadMovie.self) {
                                        await MainActor.run {
                                            videoData = movie.data
                                            videoFileName = movie.fileName
                                            isLoadingVideo = false
                                        }
                                    } else if let data = try? await newItem.loadTransferable(type: Data.self) {
                                        await MainActor.run {
                                            videoData = data
                                            videoFileName = "lesson.mp4"
                                            isLoadingVideo = false
                                        }
                                    } else {
                                        await MainActor.run {
                                            videoData = nil
                                            videoFileName = nil
                                            isLoadingVideo = false
                                            errorMessage = "Could not read the selected video. Try another file."
                                        }
                                    }
                                }
                            }
                            if isLoadingVideo {
                                ProgressView("Preparing video…")
                            } else if videoData != nil {
                                Text("Ready to upload")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.brand)
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
                                if isUploading {
                                    ProgressView()
                                } else {
                                    Label(
                                        uploadButtonTitle,
                                        systemImage: "arrow.up.circle.fill"
                                    )
                                    .fontWeight(.semibold)
                                }
                                Spacer()
                            }
                        }
                        .disabled(!canUpload)
                    }

                    Section {
                        Text(
                            authManager.isCloudEnabled
                                ? "Uploads are saved to Tricon Academy cloud storage and appear under the selected level, subject, and folder for learners."
                                : "Uploads are saved on this device and show up under the selected level, subject, and folder for learners on this phone."
                        )
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                // Default picker to a subject the tutor is allowed to manage.
                if let first = subjectOptions.first,
                   !subjectOptions.contains(where: { $0.caseInsensitiveCompare(selectedSubjectName) == .orderedSame }) {
                    selectedSubjectName = first
                }
            }
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
            .alert("New folder", isPresented: $showNewFolderAlert) {
                TextField(uploadKind.section.folderPlaceholder, text: $newFolderName)
                Button("Create") {
                    if let folder = library.createFolder(
                        name: newFolderName,
                        section: uploadKind.section,
                        level: selectedLevel,
                        subjectName: selectedSubjectName,
                        parentFolderId: nil
                    ) {
                        selectedFolderId = folder.id
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Folder will appear under \(selectedSubjectName) · \(selectedLevel.rawValue) · \(uploadKind.section.displayName).")
            }
            .alert("Upload complete", isPresented: $showSuccess) {
                Button("Done") { dismiss() }
            } message: {
                let folderLabel: String = {
                    if let id = selectedFolderId,
                       let path = availableFolders.first(where: { $0.folder.id == id })?.path {
                        return " in “\(path)”"
                    }
                    return ""
                }()
                Text("“\(title)” is now available for \(selectedSubjectName) · \(selectedLevel.rawValue)\(folderLabel).")
            }
        }
    }

    private var navigationTitle: String {
        switch uploadKind {
        case .paper: return "Upload Paper"
        case .note: return "Upload Notes"
        case .video: return "New Lesson"
        }
    }

    private var uploadButtonTitle: String {
        switch uploadKind {
        case .paper: return "Upload Paper"
        case .note: return "Upload Notes"
        case .video: return "Upload Lesson"
        }
    }

    private func performUpload() {
        guard authManager.currentUser?.canManageContent == true else {
            errorMessage = "You don’t have permission to upload content."
            return
        }
        guard authManager.currentUser?.canManageSubject(selectedSubjectName) == true else {
            errorMessage = "You can only upload for your specialist subjects: \(authManager.currentUser?.managedSubjectsDisplay ?? "—")."
            return
        }
        errorMessage = nil
        isUploading = true

        let uploader = authManager.currentUser?.fullName ?? "Staff"
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                switch uploadKind {
                case .paper:
                    _ = try await library.addPaperAsync(
                        title: cleanTitle,
                        topic: topic,
                        description: description,
                        level: selectedLevel,
                        subjectName: selectedSubjectName,
                        sourceURL: documentURL,
                        uploaderName: uploader,
                        folderId: selectedFolderId
                    )
                case .note:
                    _ = try await library.addNoteAsync(
                        title: cleanTitle,
                        topic: topic,
                        description: description,
                        level: selectedLevel,
                        subjectName: selectedSubjectName,
                        sourceURL: documentURL,
                        uploaderName: uploader,
                        folderId: selectedFolderId
                    )
                case .video:
                    guard let videoData, !videoData.isEmpty else {
                        throw SupabaseError.message("Please select a video file before uploading.")
                    }
                    _ = try await library.addVideoAsync(
                        title: cleanTitle,
                        topic: topic,
                        description: description,
                        level: selectedLevel,
                        subjectName: selectedSubjectName,
                        originalFileName: videoFileName ?? "lesson.mp4",
                        uploaderName: uploader,
                        folderId: selectedFolderId,
                        videoData: videoData
                    )
                }
                await MainActor.run {
                    isUploading = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                    errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }
}

// MARK: - PhotosPicker movie transferable

/// Loads video bytes from PhotosPicker with a stable file name when available.
private struct UploadMovie: Transferable {
    let data: Data
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            let temp = FileManager.default.temporaryDirectory
                .appendingPathComponent(movie.fileName.isEmpty ? "lesson.mp4" : movie.fileName)
            try movie.data.write(to: temp, options: .atomic)
            return SentTransferredFile(temp)
        } importing: { received in
            let url = received.file
            let data = try Data(contentsOf: url)
            let name = url.lastPathComponent.isEmpty ? "lesson.mp4" : url.lastPathComponent
            return UploadMovie(data: data, fileName: name)
        }
        DataRepresentation(contentType: .movie) { movie in
            movie.data
        } importing: { data in
            UploadMovie(data: data, fileName: "lesson.mp4")
        }
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
