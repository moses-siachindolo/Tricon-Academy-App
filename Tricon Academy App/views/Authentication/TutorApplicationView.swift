import SwiftUI

// MARK: - Tutor application (after registration)

/// Who can be a tutor: anyone who registers as Tutor, then passes super-admin verification.
/// Blue subject-style chrome — matches login / register entry flow.
struct TutorApplicationView: View {

    @EnvironmentObject private var authManager: AuthManager

    @State private var phone = ""
    @State private var highestEducation = ""
    @State private var lastInstitution = ""
    @State private var gender = "Prefer not to say"
    @State private var addressLocation = ""
    @State private var selectedSubjects: Set<String> = []
    @State private var referenceContacts = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var appeared = false
    @State private var loadedDetails = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let blue = AppTheme.authBlue
    private let blueDeep = AppTheme.authBlueDeep
    private let blueSoft = AppTheme.authBlueSoft

    private let genders = ["Prefer not to say", "Female", "Male"]
    private let educationLevels = [
        "Grade 12 / Secondary",
        "Certificate",
        "Diploma",
        "Bachelor's degree",
        "Master's degree",
        "Doctorate / PhD",
        "Other"
    ]

    private var catalogueSubjects: [String] {
        User.catalogueSubjectNames
    }

    private var subjectMajorValue: String {
        catalogueSubjects.filter { selectedSubjects.contains($0) }.joined(separator: ", ")
    }

    private var canSubmit: Bool {
        !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !highestEducation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !lastInstitution.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !gender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !addressLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !selectedSubjects.isEmpty
            && !referenceContacts.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isLoading
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header
                    .padding(.top, 18)
                    .padding(.bottom, 18)

                formCard
                    .disabled(isLoading)
                    .padding(.bottom, 14)

                if let errorMessage {
                    Text(errorMessage)
                        .appFont(size: 13.5, weight: .medium)
                        .foregroundColor(AppTheme.danger)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 12)
                }

                Button {
                    Task { await submit() }
                } label: {
                    HStack(spacing: 8) {
                        if isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text("Submit for approval")
                                .appFont(size: 15.5, weight: .semibold)
                        }
                    }
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .disabled(!canSubmit)
                .padding(.bottom, 12)

