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
        case paper = "Paper"
        case note = "Notes"
        case video = "Video"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .paper: return "doc.badge.plus"
            case .note: return "note.text.badge.plus"
            case .video: return "video.badge.plus"
            }
        }

        var fullLabel: String {
            switch self {
            case .paper: return "Past paper"
            case .note: return "Study notes"
            case .video: return "Video lesson"
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

    private let brand = AppTheme.brand
    private let brandDeep = AppTheme.brandDeep
    private let brandSoft = AppTheme.brandSoft
    private let ink = AppTheme.ink
    private let muted = AppTheme.muted
    private let canvas = AppTheme.canvas

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

    private var isAdmin: Bool {
        authManager.currentUser?.isAdmin == true
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    if authManager.currentUser?.canManageContent != true {
                        lockedBanner(
                            title: "Upload not available",
                            message: "Only tutors and admins can upload content."
                        )
                    } else if subjectOptions.isEmpty {
                        lockedBanner(
                            title: "No subjects to manage",
                            message: "Set your subject major so you can upload for those courses. You can still browse every subject as a learner."
                        )
                    } else {
                        // Nested groups keep each ViewBuilder under the iOS 16 limit of 10 children.
                        scopeBanner

                        VStack(alignment: .leading, spacing: 14) {
                            sectionLabel("Content type")
                            contentTypePicker

                            sectionLabel("Details")
                            detailsCard

                            sectionLabel(uploadKind == .video ? "Video file" : "Document file")
                            fileCard

                            sectionLabel("Folder (optional)")
                            folderCard
                        }

                        uploadActions
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 28)
            }
            .background(canvas.ignoresSafeArea())
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let first = subjectOptions.first,
                   !subjectOptions.contains(where: { $0.caseInsensitiveCompare(selectedSubjectName) == .orderedSame }) {
                    selectedSubjectName = first
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 15, weight: .medium))
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

    @ViewBuilder
    private var scopeBanner: some View {
        if authManager.currentUser?.isTutor == true {
            compactInfoBanner(
                icon: "person.badge.shield.checkmark.fill",
                text: "You can upload for: \(subjectOptions.joined(separator: ", "))."
            )
        } else if isAdmin {
            compactInfoBanner(
                icon: "checkmark.shield.fill",
                text: "Admin · full catalogue. Content appears under the form, subject, and folder you pick."
            )
        }
    }

    private var uploadActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let errorMessage {
                Text(errorMessage)
                    .appFont(size: 12.5, weight: .medium)
                    .foregroundColor(AppTheme.danger)
                    .padding(.horizontal, 2)
            }

            Button {
                performUpload()
            } label: {
                HStack(spacing: 8) {
                    if isUploading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(uploadButtonTitle)
                            .appFont(size: 15, weight: .semibold)
                    }
                }
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .disabled(!canUpload)
            .padding(.top, 4)

            Text(
                authManager.isCloudEnabled
                    ? "Saved to Tricon Academy cloud and shown to learners under the selected form & subject."
                    : "Saved on this device and shown to learners under the selected form & subject."
            )
            .appFont(size: 11.5, weight: .medium)
            .foregroundColor(muted)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .appFont(size: 11, weight: .bold)
            .foregroundColor(brandDeep)
            .tracking(0.35)
            .textCase(.uppercase)
            .padding(.top, 2)
    }

    private var contentTypePicker: some View {
        HStack(spacing: 8) {
            ForEach(UploadKind.allCases) { kind in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        uploadKind = kind
                        selectedFolderId = nil
                        // Clear opposite file type when switching
                        if kind == .video {
                            documentURL = nil
                            documentFileName = nil
                        } else {
                            selectedVideo = nil
                            videoData = nil
                            videoFileName = nil
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: kind.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(kind.rawValue)
                            .appFont(size: 12.5, weight: .semibold)
                            .lineLimit(1)
                    }
                    .foregroundColor(uploadKind == kind ? .white : brandDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.iconRadius, style: .continuous)
                            .fill(uploadKind == kind
                                  ? AnyShapeStyle(LinearGradient(colors: [AppTheme.brand, AppTheme.brandFillDeep], startPoint: .leading, endPoint: .trailing))
                                  : AnyShapeStyle(brandSoft))
                    )
                }
                .buttonStyle(SoftPressStyle())
            }
        }
    }

    private var detailsCard: some View {
        VStack(spacing: 0) {
            compactField("Title", text: $title, placeholder: "e.g. June 2023 Paper 1")

            Divider().padding(.leading, 12)

            compactField(
                uploadKind == .paper ? "Year" : "Topic",
                text: $topic,
                placeholder: uploadKind == .paper ? "Optional year" : "Optional topic"
            )

            Divider().padding(.leading, 12)

            compactField("Description", text: $description, placeholder: "Optional short note", axis: .vertical)

            Divider().padding(.leading, 12)

            HStack(spacing: 0) {
                pickerRow("Form", selection: $selectedLevel) {
                    ForEach(Level.activeCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .onChange(of: selectedLevel) { _ in selectedFolderId = nil }

                Divider().frame(height: 36)

                pickerRow("Subject", selection: $selectedSubjectName) {
                    ForEach(subjectOptions, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .onChange(of: selectedSubjectName) { _ in selectedFolderId = nil }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .stroke(brand.opacity(0.10), lineWidth: 1)
        )
    }

    private var fileCard: some View {
        Group {
            if uploadKind == .paper || uploadKind == .note {
                Button {
                    showDocumentPicker = true
                } label: {
                    filePickRow(
                        icon: "doc.fill",
                        title: documentFileName ?? "Choose PDF or document",
                        ready: documentFileName != nil
                    )
                }
                .buttonStyle(SoftPressStyle())
            } else {
                PhotosPicker(selection: $selectedVideo, matching: .videos) {
                    filePickRow(
                        icon: "video.fill",
                        title: isLoadingVideo
                            ? "Preparing video…"
                            : (videoFileName ?? "Select video"),
                        ready: videoData != nil && !isLoadingVideo
                    )
                }
                .onChange(of: selectedVideo) { newItem in
                    videoData = nil
                    videoFileName = nil
                    guard let newItem else { return }
                    isLoadingVideo = true
                    Task {
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
            }
        }
    }

    private var folderCard: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "folder.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(brandDeep)
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.iconRadius, style: .continuous)
                            .fill(brandSoft)
                    )

                Picker("Folder", selection: $selectedFolderId) {
                    Text("Root (no folder)").tag(nil as UUID?)
                    ForEach(availableFolders, id: \.folder.id) { entry in
                        Text(entry.path).tag(entry.folder.id as UUID?)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    newFolderName = ""
                    showNewFolderAlert = true
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(brandDeep)
                        .padding(8)
                        .background(Circle().fill(brandSoft))
                }
                .buttonStyle(SoftPressStyle())
                .accessibilityLabel("Create new folder")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .stroke(brand.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Small UI pieces

    private func compactField(
        _ label: String,
        text: Binding<String>,
        placeholder: String,
        axis: Axis = .horizontal
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .appFont(size: 10.5, weight: .semibold)
                .foregroundColor(muted)
            if axis == .vertical {
                TextField(placeholder, text: text, axis: .vertical)
                    .font(.system(size: 14.5))
                    .foregroundColor(ink)
                    .lineLimit(2...4)
            } else {
                TextField(placeholder, text: text)
                    .font(.system(size: 14.5))
                    .foregroundColor(ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func pickerRow<SelectionValue: Hashable, Content: View>(
        _ label: String,
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .appFont(size: 10.5, weight: .semibold)
                .foregroundColor(muted)
            Picker(label, selection: selection, content: content)
                .labelsHidden()
                .font(.system(size: 13.5, weight: .medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func filePickRow(icon: String, title: String, ready: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(ready ? .white : brandDeep)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.iconRadius, style: .continuous)
                        .fill(ready
                              ? AnyShapeStyle(LinearGradient(colors: [AppTheme.brand, AppTheme.brandFillDeep], startPoint: .topLeading, endPoint: .bottomTrailing))
                              : AnyShapeStyle(brandSoft))
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .appFont(size: 13.5, weight: .semibold)
                    .foregroundColor(ink)
                    .lineLimit(1)
                Text(ready ? "Ready to upload" : "Tap to choose a file")
                    .appFont(size: 11, weight: .medium)
                    .foregroundColor(ready ? brandDeep : muted)
            }

            Spacer(minLength: 4)

            Image(systemName: ready ? "checkmark.circle.fill" : "plus.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(ready ? brand : brand.opacity(0.45))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .stroke(ready ? brand.opacity(0.28) : brand.opacity(0.10), lineWidth: 1)
        )
    }

    private func compactInfoBanner(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(brandDeep)
                .padding(.top, 1)
            Text(text)
                .appFont(size: 12, weight: .medium)
                .foregroundColor(muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.iconRadius, style: .continuous)
                .fill(brandSoft.opacity(0.7))
        )
    }

    private func lockedBanner(title: String, message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(brandDeep)
                .padding(12)
                .background(Circle().fill(brandSoft))
            Text(title)
                .appFont(size: 15, weight: .bold)
                .foregroundColor(ink)
            Text(message)
                .appFont(size: 13, weight: .medium)
                .foregroundColor(muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .stroke(brand.opacity(0.10), lineWidth: 1)
        )
        .padding(.top, 24)
    }

    // MARK: - Titles / upload

    private var navigationTitle: String {
        switch uploadKind {
        case .paper: return "Upload Paper"
        case .note: return "Upload Notes"
        case .video: return "Upload Video"
        }
    }

    private var uploadButtonTitle: String {
        switch uploadKind {
        case .paper: return "Upload Paper"
        case .note: return "Upload Notes"

        case .video: return "Upload Video"
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
