import SwiftUI

struct ContentHubView: View {

    let level: Level
    let subject: Subject

    @State private var selectedTab: Int
    @ObservedObject private var library = ContentLibrary.shared
    @ObservedObject private var saved = SavedItemsManager.shared
    /// Shared singleton — avoids EnvironmentObject crashes on deep NavigationLinks.
    @ObservedObject private var authManager = AuthManager.shared

    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    @State private var folderError: String?
    /// Folder awaiting a delete confirmation (staff only).
    @State private var folderPendingDeletion: ContentFolder?

    init(level: Level, subject: Subject, initialTab: Int = 0) {
        self.level = level
        self.subject = subject
        _selectedTab = State(initialValue: initialTab)
    }

    private var currentSection: ContentSection {
        switch selectedTab {
        case 0: return .papers
        case 1: return .notes
        default: return .videos
        }
    }

    private var sectionFolders: [ContentFolder] {
        // Top-level only; mini-folders open inside FolderContentsView.
        library.folders(level: level, subject: subject.name, section: currentSection, parentId: nil)
    }

    /// Staff may organise/upload/delete **only** within their specialist subjects (admins: all).
    private var canManage: Bool {
        authManager.currentUser?.canManageSubject(subject.name) == true
    }

    /// Unfiled library papers + sample curriculum papers (curriculum always at root).
    private var rootPapers: [PastPaper] {
        library.papers(level: level, subject: subject.name, unfiledOnly: true)
            + CurriculumData.pastPapers(level: level, subject: subject.name)
    }

    private var rootMaterials: [StudyMaterial] {
        library.materials(level: level, subject: subject.name, unfiledOnly: true)
            + CurriculumData.materials(level: level, subject: subject.name)
    }

