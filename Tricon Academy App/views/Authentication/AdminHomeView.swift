import SwiftUI

/// Content management home for tutors and admins.
struct AdminHomeView: View {
    var showsOverview: Bool = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var library = ContentLibrary.shared
    @ObservedObject private var bookStore = LibraryBookStore.shared
    @State private var showUploadSheet = false
    @State private var showLibraryBookUpload = false
    @State private var resourceToDelete: LibraryItem?

    private var roleTitle: String {
        authManager.currentUser?.roleDisplayName ?? "Staff"
    }

    private var welcomeName: String {
        authManager.currentUser?.fullName ?? roleTitle
    }

    private var myLibrarySubmissions: [UserLibraryBook] {
        guard let id = authManager.currentUser?.id else { return [] }
        return bookStore.books(uploadedBy: id)
    }

    var body: some View {
        Group {
            if authManager.currentUser?.isAdmin == true {
                adminDashboard
            } else {
                staffContent
            }
        }
    }

    private var tutorSubjects: [Subject] {
        (authManager.currentUser?.managedSubjects ?? []).filter {
            authManager.currentUser?.canManageSubject($0.name) == true
        }
    }

    private var tutorResources: [LibraryItem] {
        library.items.filter {
            authManager.currentUser?.canManageSubject($0.subjectName) == true
        }.sorted { $0.createdAt > $1.createdAt }
    }

