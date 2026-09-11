import SwiftUI

private extension RemoteProfile {
    var tutorSubjectsSummary: String {
        let subjects = asUser.managedSubjectNames
        return subjects.isEmpty ? "No subjects assigned" : subjects.joined(separator: " · ")
    }
}

// MARK: - Super Admin Dashboard

/// Platform overview for role `admin` only: pupils, tutors, all accounts, block/remove/revoke.
struct SuperAdminDashboardView: View {

    @EnvironmentObject private var authManager: AuthManager

    @State private var profiles: [RemoteProfile] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedSegment: AccountSegment = .all
    @State private var searchText = ""

    enum AccountSegment: String, CaseIterable, Identifiable {
        case all = "All"
        case students = "Pupils"
        case tutors = "Tutors"

        var id: String { rawValue }
    }

    private var students: [RemoteProfile] {
        profiles.filter { $0.userRole == .student }
    }

    private var tutors: [RemoteProfile] {
        profiles.filter { $0.userRole == .tutor }
    }

    private var pendingTutors: [RemoteProfile] {
        tutors.filter { $0.tutorApprovalStatus == TutorApprovalStatus.pending.rawValue }
    }

    private var admins: [RemoteProfile] {
        profiles.filter { $0.userRole == .admin }
    }

    private var segmentProfiles: [RemoteProfile] {
        switch selectedSegment {
        case .all: return profiles
        case .students: return students
        case .tutors: return tutors
        }
    }