                Button("Sign out") { authManager.logout() }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.muted)
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
            .opacity(appeared ? 1 : 0)
        }
        .background(AppTheme.authBlueWash)
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) { appeared = true }
            guard !loadedDetails, let user = authManager.currentUser else { return }
            loadedDetails = true
            phone = user.phone ?? ""
            highestEducation = user.highestEducation ?? ""
            lastInstitution = user.lastInstitution ?? ""
            gender = genders.contains(user.gender ?? "") ? (user.gender ?? "Prefer not to say") : "Prefer not to say"
            addressLocation = user.addressLocation ?? ""
            let majors = User.parseSubjectList(user.subjectMajor)
            selectedSubjects = Set(catalogueSubjects.filter { name in majors.contains { User.subjectsMatch($0, name) } })
            referenceContacts = user.referenceContacts ?? ""
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(blueSoft).frame(width: 80, height: 80)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(blueDeep)
            }
            Text("Tutor verification")
                .appFont(size: 22, weight: .bold)
                .foregroundColor(AppTheme.ink)
            Text("Anyone can apply to teach on Tricon Academy. A super admin must verify your details before you get tutor access.")
                .appFont(size: 13.5, weight: .medium)
                .foregroundColor(AppTheme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your details")
                .appFont(size: 15, weight: .bold)
                .foregroundColor(AppTheme.ink)

            labeledField("Phone number", "e.g. 0976…") {
                TextField("Phone number", text: $phone)
                    .keyboardType(.phonePad)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Highest education attained")
                    .appFont(size: 12.5, weight: .semibold)
                    .foregroundColor(AppTheme.muted)
                Picker("Education", selection: $highestEducation) {
                    Text("Select…").tag("")
                    ForEach(educationLevels, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(fieldBackground)
            }

            labeledField("University or school last attended", "Institution name") {
                TextField("Last institution", text: $lastInstitution)
                    .textInputAutocapitalization(.words)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Gender")
                    .appFont(size: 12.5, weight: .semibold)
                    .foregroundColor(AppTheme.muted)
                Picker("Gender", selection: $gender) {
                    ForEach(genders, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
            }

            labeledField("Location / address", "Town, district, or full address") {
                TextField("Location or address", text: $addressLocation)
                    .textInputAutocapitalization(.words)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Specialist subjects")
                    .appFont(size: 12.5, weight: .semibold)
                    .foregroundColor(AppTheme.muted)
                Text("Pick the course(s) you teach. You may upload and delete only for these; every other subject stays view-only.")
                    .appFont(size: 12)
                    .foregroundColor(AppTheme.muted.opacity(0.9))
                LazyVGrid(columns: dynamicTypeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                    ForEach(catalogueSubjects, id: \.self) { name in
                        let on = selectedSubjects.contains(name)
                        Button {
                            if on { selectedSubjects.remove(name) } else { selectedSubjects.insert(name) }
                        } label: {
                            Text(name)
                                .appFont(size: 12.5, weight: .semibold)
                                .foregroundColor(on ? .white : AppTheme.ink)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(minHeight: 44)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: AppTheme.iconRadius, style: .continuous)
                                        .fill(on ? blueDeep : AppTheme.stroke)
                                )
                        }
                        .buttonStyle(SoftPressStyle())
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
                if !selectedSubjects.isEmpty {
                    Text("Selected: \(subjectMajorValue)")
                        .appFont(size: 12, weight: .medium)
                        .foregroundColor(blueDeep)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Reference contacts")
                    .appFont(size: 12.5, weight: .semibold)
                    .foregroundColor(AppTheme.muted)
                Text("Names, roles, and phone/email of people or authorities who can confirm your details.")
                    .appFont(size: 12)
                    .foregroundColor(AppTheme.muted.opacity(0.9))
                TextEditor(text: $referenceContacts)
                    .frame(minHeight: 100)
                    .padding(10)
                    .background(fieldBackground)
                    .scrollContentBackground(.hidden)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .stroke(blue.opacity(0.12), lineWidth: 1)
        )
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
            .fill(AppTheme.canvas)
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                    .stroke(blue.opacity(0.12), lineWidth: 1)
            )
    }

    private func labeledField<Content: View>(
        _ title: String,
        _ placeholder: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .appFont(size: 12.5, weight: .semibold)
                .foregroundColor(AppTheme.muted)
            content()
                .font(.system(size: 15))
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(fieldBackground)
        }
    }

    @MainActor
    private func submit() async {
        errorMessage = nil
        guard canSubmit else {
            errorMessage = "Please fill in every field."
            return
        }
        isLoading = true
        defer { isLoading = false }

        let result = await authManager.submitTutorApplication(
            phone: phone,
            highestEducation: highestEducation,
            lastInstitution: lastInstitution,
            gender: gender,
            addressLocation: addressLocation,
            subjectMajor: subjectMajorValue,
            referenceContacts: referenceContacts
        )
        if case .failure(let error) = result {
            errorMessage = error.errorDescription ?? "Could not submit. Try again."
        }
    }
}

// MARK: - Waiting for super-admin approval

struct TutorPendingApprovalView: View {

    @EnvironmentObject private var authManager: AuthManager
    @State private var isRefreshing = false
    @State private var notice: String?

    private let blue = AppTheme.authBlue
    private let blueDeep = AppTheme.authBlueDeep
    private let blueSoft = AppTheme.authBlueSoft

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Spacer(minLength: 24)

                ZStack {
                    Circle()
                        .fill(blueSoft)
                        .frame(width: 96, height: 96)
                    Image(systemName: "hourglass")
                        .font(.system(size: 38, weight: .medium))
                        .foregroundColor(blueDeep)
                }

                VStack(spacing: 10) {
                    Text("Application under review")
                        .appFont(size: 22, weight: .bold)
                        .foregroundColor(AppTheme.ink)
                        .multilineTextAlignment(.center)

                    Text("Your details were submitted successfully. A super admin will review your application.")
                        .appFont(size: 14.5, weight: .medium)
                        .foregroundColor(AppTheme.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label("How to check your result", systemImage: "info.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.ink)

                    Text("Tap Check status now to see the latest decision. You can also return later using the same email and password.")
                        .appFont(size: 13, weight: .medium)
                        .foregroundColor(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                        .fill(blueSoft.opacity(0.85))
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("Not approved after 2 days?")
                        .appFont(size: 14, weight: .bold)
                        .foregroundColor(AppTheme.ink)

                    Text(AcademySupport.approvalWaitMessage)
                        .appFont(size: 13, weight: .medium)
                        .foregroundColor(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    contactRow(
                        icon: "phone.fill",
                        title: "Call / WhatsApp",
                        value: AcademySupport.phoneDisplay,
                        url: AcademySupport.phoneURL
                    )
                    contactRow(
                        icon: "envelope.fill",
                        title: "Academy email",
                        value: AcademySupport.email,
                        url: AcademySupport.emailURL
                    )
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                        .fill(AppTheme.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                        .stroke(blue.opacity(0.12), lineWidth: 1)
                )

                if let notice {
                    Text(notice)
                        .appFont(size: 13.5, weight: .medium)
                        .foregroundColor(blueDeep)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await refresh() }
                } label: {
                    HStack {
                        if isRefreshing { ProgressView() }
                        Text(isRefreshing ? "Checking…" : "Check status now")
                            .appFont(size: 14.5, weight: .semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 48)
                    .background(blueSoft)
                    .foregroundColor(blueDeep)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous))
                }
                .disabled(isRefreshing)

                Button("Log out") {
                    authManager.logout()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(blueDeep)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.authBlueWash)
    }

    private func contactRow(icon: String, title: String, value: String, url: URL?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .appFont(size: 12, weight: .medium)
                    .foregroundColor(AppTheme.muted)
                if let url {
                    Link(value, destination: url)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                } else {
                    Text(value)
                        .appFont(size: 14.5, weight: .semibold)
                        .foregroundColor(AppTheme.ink)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    @MainActor
    private func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        notice = nil
        defer { isRefreshing = false }
        await authManager.refreshCurrentUserProfile()
        let status = authManager.currentUser?.tutorApprovalStatus
        if status == TutorApprovalStatus.approved.rawValue {
            notice = "You're approved. Opening the app…"
        } else if status == TutorApprovalStatus.rejected.rawValue {
            notice = "Your application was rejected. Opening the decision screen…"
        } else {
            notice = "Your current status is pending approval. You can check again later."
        }
    }
}

// MARK: - Rejected application (with admin reason)

struct TutorRejectedView: View {

    @EnvironmentObject private var authManager: AuthManager
    @State private var isBusy = false
    @State private var errorMessage: String?

    private let blue = AppTheme.authBlue
    private let blueDeep = AppTheme.authBlueDeep
    private let blueSoft = AppTheme.authBlueSoft

    private var reason: String {
        let r = authManager.currentUser?.adminStatusReason?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return r.isEmpty
            ? "No detailed reason was provided. You may contact Tricon Academy for more information."
            : r
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Spacer(minLength: 28)

                ZStack {
                    Circle()
                        .fill(AppTheme.danger.opacity(0.12))
                        .frame(width: 96, height: 96)
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundColor(AppTheme.danger)
                }

                VStack(spacing: 10) {
                    Text("Application not approved")
                        .appFont(size: 22, weight: .bold)
                        .foregroundColor(AppTheme.ink)
                        .multilineTextAlignment(.center)

                    Text("Your tutor application was reviewed and could not be approved at this time.")
                        .appFont(size: 14.5, weight: .medium)
                        .foregroundColor(AppTheme.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Reason from Tricon Academy")
                        .appFont(size: 13.5, weight: .bold)
                        .foregroundColor(AppTheme.ink)
                    Text(reason)
                        .appFont(size: 14.5)
                        .foregroundColor(AppTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                        .fill(AppTheme.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                        .stroke(AppTheme.danger.opacity(0.2), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Questions?")
                        .appFont(size: 13.5, weight: .bold)
                        .foregroundColor(AppTheme.ink)
                    Text("Call \(AcademySupport.phoneDisplay) or email \(AcademySupport.email). Use Log in with this same account — do not create a new one.")
                        .appFont(size: 13, weight: .medium)
                        .foregroundColor(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                        .fill(blueSoft.opacity(0.85))
                )

                if let errorMessage {
                    Text(errorMessage)
                        .appFont(size: 13.5, weight: .medium)
                        .foregroundColor(AppTheme.danger)
                }

                Button {
                    Task { await resubmit() }
                } label: {
                    HStack {
                        if isBusy { ProgressView().tint(.white) }
                        Text(isBusy ? "Opening form…" : "Update details & resubmit")
                            .appFont(size: 15.5, weight: .semibold)
                    }
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .disabled(isBusy)

                Button("Log out") { authManager.logout() }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.muted)
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.authBlueWash)
    }

    @MainActor
    private func resubmit() async {
        guard !isBusy else { return }
        errorMessage = nil
        isBusy = true
        defer { isBusy = false }
        let result = await authManager.beginTutorResubmit()
        if case .failure(let error) = result {
            errorMessage = error.errorDescription
        }
    }
}

struct TutorApplicationView_Previews: PreviewProvider {
    static var previews: some View {
        TutorApplicationView()
            .environmentObject(AuthManager.shared)
        TutorPendingApprovalView()
            .environmentObject(AuthManager.shared)
        TutorRejectedView()
            .environmentObject(AuthManager.shared)
    }
}