    private var staffContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Label("TUTOR WORKSPACE", systemImage: "person.crop.circle.badge.checkmark")
                        .appFont(size: 11, weight: .bold)
                        .tracking(1)
                        .foregroundColor(AppTheme.brandDeep)
                    Text(showsOverview ? "Welcome, \(welcomeName)" : "Manage teaching content")
                        .appFont(size: 28, weight: .bold)
                        .foregroundColor(AppTheme.ink)
                    Text("Organise resources for your approved subjects and follow your library submissions.")
                        .appFont(size: 15)
                        .foregroundColor(AppTheme.secondaryInk)
                    Text("\(tutorSubjects.count) approved subjects · \(tutorResources.count) subject resources")
                        .appFont(size: 13, weight: .semibold)
                        .foregroundColor(AppTheme.brandDeep)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(AppTheme.brandSoft)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))

                if let error = library.lastSyncError ?? bookStore.lastError {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Could not sync the latest content", systemImage: "exclamationmark.triangle")
                            .appFont(size: 14, weight: .semibold)
                        Text(error).appFont(size: 13)
                        Button("Retry") { Task { await refreshTutorContent() } }
                            .frame(minHeight: 44)
                    }
                    .foregroundColor(AppTheme.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .appCard(elevated: false)
                }

                if !showsOverview { tutorPublishing }

                VStack(alignment: .leading, spacing: 12) {
                    adminSectionTitle("Your subjects", detail: "Choose a subject, then a form to manage its resources")
                    if tutorSubjects.isEmpty {
                        staffTip(icon: "book.closed", title: "No approved subjects yet", detail: "Request subject access to start adding papers, notes and lessons.")
                    } else {
                        LazyVGrid(columns: adminColumns, spacing: 12) {
                            ForEach(tutorSubjects) { subject in
                                NavigationLink {
                                    SubjectLevelPickerView(subject: subject)
                                } label: {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Image(systemName: subject.icon)
                                            .font(.title2)
                                            .foregroundColor(AppTheme.brandDeep)
                                        Text(subject.name)
                                            .appFont(size: 17, weight: .bold)
                                            .foregroundColor(AppTheme.ink)
                                        Text("Form 1–4 · Manage resources")
                                            .appFont(size: 13)
                                            .foregroundColor(AppTheme.secondaryInk)
                                    }
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(16)
                                    .appCard(elevated: false)
                                }
                                .buttonStyle(SoftPressStyle())
                            }
                        }
                    }
                    NavigationLink(destination: SettingsView()) {
                        adminActionLabel("Request subject access", detail: "View your permissions and request additional subjects", icon: "lock.shield.fill")
                    }
                    .buttonStyle(SoftPressStyle())
                }

                if showsOverview { tutorPublishing }
                tutorSubmissions
                tutorRecentResources
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.vertical, 20)
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle(showsOverview ? "Tutor overview" : "Content management")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await refreshTutorContent() }
        .onAppear { bookStore.refreshInBackground() }
        .sheet(isPresented: $showUploadSheet) {
            UploadLessonView().environmentObject(authManager)
        }
        .sheet(isPresented: $showLibraryBookUpload) {
            UploadLibraryBookView().environmentObject(authManager)
        }
        .confirmationDialog("Delete this resource?", isPresented: Binding(
            get: { resourceToDelete != nil },
            set: { if !$0 { resourceToDelete = nil } }
        ), titleVisibility: .visible) {
            if let item = resourceToDelete {
                Button("Delete resource", role: .destructive) {
                    guard authManager.currentUser?.canManageSubject(item.subjectName) == true else { return }
                    library.remove(id: item.id)
                    resourceToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { resourceToDelete = nil }
        } message: {
            Text("Delete “\(resourceToDelete?.title ?? "this resource")” from the subject library? This cannot be undone.")
        }
    }

    private var tutorPublishing: some View {
        VStack(alignment: .leading, spacing: 12) {
            adminSectionTitle("Publishing", detail: "Share papers, study notes, video lessons and books")
            Button { showUploadSheet = true } label: {
                Label("Upload resource", systemImage: "plus.circle.fill")
                    .padding(.horizontal, 12)
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .disabled(tutorSubjects.isEmpty)
            Button { showLibraryBookUpload = true } label: {
                adminActionLabel("Submit library book", detail: "Send a book for admin review before publication", icon: "book.badge.plus")
            }
            .disabled(authManager.currentUser?.canManageContent != true)
            NavigationLink(destination: TriconAcademyLibraryView()) {
                adminActionLabel("Academy Library", detail: "Browse published books and extra reading", icon: "books.vertical.fill")
            }
        }
        .buttonStyle(SoftPressStyle())
    }

    private var tutorSubmissions: some View {
        VStack(alignment: .leading, spacing: 12) {
            adminSectionTitle("Your library submissions", detail: "Track approval and review feedback")
            if myLibrarySubmissions.isEmpty {
                staffTip(icon: "books.vertical", title: "No submissions yet", detail: "Submit a library book above. Its review status will appear here.")
            } else {
                ForEach(myLibrarySubmissions.sorted { $0.createdAt > $1.createdAt }) { book in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(book.title)
                            .appFont(size: 15, weight: .semibold)
                            .foregroundColor(AppTheme.ink)
                        Label(book.approvalStatus.rawValue.capitalized, systemImage: book.approvalStatus == .approved ? "checkmark.seal.fill" : (book.approvalStatus == .rejected ? "exclamationmark.circle.fill" : "clock.fill"))
                            .appFont(size: 13, weight: .semibold)
                            .foregroundColor(book.approvalStatus == .rejected ? AppTheme.danger : AppTheme.brandDeep)
                        Text(book.category.rawValue)
                            .appFont(size: 13)
                            .foregroundColor(AppTheme.secondaryInk)
                        if let reason = book.reviewReason, !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Review feedback: \(reason)")
                                .appFont(size: 13)
                                .foregroundColor(AppTheme.secondaryInk)
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .appCard(elevated: false)
                }
            }
        }
    }

    private var tutorRecentResources: some View {
        VStack(alignment: .leading, spacing: 12) {
            adminSectionTitle("Recent resources", detail: "Latest uploads in your approved subjects")
            if tutorResources.isEmpty {
                staffTip(icon: "doc.text", title: "No resources yet", detail: "Upload a resource for an approved subject to get started.")
            } else {
                ForEach(tutorResources.prefix(5)) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        NavigationLink {
                            ContentHubView(
                                level: item.level,
                                subject: User.catalogueSubjects.first { User.subjectsMatch($0.name, item.subjectName) }
                                    ?? Subject(name: item.subjectName, icon: "book.fill", colorName: "blue"),
                                initialTab: item.section == .papers ? 0 : (item.section == .notes ? 1 : 2)
                            )
                        } label: {
                            adminActionLabel(item.title, detail: recentItemSubtitle(item), icon: recentItemIcon(item))
                        }
                        .buttonStyle(SoftPressStyle())
                        Button(role: .destructive) { resourceToDelete = item } label: {
                            Label("Delete resource", systemImage: "trash")
                                .appFont(size: 13, weight: .semibold)
                                .frame(minHeight: 44)
                                .padding(.horizontal, 16)
                        }
                        .accessibilityLabel("Delete \(item.title)")
                    }
                }
            }
        }
    }

    @MainActor
    private func refreshTutorContent() async {
        await authManager.refreshCurrentUserProfile()
        await library.refreshFromCloud()
        await bookStore.refreshFromCloud()
    }

    // Admins manage publishing and accounts; they do not have assigned subjects.
    private var adminDashboard: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                adminHeader

                if showsOverview {
                    adminOverview
                }

                contentActions

                if !library.items.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        adminSectionTitle("Recent resources", detail: "Latest academy uploads")
                        ForEach(library.items.sorted { $0.createdAt > $1.createdAt }.prefix(5)) { item in
                            NavigationLink {
                                ContentHubView(
                                    level: item.level,
                                    subject: (allSubjects + optionalSubjects).first { $0.name == item.subjectName }
                                        ?? Subject(name: item.subjectName, icon: "book.fill", colorName: "blue"),
                                    initialTab: item.section == .papers ? 0 : (item.section == .notes ? 1 : 2)
                                )
                            } label: {
                                adminActionLabel(item.title, detail: recentItemSubtitle(item), icon: recentItemIcon(item))
                            }
                            .buttonStyle(SoftPressStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.vertical, 20)
            .frame(maxWidth: 860)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle(showsOverview ? "Admin overview" : "Content management")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await library.refreshFromCloud()
            await bookStore.refreshFromCloud()
        }
        .onAppear { bookStore.refreshInBackground() }
        .sheet(isPresented: $showUploadSheet) {
            UploadLessonView().environmentObject(authManager)
        }
        .sheet(isPresented: $showLibraryBookUpload) {
            UploadLibraryBookView().environmentObject(authManager)
        }
    }

    private var adminColumns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible())]
            : [GridItem(.adaptive(minimum: 155), spacing: 12)]
    }

    private var adminHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("ACADEMY ADMINISTRATION", systemImage: "shield.lefthalf.filled")
                .appFont(size: 11, weight: .bold)
                .tracking(1)
                .foregroundColor(AppTheme.brandDeep)
            Text(showsOverview ? "Academy overview" : "Manage academy content")
                .appFont(size: 28, weight: .bold)
                .foregroundColor(AppTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(showsOverview
                 ? "Review submissions and manage academy accounts."
                 : "Publish learning resources and organise content across every form and subject.")
                .appFont(size: 15)
                .foregroundColor(AppTheme.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(AppTheme.brandSoft)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
    }

    private var adminOverview: some View {
        VStack(alignment: .leading, spacing: 12) {
            adminSectionTitle("Administration", detail: "Accounts and publishing approvals")
            NavigationLink(destination: LibraryBookReviewView()) {
                adminActionLabel(
                    "Library reviews",
                    detail: bookStore.pendingReviewCount == 0
                        ? "No submissions awaiting review"
                        : "\(bookStore.pendingReviewCount) submissions awaiting review",
                    icon: "checkmark.seal.fill"
                )
            }
            NavigationLink(destination: StudentsAdminView()) {
                adminActionLabel("Student accounts", detail: "View student records and enrolment details", icon: "person.3.fill")
            }
            NavigationLink(destination: SuperAdminDashboardView()) {
                adminActionLabel("Accounts & access", detail: "Review tutors and manage account permissions", icon: "lock.shield.fill")
            }
        }
        .buttonStyle(SoftPressStyle())
    }

    private var contentActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            adminSectionTitle("Publishing", detail: "Add and organise learning resources")
            Button { showUploadSheet = true } label: {
                Label("Upload resource", systemImage: "plus.circle.fill")
                    .padding(.horizontal, 12)
            }
            .buttonStyle(AppPrimaryButtonStyle())
            Button { showLibraryBookUpload = true } label: {
                adminActionLabel("Publish library book", detail: "Add a book to the Academy Library", icon: "book.badge.plus")
            }
            .buttonStyle(SoftPressStyle())
            NavigationLink(destination: TriconAcademyLibraryView()) {
                adminActionLabel("Academy Library", detail: "Browse published books and categories", icon: "books.vertical.fill")
            }
            .buttonStyle(SoftPressStyle())
        }
    }

    private func adminSectionTitle(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .appFont(size: 19, weight: .bold)
                .foregroundColor(AppTheme.ink)
            Text(detail)
                .appFont(size: 13)
                .foregroundColor(AppTheme.secondaryInk)
        }
    }

    private func adminActionLabel(_ title: String, detail: String, icon: String) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(AppTheme.brandDeep)
                .frame(width: 44, height: 44)
                .background(AppTheme.brandSoft)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .appFont(size: 15, weight: .semibold)
                    .foregroundColor(AppTheme.ink)
                Text(detail)
                    .appFont(size: 13)
                    .foregroundColor(AppTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundColor(AppTheme.muted)
                .accessibilityHidden(true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .appCard(elevated: false)
    }

    private func recentItemIcon(_ item: LibraryItem) -> String {
        switch item.kind {
        case .video: return "play.rectangle.fill"
        case .note: return "note.text"
        case .paper, .document: return "doc.fill"
        }
    }

    private func recentItemSubtitle(_ item: LibraryItem) -> String {
        var parts = ["\(item.subjectName)", item.level.rawValue, item.section.displayName]
        if let folderId = item.folderId,
           let folder = library.folders.first(where: { $0.id == folderId }) {
            parts.append(folder.name)
        }
        return parts.joined(separator: " · ")
    }

    private func staffTip(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(AppTheme.brand)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .appFont(size: 14, weight: .semibold)
                    .foregroundColor(AppTheme.ink)
                Text(detail)
                    .appFont(size: 12.5)
                    .foregroundColor(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
    }
}

struct AdminHomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AdminHomeView()
        }
        .environmentObject(AuthManager.shared)
    }
}
