import SwiftUI

/// Content management home for tutors and admins.
struct AdminHomeView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject private var library = ContentLibrary.shared
    @ObservedObject private var bookStore = LibraryBookStore.shared
    @State private var showUploadSheet = false
    @State private var showLibraryBookUpload = false

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
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {

                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome, \(welcomeName)")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.ink)

                    Text(
                        authManager.isCloudEnabled
                            ? "You’re signed in as \(roleTitle). Uploads sync to Supabase so every student sees the same folders and files."
                            : "You’re signed in as \(roleTitle). Upload papers, notes, and lessons into folders (local mode — configure SupabaseConfig to sync online)."
                    )
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, AppTheme.horizontalPadding)
                .padding(.top, 10)

                HStack(spacing: 10) {
                    Image(systemName: authManager.currentUser?.isAdmin == true ? "shield.fill" : "person.crop.circle.badge.checkmark")
                        .foregroundColor(AppTheme.brandDeep)
                    Text(roleTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                    Spacer()
                    Text("\(library.items.count) uploads")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.brandDeep)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(AppTheme.brandSoft))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.brandSoft.opacity(0.7))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.brand.opacity(0.14), lineWidth: 1)
                )
                .padding(.horizontal, AppTheme.horizontalPadding)

                // Specialist scope for tutors (admins manage everything).
                if authManager.currentUser?.isTutor == true {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your specialist subjects")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(AppTheme.ink)
                        Text(authManager.currentUser?.managedSubjectsDisplay ?? "Not set")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppTheme.brandDeep)
                        Text("You can upload and delete only for these subjects. You may still open and study every other course.")
                            .font(.system(size: 12.5))
                            .foregroundColor(AppTheme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.card)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(AppTheme.brand.opacity(0.14), lineWidth: 1)
                    )
                    .padding(.horizontal, AppTheme.horizontalPadding)
                }

                VStack(spacing: 12) {
                    Button {
                        showUploadSheet = true
                    } label: {
                        Label("Upload Document or Lesson", systemImage: "arrow.up.doc.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                LinearGradient(
                                    colors: [AppTheme.brand, AppTheme.brandDeep],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .shadow(color: AppTheme.brand.opacity(0.25), radius: 10, x: 0, y: 5)
                    }

                    Button {
                        showLibraryBookUpload = true
                    } label: {
                        Label(
                            authManager.currentUser?.isAdmin == true
                                ? "Upload library book"
                                : "Submit library book for review",
                            systemImage: "books.vertical.fill"
                        )
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(AppTheme.card)
                        .foregroundColor(AppTheme.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AppTheme.brand.opacity(0.18), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink(destination: BrowseView()) {
                        Label("Browse published content", systemImage: "square.grid.2x2.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(AppTheme.card)
                            .foregroundColor(AppTheme.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AppTheme.stroke, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    if authManager.currentUser?.isAdmin == true {
                        NavigationLink(destination: LibraryBookReviewView()) {
                            HStack {
                                Label("Review library books", systemImage: "checkmark.seal.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                Spacer()
                                if bookStore.pendingReviewCount > 0 {
                                    Text("\(bookStore.pendingReviewCount)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(AppTheme.danger))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .padding(.horizontal, 16)
                            .background(AppTheme.card)
                            .foregroundColor(AppTheme.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AppTheme.brand.opacity(0.18), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)

                        NavigationLink(destination: SuperAdminDashboardView()) {
                            Label("Super Admin dashboard", systemImage: "shield.checkered")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(AppTheme.card)
                                .foregroundColor(AppTheme.ink)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(AppTheme.brand.opacity(0.18), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }

                    // Student personal data is super-admin only — tutors cannot access it.
                    if authManager.currentUser?.isAdmin == true {
                        NavigationLink(destination: StudentsAdminView()) {
                            Label("Student accounts", systemImage: "person.3.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(AppTheme.card)
                                .foregroundColor(AppTheme.ink)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(AppTheme.stroke, lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, AppTheme.horizontalPadding)

                // Tutor’s own library book submissions (pending / approved / rejected).
                if authManager.currentUser?.isTutor == true, !myLibrarySubmissions.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your library book submissions")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(AppTheme.ink)

                        ForEach(myLibrarySubmissions.prefix(8)) { book in
                            HStack(spacing: 12) {
                                Image(systemName: "book.closed.fill")
                                    .foregroundColor(AppTheme.brandDeep)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(book.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AppTheme.ink)
                                        .lineLimit(1)
                                    Text("\(book.category.rawValue) · \(book.approvalStatus.rawValue.capitalized)")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.muted)
                                    if book.approvalStatus == .rejected,
                                       let reason = book.reviewReason,
                                       !reason.isEmpty {
                                        Text("Reason: \(reason)")
                                            .font(.system(size: 11.5))
                                            .foregroundColor(AppTheme.danger)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(AppTheme.card)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AppTheme.stroke, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                }

                if !library.items.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent uploads")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(AppTheme.ink)

                        ForEach(library.items.prefix(8)) { item in
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(AppTheme.brandSoft)
                                        .frame(width: 42, height: 42)
                                    Image(systemName: recentItemIcon(item))
                                        .foregroundColor(AppTheme.brandDeep)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(AppTheme.ink)
                                        .lineLimit(1)
                                    Text(recentItemSubtitle(item))
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.muted)
                                        .lineLimit(1)
                                }
                                Spacer()
                                if authManager.currentUser?.canManageSubject(item.subjectName) == true {
                                    Button {
                                        library.remove(id: item.id)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(AppTheme.danger)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Delete \(item.title)")
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(AppTheme.card)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(AppTheme.stroke, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, AppTheme.horizontalPadding)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Staff tools")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(AppTheme.ink)

                    staffTip(
                        icon: "folder.badge.plus",
                        title: "Folders & delete",
                        detail: "Open a subject you manage → create year/topic folders, then use ··· or trash to delete a folder (keep files or remove everything) and individual uploads."
                    )
                    staffTip(
                        icon: "doc.badge.plus",
                        title: "Papers & notes",
                        detail: "Upload PDFs as past papers or study notes for Form 1–4 subjects."
                    )
                    staffTip(
                        icon: "video.badge.plus",
                        title: "Video lessons",
                        detail: "Attach a lesson with title, topic, and optional folder."
                    )
                    staffTip(
                        icon: "books.vertical.fill",
                        title: "Library books",
                        detail: authManager.currentUser?.isAdmin == true
                            ? "Publish books to the Academy Library, or review tutor submissions before learners can see them."
                            : "Submit library books for admin verification. You cannot publish books until an admin approves them."
                    )
                    if authManager.currentUser?.isAdmin == true {
                        staffTip(
                            icon: "shield.checkered",
                            title: "Super Admin",
                            detail: "View all pupils and tutors, block or remove accounts, and revoke tutor access."
                        )
                    }
                    if authManager.currentUser?.isAdmin == true {
                        staffTip(
                            icon: "person.2.fill",
                            title: "Student accounts",
                            detail: "Only super admins can view learner school, district, and grade details."
                        )
                    } else {
                        staffTip(
                            icon: "lock.shield.fill",
                            title: "Privacy",
                            detail: "Tutors cannot view student personal information. Upload only your specialist subject unless super admin grants more."
                        )
                    }
                    staffTip(
                        icon: "eye.fill",
                        title: "Student experience",
                        detail: "Use Home, Browse, and Saved to review content as learners do."
                    )
                }
                .padding(.horizontal, AppTheme.horizontalPadding)

                Spacer(minLength: 24)
            }
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle("Manage")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            bookStore.refreshInBackground()
        }
        .sheet(isPresented: $showUploadSheet) {
            UploadLessonView()
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showLibraryBookUpload) {
            UploadLibraryBookView()
                .environmentObject(authManager)
        }
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                Text(detail)
                    .font(.system(size: 12.5))
                    .foregroundColor(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
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