    private var filtered: [RemoteProfile] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return segmentProfiles }
        return segmentProfiles.filter {
            $0.fullName.localizedCaseInsensitiveContains(q)
                || $0.email.localizedCaseInsensitiveContains(q)
                || $0.userRole.displayName.localizedCaseInsensitiveContains(q)
                || ($0.school?.localizedCaseInsensitiveContains(q) ?? false)
                || ($0.schoolDistrict?.localizedCaseInsensitiveContains(q) ?? false)
                || ($0.grade?.localizedCaseInsensitiveContains(q) ?? false)
                || ($0.phone?.localizedCaseInsensitiveContains(q) ?? false)
        }
    }

    var body: some View {
        Group {
            if isLoading && profiles.isEmpty {
                ProgressView("Loading platform accounts…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage, profiles.isEmpty {
                errorState(errorMessage)
            } else {
                List {
                    Section {
                        statsRow
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)

                    let subjectRequests = profiles.filter {
                        $0.userRole == .tutor
                            && !($0.pendingSubjectRequest?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                    }
                    if !subjectRequests.isEmpty {
                        Section("Tutor subject access requests") {
                            ForEach(subjectRequests) { profile in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(profile.fullName)
                                        .appFont(size: 14, weight: .semibold)
                                    Text("Requesting: \(profile.pendingSubjectRequest ?? "—")")
                                        .appFont(size: 12, weight: .medium)
                                        .foregroundColor(AppTheme.brandDeep)
                                    Text("Current majors: \(profile.subjectMajor ?? "—")")
                                        .appFont(size: 11.5)
                                        .foregroundColor(AppTheme.muted)
                                    HStack(spacing: 8) {
                                        Button("Approve") {
                                            Task {
                                                _ = await authManager.resolveExtraSubjectRequest(userId: profile.id, approve: true)
                                                await load()
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                        Button("Deny") {
                                            Task {
                                                _ = await authManager.resolveExtraSubjectRequest(userId: profile.id, approve: false)
                                                await load()
                                            }
                                        }
                                        .buttonStyle(.bordered)
                                        .controlSize(.small)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    Section {
                        Picker("Filter", selection: $selectedSegment) {
                            ForEach(AccountSegment.allCases) { seg in
                                Text(seg.rawValue).tag(seg)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)

                    Section {
                        if filtered.isEmpty {
                            Text(emptyCopy)
                                .appFont(size: 14)
                                .foregroundColor(AppTheme.muted)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 24)
                        } else {
                            ForEach(filtered) { profile in
                                NavigationLink(destination: SuperAdminAccountDetailView(profile: profile) {
                                    Task { await load() }
                                }) {
                                    accountRow(profile)
                                }
                            }
                        }
                    } header: {
                        Text(sectionHeader)
                    }
                }
                .listStyle(.insetGrouped)
                .searchable(text: $searchText, prompt: "Search name, email, school…")
            }
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle("Super Admin")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
    }

    private var sectionHeader: String {
        let n = filtered.count
        switch selectedSegment {
        case .all: return "\(n) account\(n == 1 ? "" : "s")"
        case .students: return "\(n) pupil\(n == 1 ? "" : "s")"
        case .tutors: return "\(n) tutor\(n == 1 ? "" : "s")"
        }
    }

    private var emptyCopy: String {
        searchText.isEmpty ? "No accounts in this list." : "No matches for your search."
    }

    private var statsRow: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                statCard(title: "Pupils", value: "\(students.count)", icon: "person.3.fill", color: AppTheme.brand)
                statCard(title: "Tutors", value: "\(tutors.count)", icon: "person.badge.shield.checkmark.fill", color: AppTheme.papers)
                statCard(title: "Total", value: "\(profiles.count)", icon: "person.2.fill", color: AppTheme.videos)
            }
            if !pendingTutors.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.bubble.fill")
                        .foregroundColor(AppTheme.warning)
                    Text("\(pendingTutors.count) tutor application\(pendingTutors.count == 1 ? "" : "s") awaiting your approval")
                        .appFont(size: 13, weight: .semibold)
                        .foregroundColor(AppTheme.ink)
                    Spacer()
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                        .fill(AppTheme.warning.opacity(0.12))
                )
            }
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .appFont(size: 22, weight: .bold, design: .rounded)
                .foregroundColor(AppTheme.ink)
            Text(title)
                .appFont(size: 11, weight: .medium)
                .foregroundColor(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
    }

    private func accountRow(_ profile: RemoteProfile) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(roleColor(profile.userRole).opacity(0.14))
                    .frame(width: 44, height: 44)
                Text(initials(profile.fullName))
                    .appFont(size: 14, weight: .bold)
                    .foregroundColor(roleColor(profile.userRole))
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(profile.fullName)
                        .appFont(size: 15, weight: .semibold)
                        .foregroundColor(AppTheme.ink)
                        .lineLimit(1)
                    if profile.isAccountBlocked {
                        Text("Blocked")
                            .appFont(size: 10, weight: .bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AppTheme.danger))
                    } else if profile.userRole == .tutor,
                              profile.tutorApprovalStatus == TutorApprovalStatus.pending.rawValue {
                        Text("Pending")
                            .appFont(size: 10, weight: .bold)
                            .foregroundColor(AppTheme.warning)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(AppTheme.warning.opacity(0.12)))
                    }
                }
                Text(profile.email)
                    .appFont(size: 12.5)
                    .foregroundColor(AppTheme.muted)
                    .lineLimit(1)

                if profile.userRole == .tutor {
                    Label("Subjects: \(profile.tutorSubjectsSummary)", systemImage: "books.vertical.fill")
                        .appFont(size: 12.5)
                        .foregroundColor(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 6) {
                    Text(profile.userRole.displayName)
                        .appFont(size: 11, weight: .semibold)
                        .foregroundColor(roleColor(profile.userRole))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(roleColor(profile.userRole).opacity(0.12)))

                    if profile.userRole == .student, let grade = profile.grade, !grade.isEmpty {
                        Text(grade)
                            .appFont(size: 11.5)
                            .foregroundColor(AppTheme.muted)
                    }
                    if let school = profile.school, !school.isEmpty {
                        Text(school)
                            .appFont(size: 11.5)
                            .foregroundColor(AppTheme.muted)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func roleColor(_ role: UserRole) -> Color {
        switch role {
        case .admin: return AppTheme.warning
        case .tutor: return AppTheme.papers
        case .student: return AppTheme.brand
        }
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        return String(parts.prefix(2).compactMap(\.first)).uppercased()
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28))
                .foregroundColor(AppTheme.danger)
            Text(message)
                .appFont(size: 14)
                .foregroundColor(AppTheme.muted)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await load() } }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppTheme.brandDeep)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @MainActor
    private func load() async {
        if profiles.isEmpty { isLoading = true }
        errorMessage = nil
        // Longer timeout: force-refresh + profile list can take a few seconds on cellular.
        let result: Result<[RemoteProfile], AuthError>
        do {
            result = try await withThrowingTaskGroup(of: Result<[RemoteProfile], AuthError>.self) { group in
                group.addTask { await authManager.fetchAllProfiles() }
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
            profiles = rows
            errorMessage = nil
        case .failure(let error):
            errorMessage = error.errorDescription
        }
    }
}

// MARK: - Account detail + actions

struct SuperAdminAccountDetailView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.presentationMode) private var presentationMode

    let profile: RemoteProfile
    var onChanged: () -> Void

    @State private var workingProfile: RemoteProfile
    @State private var actionError: String?
    @State private var isBusy = false
    @State private var confirmBlock = false
    @State private var confirmUnblock = false
    @State private var confirmRevokeTutor = false
    @State private var confirmRemove = false
    @State private var confirmApproveTutor = false
    @State private var confirmRejectTutor = false
    @State private var adminReason = ""

    init(profile: RemoteProfile, onChanged: @escaping () -> Void) {
        self.profile = profile
        self.onChanged = onChanged
        _workingProfile = State(initialValue: profile)
    }

    private var canManage: Bool {
        workingProfile.userRole != .admin && workingProfile.id != authManager.currentUser?.id
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                header

                infoCard(title: "Account") {
                    infoRow(icon: "envelope.fill", label: "Email", value: workingProfile.email)
                    if let phone = workingProfile.phone, !phone.isEmpty {
                        infoRow(icon: "phone.fill", label: "Phone", value: phone)
                    }
                    infoRow(icon: "person.fill", label: "Role", value: workingProfile.userRole.displayName)
                    infoRow(
                        icon: "lock.shield.fill",
                        label: "Status",
                        value: statusLabel
                    )
                    if let created = workingProfile.createdAt {
                        infoRow(
                            icon: "calendar",
                            label: "Joined",
                            value: created.formatted(date: .abbreviated, time: .omitted)
                        )
                    }
                }

                if workingProfile.userRole == .student {
                    infoCard(title: "School information") {
                        infoRow(icon: "building.2.fill", label: "School", value: workingProfile.school ?? "Not provided")
                        infoRow(icon: "mappin.and.ellipse", label: "District", value: workingProfile.schoolDistrict ?? "Not provided")
                        infoRow(icon: "graduationcap.fill", label: "Grade", value: workingProfile.grade ?? "Not provided")
                    }
                }

                if workingProfile.userRole == .tutor {
                    infoCard(title: "Tutor application") {
                        infoRow(icon: "checkmark.seal.fill", label: "Approval", value: workingProfile.tutorStatus.displayName)
                        infoRow(icon: "phone.fill", label: "Phone", value: workingProfile.phone ?? "Not provided")
                        infoRow(icon: "books.vertical.fill", label: "Highest education", value: workingProfile.highestEducation ?? "Not provided")
                        infoRow(icon: "building.columns.fill", label: "Last institution", value: workingProfile.lastInstitution ?? "Not provided")
                        infoRow(icon: "person.fill", label: "Gender", value: workingProfile.gender ?? "Not provided")
                        infoRow(icon: "mappin.and.ellipse", label: "Location / address", value: workingProfile.addressLocation ?? "Not provided")
                        infoRow(icon: "books.vertical.fill", label: "Subjects", value: workingProfile.tutorSubjectsSummary)
                        infoRow(icon: "person.2.fill", label: "Reference contacts", value: workingProfile.referenceContacts ?? "Not provided")
                        if let note = workingProfile.adminStatusReason, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            infoRow(icon: "text.bubble.fill", label: "Admin note", value: note)
                        }
                    }
                } else if let note = workingProfile.adminStatusReason, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    infoCard(title: "Admin note") {
                        infoRow(icon: "text.bubble.fill", label: "Reason", value: note)
                    }
                }

                if canManage {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Admin actions")
                            .appFont(size: 15, weight: .bold)
                            .foregroundColor(AppTheme.ink)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Reason for reject / block (required)")
                                .appFont(size: 12, weight: .semibold)
                                .foregroundColor(AppTheme.muted)
                            TextField("e.g. Too many tutors for this subject right now", text: $adminReason)
                                .font(.system(size: 14))
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                                        .fill(AppTheme.canvas)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                                        .stroke(AppTheme.stroke, lineWidth: 1)
                                )
                        }
                        .padding(.bottom, 4)

                        if workingProfile.userRole == .tutor,
                           workingProfile.tutorApprovalStatus == TutorApprovalStatus.pending.rawValue
                            || workingProfile.tutorApprovalStatus == TutorApprovalStatus.rejected.rawValue
                            || workingProfile.tutorApprovalStatus == TutorApprovalStatus.none.rawValue {
                            actionButton(
                                title: "Approve tutor",
                                systemImage: "checkmark.circle.fill",
                                tint: AppTheme.brand
                            ) { confirmApproveTutor = true }
                            if workingProfile.tutorApprovalStatus == TutorApprovalStatus.pending.rawValue {
                                actionButton(
                                    title: "Reject application",
                                    systemImage: "xmark.circle.fill",
                                    tint: AppTheme.warning
                                ) { confirmRejectTutor = true }
                            }
                        }

                        if workingProfile.isAccountBlocked {
                            actionButton(
                                title: "Unblock account",
                                systemImage: "lock.open.fill",
                                tint: AppTheme.brand
                            ) { confirmUnblock = true }
                        } else {
                            actionButton(
                                title: "Block account",
                                systemImage: "hand.raised.fill",
                                tint: AppTheme.warning
                            ) { confirmBlock = true }
                        }

                        if workingProfile.userRole == .tutor,
                           workingProfile.tutorStatus == .approved {
                            actionButton(
                                title: "Remove tutor access",
                                systemImage: "person.badge.minus",
                                tint: AppTheme.papers
                            ) { confirmRevokeTutor = true }
                        }

                        actionButton(
                            title: "Remove account",
                            systemImage: "trash.fill",
                            tint: AppTheme.danger
                        ) { confirmRemove = true }
                    }
                    .padding(.top, 4)
                } else {
                    Text(workingProfile.userRole == .admin
                         ? "Admin accounts are protected from these actions."
                         : "You cannot manage your own account from this screen.")
                        .appFont(size: 13)
                        .foregroundColor(AppTheme.muted)
                        .padding(.top, 4)
                }

                if let actionError {
                    Text(actionError)
                        .appFont(size: 13.5, weight: .medium)
                        .foregroundColor(AppTheme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if isBusy {
                    ProgressView()
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, AppTheme.horizontalPadding)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .navigationTitle("Account")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(isBusy)
        .confirmationDialog("Block this account?", isPresented: $confirmBlock, titleVisibility: .visible) {
            Button("Block", role: .destructive) {
                Task { await runBlock(true) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They will see your reason when they try to log in. Reason: \(adminReason.isEmpty ? "(enter a reason above first)" : adminReason)")
        }
        .confirmationDialog("Unblock this account?", isPresented: $confirmUnblock, titleVisibility: .visible) {
            Button("Unblock") {
                Task { await runBlock(false) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Remove tutor access?", isPresented: $confirmRevokeTutor, titleVisibility: .visible) {
            Button("Remove tutor access", role: .destructive) {
                Task { await runRevokeTutor() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(workingProfile.fullName) will become a student and lose upload / manage access.")
        }
        .confirmationDialog("Remove this account permanently?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Remove account", role: .destructive) {
                Task { await runRemove() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(workingProfile.fullName) will lose access to Tricon Academy and disappear from the active list.")
        }
        .confirmationDialog("Approve this tutor?", isPresented: $confirmApproveTutor, titleVisibility: .visible) {
            Button("Approve tutor") {
                Task { await runTutorApproval(.approved) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(workingProfile.fullName) will get Manage access and can upload lessons.")
        }
        .confirmationDialog("Reject this application?", isPresented: $confirmRejectTutor, titleVisibility: .visible) {
            Button("Reject", role: .destructive) {
                Task { await runTutorApproval(.rejected) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They will see your reason when they log in: \(adminReason.isEmpty ? "(enter a reason above first)" : adminReason)")
        }
    }

    private var statusLabel: String {
        if workingProfile.isAccountRemoved { return "Removed" }
        if workingProfile.isAccountBlocked { return "Blocked" }
        if workingProfile.userRole == .tutor {
            return workingProfile.tutorStatus.displayName
        }
        return "Active"
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.brand, AppTheme.brandFillDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 84, height: 84)
                Text(initials(workingProfile.fullName))
                    .appFont(size: 28, weight: .bold)
                    .foregroundColor(.white)
            }
            Text(workingProfile.fullName)
                .appFont(size: 22, weight: .bold, design: .rounded)
                .foregroundColor(AppTheme.ink)
            Text(workingProfile.userRole.displayName)
                .appFont(size: 13, weight: .semibold)
                .foregroundColor(AppTheme.brandDeep)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(AppTheme.brandSoft))
        }
        .frame(maxWidth: .infinity)
    }

    private func infoCard(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .appFont(size: 15, weight: .bold)
                .foregroundColor(AppTheme.ink)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
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
                    .appFont(size: 12, weight: .medium)
                    .foregroundColor(AppTheme.muted)
                Text(value)
                    .appFont(size: 15, weight: .semibold)
                    .foregroundColor(AppTheme.ink)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    private func actionButton(title: String, systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
                .background(tint.opacity(0.12))
                .foregroundColor(tint)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous))
        }
        .buttonStyle(SoftPressStyle())
    }

    private func initials(_ name: String) -> String {
        let parts = name.split(separator: " ")
        return String(parts.prefix(2).compactMap(\.first)).uppercased()
    }

    @MainActor
    private func runBlock(_ blocked: Bool) async {
        actionError = nil
        isBusy = true
        defer { isBusy = false }
        let result = await authManager.setAccountBlocked(
            userId: workingProfile.id,
            blocked: blocked,
            reason: blocked ? adminReason : nil
        )
        switch result {
        case .success:
            workingProfile.isBlocked = blocked
            workingProfile.adminStatusReason = blocked ? adminReason : nil
            if !blocked { adminReason = "" }
            onChanged()
        case .failure(let error):
            actionError = error.errorDescription
        }
    }

    @MainActor
    private func runRevokeTutor() async {
        actionError = nil
        isBusy = true
        defer { isBusy = false }
        let result = await authManager.revokeTutorAccess(userId: workingProfile.id)
        switch result {
        case .success:
            workingProfile.role = UserRole.student.rawValue
            onChanged()
        case .failure(let error):
            actionError = error.errorDescription
        }
    }

    @MainActor
    private func runRemove() async {
        actionError = nil
        isBusy = true
        defer { isBusy = false }
        let result = await authManager.removeAccount(userId: workingProfile.id)
        switch result {
        case .success:
            onChanged()
            presentationMode.wrappedValue.dismiss()
        case .failure(let error):
            actionError = error.errorDescription
        }
    }

    @MainActor
    private func runTutorApproval(_ status: TutorApprovalStatus) async {
        actionError = nil
        isBusy = true
        defer { isBusy = false }
        let result = await authManager.setTutorApproval(
            userId: workingProfile.id,
            status: status,
            reason: status == .rejected ? adminReason : nil
        )
        switch result {
        case .success:
            workingProfile.tutorApprovalStatus = status.rawValue
            workingProfile.adminStatusReason = status == .rejected ? adminReason : nil
            if status == .approved { adminReason = "" }
            onChanged()
        case .failure(let error):
            actionError = error.errorDescription
        }
    }
}

struct SuperAdminDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SuperAdminDashboardView()
        }
        .environmentObject(AuthManager.shared)
    }
}