    private var rootVideos: [VideoLesson] {
        library.videos(level: level, subject: subject.name, unfiledOnly: true)
            + CurriculumData.videos(level: level, subject: subject.name)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(subject.swiftUIColor.opacity(0.14))
                        .frame(width: 42, height: 42)
                    Image(systemName: subject.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(subject.swiftUIColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(subject.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.ink)
                    Text(level.rawValue)
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(AppTheme.muted)
                }
                Spacer()
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.top, 8)
            .padding(.bottom, 12)

            Picker("Content type", selection: $selectedTab) {
                Text("Papers").tag(0)
                Text("Notes").tag(1)
                Text("Videos").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.bottom, 12)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 10) {
                    if canManage {
                        Button {
                            newFolderName = ""
                            folderError = nil
                            showCreateFolder = true
                        } label: {
                            Label("New folder in \(currentSection.displayName)", systemImage: "folder.badge.plus")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(AppTheme.brandSoft)
                                .foregroundColor(AppTheme.brandDeep)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    } else if authManager.currentUser?.isTutor == true {
                        // Tutor can view this subject but not organise it.
                        Label(
                            "View only — you can manage: \(authManager.currentUser?.managedSubjectsDisplay ?? "your specialist subjects")",
                            systemImage: "eye.fill"
                        )
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(AppTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Folders
                    ForEach(sectionFolders) { folder in
                        folderCard(folder)
                    }

                    // Content at root (unfiled + sample curriculum)
                    switch selectedTab {
                    case 0:
                        if sectionFolders.isEmpty && rootPapers.isEmpty {
                            emptyState(
                                icon: "doc.text.magnifyingglass",
                                title: "No past papers yet",
                                message: canManage
                                    ? "Create a year folder (e.g. 2018) or upload papers for \(subject.name)."
                                    : "Past papers for \(subject.name) at \(level.rawValue) will show up here."
                            )
                        } else {
                            if !rootPapers.isEmpty && !sectionFolders.isEmpty {
                                sectionLabel("Other papers")
                            }
                            ForEach(rootPapers) { paper in
                                contentRow(
                                    icon: "doc.text.fill",
                                    title: paper.title,
                                    subtitle: "\(paper.year) · Past paper",
                                    color: Color(red: 0.20, green: 0.48, blue: 0.92),
                                    isSaved: saved.isSaved(id: paper.id),
                                    onBookmark: { saved.togglePaper(paper) },
                                    onDelete: deleteAction(forContentId: paper.id),
                                    destination: PDFViewerScreen(
                                        fileName: paper.fileName,
                                        title: paper.title,
                                        isPastPaper: true,
                                        contentId: paper.id,
                                        subjectName: paper.subjectName,
                                        levelRaw: paper.level.rawValue,
                                        year: paper.year
                                    )
                                )
                            }
                        }
                    case 1:
                        if sectionFolders.isEmpty && rootMaterials.isEmpty {
                            emptyState(
                                icon: "note.text",
                                title: "No materials yet",
                                message: canManage
                                    ? "Create a topic folder (e.g. Kinematics) or upload notes for \(subject.name)."
                                    : "Study notes for \(subject.name) will appear here when available."
                            )
                        } else {
                            if !rootMaterials.isEmpty && !sectionFolders.isEmpty {
                                sectionLabel("Other notes")
                            }
                            ForEach(rootMaterials) { material in
                                contentRow(
                                    icon: "note.text",
                                    title: material.title,
                                    subtitle: material.topic,
                                    color: Color(red: 0.10, green: 0.62, blue: 0.55),
                                    isSaved: saved.isSaved(id: material.id),
                                    onBookmark: { saved.toggleMaterial(material) },
                                    onDelete: deleteAction(forContentId: material.id),
                                    destination: PDFViewerScreen(
                                        fileName: material.fileName,
                                        title: material.title,
                                        isPastPaper: false,
                                        contentId: material.id,
                                        subjectName: material.subjectName,
                                        levelRaw: material.level.rawValue,
                                        topic: material.topic
                                    )
                                )
                            }
                        }
                    default:
                        if sectionFolders.isEmpty && rootVideos.isEmpty {
                            emptyState(
                                icon: "play.rectangle",
                                title: "No videos yet",
                                message: canManage
                                    ? "Create a topic folder or upload video lessons for \(subject.name)."
                                    : "Video lessons for \(subject.name) will show up here."
                            )
                        } else {
                            if !rootVideos.isEmpty && !sectionFolders.isEmpty {
                                sectionLabel("Other videos")
                            }
                            ForEach(rootVideos) { video in
                                contentRow(
                                    icon: "play.circle.fill",
                                    title: video.title,
                                    subtitle: "\(video.topic) · \(video.durationLabel)",
                                    color: Color(red: 0.52, green: 0.32, blue: 0.88),
                                    isSaved: saved.isSaved(id: video.id),
                                    onBookmark: { saved.toggleVideo(video) },
                                    onDelete: deleteAction(forContentId: video.id),
                                    destination: VideoPlayerScreen(
                                        fileName: video.fileName,
                                        fileExtension: video.fileExtension,
                                        title: video.title,
                                        contentId: video.id,
                                        topic: video.topic,
                                        subjectName: video.subjectName,
                                        levelRaw: video.level.rawValue,
                                        durationLabel: video.durationLabel
                                    )
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.bottom, 28)
            }
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle(subject.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("New folder", isPresented: $showCreateFolder) {
            TextField(currentSection.folderPlaceholder, text: $newFolderName)
            Button("Create") {
                createFolder()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(folderError ?? "Organize \(currentSection.displayName.lowercased()) into folders — years for papers, topics for notes and videos.")
        }
        .deleteFolderConfirmation($folderPendingDeletion, itemNoun: "folder") { folder, deleteContents in
            library.removeFolder(id: folder.id, deleteContents: deleteContents)
        }
    }

    private func createFolder() {
        let result = library.createFolder(
            name: newFolderName,
            section: currentSection,
            level: level,
            subjectName: subject.name
        )
        if result == nil {
            folderError = "Could not create folder. Use a unique non-empty name."
            showCreateFolder = true
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(AppTheme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }

    /// Folder row + (staff only) a visible manage button that offers delete.
    private func folderCard(_ folder: ContentFolder) -> some View {
        HStack(spacing: 10) {
            NavigationLink {
                FolderContentsView(folder: folder, level: level, subject: subject)
            } label: {
                folderRow(folder)
            }
            .buttonStyle(.plain)

            if canManage {
                FolderManageButton(folderName: folder.name) {
                    folderPendingDeletion = folder
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
        .contextMenu {
            if canManage {
                Button(role: .destructive) {
                    folderPendingDeletion = folder
                } label: {
                    Label("Delete folder", systemImage: "trash")
                }
            }
        }
    }

    private func folderRow(_ folder: ContentFolder) -> some View {
        let count = library.itemCount(in: folder.id)
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 0.95, green: 0.72, blue: 0.20).opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: "folder.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Color(red: 0.90, green: 0.62, blue: 0.12))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(folder.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                    .lineLimit(1)
                Text(count == 1 ? "1 item" : "\(count) items")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(AppTheme.muted)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.muted.opacity(0.7))
        }
    }

    @ViewBuilder
    private func emptyState(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 12) {
            Spacer().frame(height: 36)
            ZStack {
                Circle()
                    .fill(AppTheme.brandSoft)
                    .frame(width: 72, height: 72)
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(AppTheme.brandDeep)
            }
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppTheme.ink)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Spacer().frame(height: 36)
        }
        .frame(maxWidth: .infinity)
    }

    /// Delete only for library uploads (not sample curriculum), and only when staff can manage this subject.
    private func deleteAction(forContentId contentId: String) -> (() -> Void)? {
        guard canManage, let libraryId = Self.libraryUUID(from: contentId) else { return nil }
        return { library.remove(id: libraryId) }
    }

    /// IDs for uploaded content: `library-paper-<uuid>`, `library-material-<uuid>`, `library-video-<uuid>`.
    static func libraryUUID(from contentId: String) -> UUID? {
        let prefixes = ["library-paper-", "library-material-", "library-video-"]
        for prefix in prefixes where contentId.hasPrefix(prefix) {
            return UUID(uuidString: String(contentId.dropFirst(prefix.count)))
        }
        return nil
    }

    private func contentRow<Destination: View>(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        isSaved: Bool,
        onBookmark: @escaping () -> Void,
        onDelete: (() -> Void)? = nil,
        destination: Destination
    ) -> some View {
        HStack(spacing: 10) {
            NavigationLink(destination: destination) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(color.opacity(0.14))
                            .frame(width: 44, height: 44)
                        Image(systemName: icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(color)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(subtitle)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(AppTheme.muted)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.muted.opacity(0.7))
                }
            }
            .buttonStyle(.plain)

            Button {
                onBookmark()
            } label: {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isSaved ? Color(red: 0.95, green: 0.48, blue: 0.18) : AppTheme.muted)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(AppTheme.stroke)
                    )
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isSaved ? "Remove bookmark" : "Save")

            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.danger)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(AppTheme.danger.opacity(0.10)))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Delete content")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
    }
}

// MARK: - Folder contents (supports nested mini-folders)

struct FolderContentsView: View {
    let folder: ContentFolder
    let level: Level
    let subject: Subject

    @ObservedObject private var library = ContentLibrary.shared
    @ObservedObject private var saved = SavedItemsManager.shared
    /// Shared singleton — avoids EnvironmentObject crashes on nested folder navigation.
    @ObservedObject private var authManager = AuthManager.shared

    @Environment(\.dismiss) private var dismiss

    @State private var showCreateSubfolder = false
    @State private var newSubfolderName = ""
    @State private var subfolderError: String?
    /// Mini folder awaiting a delete confirmation (staff only).
    @State private var subfolderPendingDeletion: ContentFolder?
    /// Set when staff choose to delete the folder they are currently viewing.
    @State private var selfPendingDeletion: ContentFolder?

    private var canManage: Bool {
        authManager.currentUser?.canManageSubject(subject.name) == true
    }

    private var miniFolders: [ContentFolder] {
        library.childFolders(of: folder.id)
    }

    private var papers: [PastPaper] {
        library.papers(level: level, subject: subject.name, folderId: folder.id)
    }

    private var materials: [StudyMaterial] {
        library.materials(level: level, subject: subject.name, folderId: folder.id)
    }

    private var videos: [VideoLesson] {
        library.videos(level: level, subject: subject.name, folderId: folder.id)
    }

    private var hasContent: Bool {
        !miniFolders.isEmpty || !papers.isEmpty || !materials.isEmpty || !videos.isEmpty
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(red: 0.90, green: 0.62, blue: 0.12))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(folder.name)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(AppTheme.ink)
                        Text("\(folder.section.displayName) · \(subject.name) · \(level.rawValue)")
                            .font(.system(size: 12.5))
                            .foregroundColor(AppTheme.muted)
                    }
                    Spacer()
                }
                .padding(.bottom, 6)

