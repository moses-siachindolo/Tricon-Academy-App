import SwiftUI

/// Super-admin queue: approve or reject tutor-submitted Academy Library books.
struct LibraryBookReviewView: View {
    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject private var bookStore = LibraryBookStore.shared

    @State private var rejectTarget: UserLibraryBook?
    @State private var rejectReason = ""
    @State private var showRejectAlert = false

    private var isAdmin: Bool {
        authManager.currentUser?.isAdmin == true
    }

    private var pending: [UserLibraryBook] {
        bookStore.pendingBooks
    }

    var body: some View {
        content
            .background(AppTheme.canvas.ignoresSafeArea())
            .navigationTitle("Library book review")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { bookStore.refreshInBackground() }
            .alert("Reject book", isPresented: $showRejectAlert) {
                rejectAlertButtons
            } message: {
                rejectAlertMessage
            }
    }

    @ViewBuilder
    private var content: some View {
        if !isAdmin {
            reviewEmptyState(
                title: "Admins only",
                systemImage: "lock.shield",
                message: "Only super admins can verify library book submissions."
            )
        } else if pending.isEmpty {
            reviewEmptyState(
                title: "No books waiting",
                systemImage: "books.vertical",
                message: "When tutors submit library books, they appear here for review."
            )
        } else {
            pendingList
        }
    }

    private var pendingList: some View {
        List {
            Section {
                Text("Approve books before they appear for students. Rejected submissions stay hidden.")
                    .appFont(size: 13)
                    .foregroundColor(AppTheme.muted)
            }

            Section {
                ForEach(pending) { book in
                    LibraryBookReviewRow(
                        book: book,
                        onApprove: { bookStore.setApproval(id: book.id, status: .approved) },
                        onReject: {
                            rejectTarget = book
                            rejectReason = ""
                            showRejectAlert = true
                        }
                    )
                }
            } header: {
                Text("Pending review (\(pending.count))")
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private var rejectAlertButtons: some View {
        TextField("Reason (optional)", text: $rejectReason)
        Button("Reject", role: .destructive) {
            confirmReject()
        }
        Button("Cancel", role: .cancel) {
            rejectTarget = nil
        }
    }

    @ViewBuilder
    private var rejectAlertMessage: some View {
        if let title = rejectTarget?.title {
            Text("“\(title)” will stay hidden from learners.")
        } else {
            Text("This book will stay hidden from learners.")
        }
    }

    private func confirmReject() {
        guard let book = rejectTarget else { return }
        let trimmed = rejectReason.trimmingCharacters(in: .whitespacesAndNewlines)
        bookStore.setApproval(
            id: book.id,
            status: .rejected,
            reason: trimmed.isEmpty ? nil : trimmed
        )
        rejectTarget = nil
        rejectReason = ""
    }

    private func reviewEmptyState(title: String, systemImage: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .medium))
                .foregroundColor(AppTheme.brandDeep.opacity(0.7))
            Text(title)
                .appFont(size: 17, weight: .semibold)
                .foregroundColor(AppTheme.ink)
            Text(message)
                .appFont(size: 14)
                .foregroundColor(AppTheme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Row

private struct LibraryBookReviewRow: View {
    let book: UserLibraryBook
    let onApprove: () -> Void
    let onReject: () -> Void

    private var metaLine: String {
        "\(book.category.rawValue) · \(book.audience) · \(book.pages) pages"
    }

    private var uploaderLine: String {
        let name = book.uploaderName.isEmpty ? "Staff" : book.uploaderName
        return "Submitted by \(name)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            bookHeader
            actionButtons
        }
        .padding(.vertical, 6)
    }

    private var bookHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            coverIcon
            bookInfo
        }
    }

    private var coverIcon: some View {
        Image(systemName: "book.fill")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(AppTheme.iconGreen)
            .symbolRenderingMode(.monochrome)
            .frame(width: 44, height: 56)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.iconRadius, style: .continuous)
                    .fill(AppTheme.iconWell)
            )
    }

    private var bookInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(book.title)
                .appFont(size: 15, weight: .semibold)
                .foregroundColor(AppTheme.ink)
            Text(book.author)
                .appFont(size: 13, weight: .medium)
                .foregroundColor(AppTheme.secondaryInk)
            Text(metaLine)
                .appFont(size: 12)
                .foregroundColor(AppTheme.secondaryInk)
            Text(uploaderLine)
                .appFont(size: 12, weight: .medium)
                .foregroundColor(AppTheme.brandDeep)
            if !book.summary.isEmpty {
                Text(book.summary)
                    .appFont(size: 12.5)
                    .foregroundColor(AppTheme.muted)
                    .lineLimit(3)
            }
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button(action: onApprove) {
                Label("Approve", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .background(AppTheme.brandSoft)
                    .foregroundColor(AppTheme.brandDeep)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.iconRadius, style: .continuous))
            }
            .buttonStyle(SoftPressStyle())

            Button(action: onReject) {
                Label("Reject", systemImage: "xmark.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .background(AppTheme.dangerSoft)
                    .foregroundColor(AppTheme.danger)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.iconRadius, style: .continuous))
            }
            .buttonStyle(SoftPressStyle())
        }
    }
}

struct LibraryBookReviewView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LibraryBookReviewView()
        }
        .environmentObject(AuthManager.shared)
    }
}
