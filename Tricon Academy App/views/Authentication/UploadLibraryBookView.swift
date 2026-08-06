import SwiftUI
import UniformTypeIdentifiers

/// Staff submit a book to the Academy Library. Tutors’ uploads stay **pending**
/// until a super admin approves them. Admins may approve their own uploads immediately.
struct UploadLibraryBookView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject private var bookStore = LibraryBookStore.shared

    @State private var title = ""
    @State private var author = ""
    @State private var summary = ""
    @State private var audience = "All levels"
    @State private var pagesText = ""
    @State private var category: LibraryCategory = .science
    @State private var documentURL: URL?
    @State private var documentFileName: String?
    @State private var showDocumentPicker = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    @State private var isSubmitting = false

    private var canSubmit: Bool {
        guard authManager.currentUser?.canManageContent == true else { return false }
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = author.trimmingCharacters(in: .whitespacesAndNewlines)
        return !t.isEmpty && !a.isEmpty && !isSubmitting
    }

    private var isAdmin: Bool {
        authManager.currentUser?.isAdmin == true
    }

    private var canManage: Bool {
        authManager.currentUser?.canManageContent == true
    }

    private var submitButtonTitle: String {
        isAdmin ? "Publish book" : "Submit for review"
    }

    private var successMessage: String {
        if isAdmin {
            return "“\(title)” is now available in the Academy Library."
        }
        return "“\(title)” was submitted. An admin will review it before learners can see it."
    }

    var body: some View {
        NavigationView {
            formContent
                .navigationTitle("Upload library book")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { cancelToolbar }
                .sheet(isPresented: $showDocumentPicker) {
                    DocumentPicker { url in
                        documentURL = url
                        documentFileName = url.lastPathComponent
                    }
                }
                .alert("Submitted", isPresented: $showSuccess) {
                    Button("Done") { dismiss() }
                } message: {
                    Text(successMessage)
                }
        }
    }

    @ViewBuilder
    private var formContent: some View {
        Form {
            if canManage {
                staffFormSections
            } else {
                Section {
                    Label(
                        "Only approved tutors and admins can submit library books.",
                        systemImage: "lock.fill"
                    )
                    .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var staffFormSections: some View {
        if !isAdmin {
            Section {
                Label(
                    "Your book will be sent for admin review. Students will only see it after it is approved.",
                    systemImage: "checkmark.shield"
                )
                .font(.footnote)
                .foregroundColor(.secondary)
            }
        }

        detailsSection
        fileSection

        if let errorMessage {
            Section {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
            }
        }

        submitSection
        footerSection
    }

    private var detailsSection: some View {
        Section("Book details") {
            TextField("Title", text: $title)
            TextField("Author", text: $author)
            TextField("Summary", text: $summary, axis: .vertical)
                .lineLimit(3...8)
            TextField("Audience (e.g. Forms 1–4)", text: $audience)
            TextField("Pages (optional)", text: $pagesText)
                .keyboardType(.numberPad)
            Picker("Category", selection: $category) {
                ForEach(LibraryCategory.allCases) { cat in
                    Text(cat.rawValue).tag(cat)
                }
            }
        }
    }

    private var fileSection: some View {
        Section("PDF file (optional)") {
            Button {
                showDocumentPicker = true
            } label: {
                Label(documentFileName ?? "Choose PDF", systemImage: "doc.fill")
            }
            if documentFileName != nil {
                Text("File attached — will upload with the book.")
                    .font(.caption)
                    .foregroundColor(AppTheme.brand)
            }
        }
    }

    private var submitSection: some View {
        Section {
            Button(action: submit) {
                HStack {
                    Spacer()
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Label(submitButtonTitle, systemImage: "arrow.up.circle.fill")
                            .fontWeight(.semibold)
                    }
                    Spacer()
                }
            }
            .disabled(!canSubmit)
        }
    }

    private var footerSection: some View {
        Section {
            Text(
                isAdmin
                    ? "As an admin, approved books appear in the Academy Library for all learners right away."
                    : "Tutors cannot publish library books directly. An admin must verify each submission."
            )
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }

    private var cancelToolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
    }

    private func submit() {
        guard canSubmit else { return }
        errorMessage = nil
        isSubmitting = true

        let pages = Int(pagesText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 1
        let uploaderId = authManager.currentUser?.id
        let uploaderName = authManager.currentUser?.fullName ?? "Staff"

        let book = bookStore.submitBook(
            title: title,
            author: author,
            summary: summary,
            category: category,
            audience: audience,
            pages: pages,
            fileURL: documentURL,
            uploaderId: uploaderId,
            uploaderName: uploaderName,
            autoApprove: isAdmin
        )

        isSubmitting = false
        if book != nil {
            showSuccess = true
        } else {
            errorMessage = "Could not submit the book. Check title and author, then try again."
        }
    }
}

struct UploadLibraryBookView_Previews: PreviewProvider {
    static var previews: some View {
        UploadLibraryBookView()
            .environmentObject(AuthManager.shared)
    }
}