                if canManage {
                    Button {
                        newSubfolderName = ""
                        subfolderError = nil
                        showCreateSubfolder = true
                    } label: {
                        Label("New mini folder", systemImage: "folder.badge.plus")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(AppTheme.brandSoft)
                            .foregroundColor(AppTheme.brandDeep)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                ForEach(miniFolders) { child in
                    HStack(spacing: 10) {
                        NavigationLink {
                            FolderContentsView(folder: child, level: level, subject: subject)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(red: 0.90, green: 0.62, blue: 0.12).opacity(0.16))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(Color(red: 0.90, green: 0.62, blue: 0.12))
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(child.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(AppTheme.ink)
                                    Text("Mini folder · \(library.itemCount(in: child.id)) items")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.muted.opacity(0.7))
                            }
                        }
                        .buttonStyle(.plain)

                        if canManage {
                            FolderManageButton(folderName: child.name) {
                                subfolderPendingDeletion = child
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.stroke, lineWidth: 1)
                    )
                    .contextMenu {
                        if canManage {
                            Button(role: .destructive) {
                                subfolderPendingDeletion = child
                            } label: {
                                Label("Delete mini folder", systemImage: "trash")
                            }
                        }
                    }
                }

                switch folder.section {
                case .papers:
                    if papers.isEmpty && miniFolders.isEmpty {
                        emptyFolder
                    } else {
                        ForEach(papers) { paper in
                            row(
                                icon: "doc.text.fill",
                                title: paper.title,
                                subtitle: "\(paper.year) · Past paper",
                                color: Color(red: 0.20, green: 0.48, blue: 0.92),
                                isSaved: saved.isSaved(id: paper.id),
                                onBookmark: { saved.togglePaper(paper) },
                                onDelete: folderDeleteAction(forContentId: paper.id),
                                destination: PDFViewerScreen(
                                    fileName: paper.fileName,
                                    title: paper.title,
                                    isPastPaper: true,
                                    contentId: paper.id,
                                    subjectName: paper.subjectName,
                                    levelRaw: paper.level.rawValue,
                                    year: paper.year
                                )
                            )
                        }
                    }
                case .notes:
                    if materials.isEmpty && miniFolders.isEmpty {
                        emptyFolder
                    } else {
                        ForEach(materials) { material in
                            row(
                                icon: "note.text",
                                title: material.title,
                                subtitle: material.topic,
                                color: Color(red: 0.10, green: 0.62, blue: 0.55),
                                isSaved: saved.isSaved(id: material.id),
                                onBookmark: { saved.toggleMaterial(material) },
                                onDelete: folderDeleteAction(forContentId: material.id),
                                destination: PDFViewerScreen(
                                    fileName: material.fileName,
                                    title: material.title,
                                    isPastPaper: false,
                                    contentId: material.id,
                                    subjectName: material.subjectName,
                                    levelRaw: material.level.rawValue,
                                    topic: material.topic
                                )
                            )
                        }
                    }
                case .videos:
                    if videos.isEmpty && miniFolders.isEmpty {
                        emptyFolder
                    } else {
                        ForEach(videos) { video in
                            row(
                                icon: "play.circle.fill",
                                title: video.title,
                                subtitle: "\(video.topic) · \(video.durationLabel)",
                                color: Color(red: 0.52, green: 0.32, blue: 0.88),
                                isSaved: saved.isSaved(id: video.id),
                                onBookmark: { saved.toggleVideo(video) },
                                onDelete: folderDeleteAction(forContentId: video.id),
                                destination: VideoPlayerScreen(
                                    fileName: video.fileName,
                                    fileExtension: video.fileExtension,
                                    title: video.title,
                                    contentId: video.id,
                                    topic: video.topic,
                                    subjectName: video.subjectName,
                                    levelRaw: video.level.rawValue,
                                    durationLabel: video.durationLabel
                                )
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.inline)
        .alert("New mini folder", isPresented: $showCreateSubfolder) {
            TextField("Folder name", text: $newSubfolderName)
            Button("Create") {
                let result = library.createFolder(
                    name: newSubfolderName,
                    section: folder.section,
                    level: level,
                    subjectName: subject.name,
                    parentFolderId: folder.id
                )
                if result == nil {
                    subfolderError = "Could not create mini folder. Use a unique name."
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(subfolderError ?? "Create a nested folder inside “\(folder.name)”.")
        }
        .toolbar {
            if canManage {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            selfPendingDeletion = folder
                        } label: {
                            Label("Delete this folder", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Manage folder \(folder.name)")
                }
            }
        }
        .deleteFolderConfirmation($subfolderPendingDeletion, itemNoun: "mini folder") { child, deleteContents in
            library.removeFolder(id: child.id, deleteContents: deleteContents)
        }
        .deleteFolderConfirmation($selfPendingDeletion, itemNoun: "folder") { target, deleteContents in
            library.removeFolder(id: target.id, deleteContents: deleteContents)
            dismiss()
        }
    }

    private var emptyFolder: some View {
        VStack(spacing: 10) {
            Spacer().frame(height: 40)
            Image(systemName: "folder")
                .font(.system(size: 36))
                .foregroundColor(AppTheme.muted)
            Text("This folder is empty")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.ink)
            Text(canManage
                 ? "Add a mini folder, or upload content and choose this folder."
                 : "Content will appear here when staff uploads it.")
                .font(.system(size: 13.5))
                .foregroundColor(AppTheme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer().frame(height: 40)
        }
        .frame(maxWidth: .infinity)
    }

    private func folderDeleteAction(forContentId contentId: String) -> (() -> Void)? {
        guard canManage, let libraryId = ContentHubView.libraryUUID(from: contentId) else { return nil }
        return { library.remove(id: libraryId) }
    }

    private func row<Destination: View>(
        icon: String,
        title: String,
        subtitle: String,
        color: Color,
        isSaved: Bool,
        onBookmark: @escaping () -> Void,
        onDelete: (() -> Void)? = nil,
        destination: Destination
    ) -> some View {
        HStack(spacing: 10) {
            NavigationLink(destination: destination) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(color.opacity(0.14))
                            .frame(width: 44, height: 44)
                        Image(systemName: icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(color)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(AppTheme.ink)
                            .lineLimit(2)
                        Text(subtitle)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundColor(AppTheme.muted)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.muted.opacity(0.7))
                }
            }
            .buttonStyle(.plain)

            Button(action: onBookmark) {
                Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(isSaved ? Color(red: 0.95, green: 0.48, blue: 0.18) : AppTheme.muted)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(AppTheme.stroke))
            }
            .buttonStyle(.borderless)

            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.danger)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(AppTheme.danger.opacity(0.10)))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Delete content")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
    }
}

// MARK: - Staff folder management (tutors & admins, every form)

/// Visible trash control on a folder row. Only rendered for staff who manage
/// this subject, so students and other tutors never see a delete affordance.
struct FolderManageButton: View {
    let folderName: String
    let onDelete: () -> Void

