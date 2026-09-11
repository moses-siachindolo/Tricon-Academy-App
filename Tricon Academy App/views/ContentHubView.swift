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

    private var papersTotal: Int {
        library.folders(level: level, subject: subject.name, section: .papers, parentId: nil).count
            + library.papers(level: level, subject: subject.name, unfiledOnly: true).count
            + CurriculumData.pastPapers(level: level, subject: subject.name).count
    }

    private var notesTotal: Int {
        library.folders(level: level, subject: subject.name, section: .notes, parentId: nil).count
            + library.materials(level: level, subject: subject.name, unfiledOnly: true).count
            + CurriculumData.materials(level: level, subject: subject.name).count
    }

    private var videosTotal: Int {
        library.folders(level: level, subject: subject.name, section: .videos, parentId: nil).count
            + library.videos(level: level, subject: subject.name, unfiledOnly: true).count
            + CurriculumData.videos(level: level, subject: subject.name).count
    }

    private var sectionAccent: Color { AppTheme.iconGreen }
    private var sectionSoft: Color { AppTheme.iconWell }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 16)

            ContentTypeSelector(
                selection: $selectedTab,
                tabs: ContentTypeSelector.subjectTabs(
                    papers: papersTotal,
                    notes: notesTotal,
                    videos: videosTotal
                )
            )
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.bottom, 12)

            sectionContextBar
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.bottom, 14)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    if canManage {
                        Button {
                            newFolderName = ""
                            folderError = nil
                            showCreateFolder = true
                        } label: {
                            Label("New folder in \(currentSection.displayName)", systemImage: "folder.badge.plus")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(sectionAccent)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 48)
                                .background(sectionSoft)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                                        .stroke(sectionAccent.opacity(0.40), lineWidth: 1)
                                )
                        }
                        .buttonStyle(SoftPressStyle())
                    } else if authManager.currentUser?.isTutor == true {
                        Label(
                            "View only — you can manage: \(authManager.currentUser?.managedSubjectsDisplay ?? "your specialist subjects")",
                            systemImage: "eye.fill"
                        )
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundColor(AppTheme.secondaryInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                                .fill(AppTheme.iconWell)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                                .stroke(AppTheme.cardLine, lineWidth: 1)
                        )
                    }

                    // Folders
                    ForEach(sectionFolders) { folder in
                        folderCard(folder)
                    }

                    // Content at root (unfiled + sample curriculum)
                    switch selectedTab {
                    case 0:
                        if sectionFolders.isEmpty && rootPapers.isEmpty {
                            AppEmptyState(
                                icon: "doc.text.magnifyingglass",
                                title: "No past papers yet",
                                message: canManage
                                    ? "Create a year folder (e.g. 2018) or upload papers for \(subject.name)."
                                    : "Past papers for \(subject.name) at \(level.rawValue) will show up here.",
                                accent: AppTheme.iconGreen,
                                soft: AppTheme.iconWell
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
                                    color: AppTheme.iconGreen,
                                    soft: AppTheme.iconWell,
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
                            AppEmptyState(
                                icon: "note.text",
                                title: "No study notes yet",
                                message: canManage
                                    ? "Create a topic folder (e.g. Kinematics) or upload notes for \(subject.name)."
                                    : "Study notes for \(subject.name) will appear here when available.",
                                accent: AppTheme.iconGreen,
                                soft: AppTheme.iconWell
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
                                    color: AppTheme.iconGreen,
                                    soft: AppTheme.iconWell,
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
                            AppEmptyState(
                                icon: "play.rectangle.fill",
                                title: "No video lessons yet",
                                message: canManage
                                    ? "Create a topic folder or upload video lessons for \(subject.name)."
                                    : "Video lessons for \(subject.name) will show up here.",
                                accent: AppTheme.iconGreen,
                                soft: AppTheme.iconWell
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
                                    color: AppTheme.iconGreen,
                                    soft: AppTheme.iconWell,
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
                .padding(.bottom, 32)
            }
        }
        .background(
            ZStack {
                AppTheme.canvas.ignoresSafeArea()
                LinearGradient(
                    colors: [AppTheme.brandSoft.opacity(0.38), AppTheme.canvas, AppTheme.canvas],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        )
        .navigationTitle(subject.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            StatsManager.shared.recordSubjectVisited(name: subject.name, levelRaw: level.rawValue)
        }
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

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: subject.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(AppTheme.iconGreen)
                .symbolRenderingMode(.monochrome)
                .frame(width: 52, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                        .fill(AppTheme.iconWell)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(subject.name)
                    .appFont(size: 18, weight: .bold)
                    .foregroundColor(AppTheme.ink)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(level.rawValue)
                        .appFont(size: 12.5, weight: .semibold)
                        .foregroundColor(AppTheme.secondaryInk)
                    Text("·")
                        .foregroundColor(AppTheme.secondaryInk)
                    Text(currentSection.displayName)
                        .appFont(size: 12.5, weight: .bold)
                        .foregroundColor(AppTheme.iconGreen)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .stroke(AppTheme.cardLine, lineWidth: 1)
        )
    }

    private var sectionContextBar: some View {
        HStack(spacing: 8) {
            Image(systemName: AppTheme.icon(for: currentSection))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(AppTheme.iconGreen)
                .symbolRenderingMode(.monochrome)
            Text(sectionHint)
                .appFont(size: 12.5, weight: .medium)
                .foregroundColor(AppTheme.secondaryInk)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .fill(AppTheme.iconWell)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .stroke(AppTheme.cardLine, lineWidth: 1)
        )
    }

    private var sectionHint: String {
        switch currentSection {
        case .papers:
            return "Past exam papers by year — practice under real conditions."
        case .notes:
            return "Topic notes and study materials for revision."
        case .videos:
            return "Video lessons you can watch anytime to reinforce each topic."
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
        Text(text.uppercased())
            .appFont(size: 11.5, weight: .bold)
            .tracking(0.6)
            .foregroundColor(AppTheme.iconGreen)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 10)
            .padding(.bottom, 2)
    }

    /// Folder row + (staff only) a visible manage button that offers delete.
    private func folderCard(_ folder: ContentFolder) -> some View {
        HStack(spacing: 10) {
            NavigationLink {
                FolderContentsView(folder: folder, level: level, subject: subject)
            } label: {
                folderRow(folder)
            }
            .buttonStyle(SoftPressStyle())

            if canManage {
                FolderManageButton(folderName: folder.name) {
                    folderPendingDeletion = folder
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .stroke(AppTheme.cardLine, lineWidth: 1)
        )
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
            Image(systemName: "folder.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppTheme.iconGreen)
                .symbolRenderingMode(.monochrome)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                        .fill(AppTheme.iconWell)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(folder.name)
                    .appFont(size: 15, weight: .semibold)
                    .foregroundColor(AppTheme.ink)
                    .lineLimit(1)
                Text(count == 1 ? "1 item" : "\(count) items")
                    .appFont(size: 12.5, weight: .medium)
                    .foregroundColor(AppTheme.secondaryInk)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.secondaryInk)
        }
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
        soft: Color,
        isSaved: Bool,
        onBookmark: @escaping () -> Void,
        onDelete: (() -> Void)? = nil,
        destination: Destination
    ) -> some View {
        HStack(spacing: 10) {
            NavigationLink(destination: destination) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppTheme.iconGreen)
                        .symbolRenderingMode(.monochrome)
                        .frame(width: 46, height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                                .fill(AppTheme.iconWell)
                        )

                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .appFont(size: 15, weight: .semibold)
                            .foregroundColor(AppTheme.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(subtitle)
                            .appFont(size: 12.5, weight: .medium)
                            .foregroundColor(AppTheme.secondaryInk)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.secondaryInk)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(SoftPressStyle())

            Button {
                onBookmark()
            } label: {
                AppIconLabel(systemName: isSaved ? "bookmark.fill" : "bookmark",
                             tint: isSaved ? AppTheme.bookmark : AppTheme.secondaryInk,
                             fill: isSaved ? AppTheme.bookmark.opacity(0.12) : AppTheme.fill)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isSaved ? "Remove bookmark" : "Save")

            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    AppIconLabel(systemName: "trash", tint: AppTheme.danger, fill: AppTheme.dangerSoft)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Delete content")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .stroke(AppTheme.cardLine, lineWidth: 1)
        )
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

    private var sectionAccent: Color { AppTheme.iconGreen }
    private var sectionSoft: Color { AppTheme.iconWell }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                            .fill(AppTheme.iconWell)
                            .frame(width: 48, height: 48)
                        Image(systemName: "folder.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.iconGreen)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(folder.name)
                            .appFont(size: 18, weight: .bold)
                            .foregroundColor(AppTheme.ink)
                        Text("\(folder.section.displayName) · \(subject.name) · \(level.rawValue)")
                            .appFont(size: 12.5, weight: .medium)
                            .foregroundColor(AppTheme.secondaryInk)
                    }
                    Spacer()
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                        .fill(AppTheme.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                        .stroke(AppTheme.cardLine, lineWidth: 1)
                )
                .padding(.bottom, 4)

                if canManage {
                    Button {
                        newSubfolderName = ""
                        subfolderError = nil
                        showCreateSubfolder = true
                    } label: {
                        Label("New mini folder", systemImage: "folder.badge.plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(sectionAccent)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 48)
                            .background(sectionSoft)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                                    .stroke(sectionAccent.opacity(0.28), lineWidth: 1)
                            )
                    }
                    .buttonStyle(SoftPressStyle())
                }

                ForEach(miniFolders) { child in
                    HStack(spacing: 10) {
                        NavigationLink {
                            FolderContentsView(folder: child, level: level, subject: subject)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                                        .fill(AppTheme.iconWell)
                                        .frame(width: 44, height: 44)
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(AppTheme.iconGreen)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(child.name)
                                        .appFont(size: 15, weight: .semibold)
                                        .foregroundColor(AppTheme.ink)
                                    Text("Mini folder · \(library.itemCount(in: child.id)) items")
                                        .appFont(size: 12, weight: .medium)
                                        .foregroundColor(AppTheme.secondaryInk)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppTheme.subtle)
                            }
                        }
                        .buttonStyle(SoftPressStyle())

                        if canManage {
                            FolderManageButton(folderName: child.name) {
                                subfolderPendingDeletion = child
                            }
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                            .fill(AppTheme.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                            .stroke(AppTheme.cardLine, lineWidth: 1)
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
                                color: AppTheme.iconGreen,
                                soft: AppTheme.iconWell,
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
                                color: AppTheme.iconGreen,
                                soft: AppTheme.iconWell,
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
                                color: AppTheme.iconGreen,
                                soft: AppTheme.iconWell,
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
        .appScreen()
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
                            .foregroundColor(AppTheme.brandDeep)
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
        AppEmptyState(
            icon: "folder",
            title: "This folder is empty",
            message: canManage
                ? "Add a mini folder, or upload content and choose this folder."
                : "Content will appear here when staff uploads it.",
            accent: sectionAccent,
            soft: sectionSoft
        )
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
        soft: Color,
        isSaved: Bool,
        onBookmark: @escaping () -> Void,
        onDelete: (() -> Void)? = nil,
        destination: Destination
    ) -> some View {
        HStack(spacing: 10) {
            NavigationLink(destination: destination) {
                HStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppTheme.iconGreen)
                        .symbolRenderingMode(.monochrome)
                        .frame(width: 46, height: 46)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                                .fill(AppTheme.iconWell)
                        )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .appFont(size: 15, weight: .semibold)
                            .foregroundColor(AppTheme.ink)
                            .lineLimit(2)
                        Text(subtitle)
                            .appFont(size: 12.5, weight: .medium)
                            .foregroundColor(AppTheme.secondaryInk)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.secondaryInk)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(SoftPressStyle())

            Button(action: onBookmark) {
                AppIconLabel(systemName: isSaved ? "bookmark.fill" : "bookmark",
                             tint: isSaved ? AppTheme.bookmark : AppTheme.secondaryInk,
                             fill: isSaved ? AppTheme.bookmark.opacity(0.12) : AppTheme.fill)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isSaved ? "Remove bookmark" : "Save")

            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    AppIconLabel(systemName: "trash", tint: AppTheme.danger, fill: AppTheme.dangerSoft)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Delete content")
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .stroke(AppTheme.cardLine, lineWidth: 1)
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
            AppIconLabel(systemName: "trash", tint: AppTheme.danger, fill: AppTheme.dangerSoft)
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
