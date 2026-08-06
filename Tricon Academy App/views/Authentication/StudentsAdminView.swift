import SwiftUI

/// Super-admin only list of registered students with school / district / grade.
/// Tutors must not see student personal information.
struct StudentsAdminView: View {

    @EnvironmentObject private var authManager: AuthManager

    @State private var students: [RemoteProfile] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var searchText = ""

    private var isSuperAdmin: Bool {
        authManager.currentUser?.isAdmin == true
    }

    private var filtered: [RemoteProfile] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return students }
        return students.filter {
            $0.fullName.localizedCaseInsensitiveContains(q)
                || $0.email.localizedCaseInsensitiveContains(q)
                || ($0.school?.localizedCaseInsensitiveContains(q) ?? false)
                || ($0.schoolDistrict?.localizedCaseInsensitiveContains(q) ?? false)
                || ($0.grade?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    var body: some View {
        Group {
            if !isSuperAdmin {
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 32))
                        .foregroundColor(AppTheme.muted)
                    Text("Super admin only")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Tutors cannot view student personal information.")
                        .font(.system(size: 13.5))
                        .foregroundColor(AppTheme.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if isLoading {
                ProgressView("Loading students…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(AppTheme.danger)
                    Text(errorMessage)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.muted)
                        .multilineTextAlignment(.center)
                    Button("Retry") { Task { await load() } }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.brandDeep)
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if students.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.3")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(AppTheme.muted)
                    Text("No students yet")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                    Text("When learners register, they will appear here with their school details.")
                        .font(.system(size: 13.5))
                        .foregroundColor(AppTheme.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(28)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section {
                        ForEach(filtered) { student in
                            NavigationLink(destination: StudentDetailAdminView(profile: student)) {
                                studentRow(student)
                            }
                        }
                    } header: {
                        Text("\(filtered.count) student\(filtered.count == 1 ? "" : "s")")
                    }
                }
                .listStyle(.insetGrouped)
                .searchable(text: $searchText, prompt: "Search name, school, grade")
            }
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle("Students")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { if isSuperAdmin { await load() } }
        .task { if isSuperAdmin { await load() } }
    }

    private func studentRow(_ student: RemoteProfile) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.brandSoft)
                    .frame(width: 44, height: 44)
                Text(initials(for: student.fullName))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.brandDeep)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(student.fullName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
                Text(student.email)
                    .font(.system(size: 12.5))
                    .foregroundColor(AppTheme.muted)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let grade = student.grade, !grade.isEmpty {
                        Text(grade)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(AppTheme.brandDeep)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(AppTheme.brandSoft))
                    }
                    if let school = student.school, !school.isEmpty {
                        Text(school)
                            .font(.system(size: 11.5))
                            .foregroundColor(AppTheme.muted)
                            .lineLimit(1)
                    } else {
                        Text("Profile incomplete")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(AppTheme.danger.opacity(0.85))
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func initials(for name: String) -> String {
        let parts = name.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }

    @MainActor
    private func load() async {
        isLoading = students.isEmpty
        errorMessage = nil
        // Timeout so a hung network cannot leave Students stuck forever.
        let result: Result<[RemoteProfile], AuthError>
        do {
            result = try await withThrowingTaskGroup(of: Result<[RemoteProfile], AuthError>.self) { group in
                group.addTask { await authManager.fetchStudentProfiles() }
                group.addTask {
                    try await Task.sleep(nanoseconds: 20_000_000_000)
                    throw CancellationError()
                }
                guard let first = try await group.next() else {
                    throw CancellationError()
                }
                group.cancelAll()
                return first
            }
        } catch {
            result = .failure(.remote("Server took too long. Check your connection or Supabase project status."))
        }
        isLoading = false
        switch result {
        case .success(let rows):
            students = rows
            errorMessage = nil
        case .failure(let error):
            errorMessage = error.errorDescription
        }
    }
}

// MARK: - Student detail (admin)

struct StudentDetailAdminView: View {
    let profile: RemoteProfile

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.brand, AppTheme.brandDeep],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 84, height: 84)
                        Text(initials)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                    }

                    Text(profile.fullName)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.ink)

                    Text("Student account")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(AppTheme.brandDeep)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AppTheme.brandSoft))
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

                infoCard(title: "Contact") {
                    infoRow(icon: "envelope.fill", label: "Email", value: profile.email)
                    if let phone = profile.phone, !phone.isEmpty {
                        infoRow(icon: "phone.fill", label: "Phone", value: phone)
                    }
                }

                infoCard(title: "School information") {
                    infoRow(icon: "building.2.fill", label: "School", value: profile.school ?? "Not provided")
                    infoRow(icon: "mappin.and.ellipse", label: "District", value: profile.schoolDistrict ?? "Not provided")
                    infoRow(icon: "graduationcap.fill", label: "Grade", value: profile.grade ?? "Not provided")
                    infoRow(
                        icon: "checkmark.seal.fill",
                        label: "Profile",
                        value: (profile.profileCompleted == true || hasSchoolInfo) ? "Complete" : "Incomplete"
                    )
                }

                if let created = profile.createdAt {
                    Text("Joined \(created.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 12.5))
                        .foregroundColor(AppTheme.muted)
                }
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.bottom, 32)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle("Student")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hasSchoolInfo: Bool {
        let s = profile.school?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let d = profile.schoolDistrict?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let g = profile.grade?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return !s.isEmpty && !d.isEmpty && !g.isEmpty
    }

    private var initials: String {
        let parts = profile.fullName.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }

    private func infoCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(AppTheme.ink)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.brand)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.muted)
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.ink)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

struct StudentsAdminView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            StudentsAdminView()
        }
        .environmentObject(AuthManager.shared)
    }
}