    var body: some View {
        Menu {
            Button(role: .destructive, action: onDelete) {
                Label("Delete folder", systemImage: "trash")
            }
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.danger)
                .frame(width: 36, height: 36)
                .background(Circle().fill(AppTheme.danger.opacity(0.10)))
                .contentShape(Circle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Delete folder \(folderName)")
    }
}

extension View {
    /// Two-step delete for a folder: nothing is removed until staff pick one of
    /// the two explicit options, so a stray tap can't destroy uploaded content.
    /// `perform` receives `deleteContents == true` only for the destructive option.
    func deleteFolderConfirmation(
        _ folder: Binding<ContentFolder?>,
        itemNoun: String,
        perform: @escaping (ContentFolder, Bool) -> Void
    ) -> some View {
        confirmationDialog(
            folder.wrappedValue.map { "Delete “\($0.name)”?" } ?? "Delete \(itemNoun)?",
            isPresented: Binding(
                get: { folder.wrappedValue != nil },
                set: { if !$0 { folder.wrappedValue = nil } }
            ),
            titleVisibility: .visible,
            presenting: folder.wrappedValue
        ) { target in
            Button("Delete \(itemNoun) only (keep files)", role: .destructive) {
                perform(target, false)
                folder.wrappedValue = nil
            }
            Button("Delete \(itemNoun) and everything in it", role: .destructive) {
                perform(target, true)
                folder.wrappedValue = nil
            }
            Button("Cancel", role: .cancel) {
                folder.wrappedValue = nil
            }
        } message: { target in
            Text("“\(target.name)” and any mini folders inside it will be removed. Keeping the files moves them back to the main \(target.section.displayName.lowercased()) list. This can't be undone.")
        }
    }
}

struct ContentHubView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ContentHubView(
                level: .form4,
                subject: allSubjects.first ?? Subject(name: "Physics", icon: "atom", colorName: "blue")
            )
        }
    }
}
