import SwiftUI

// MARK: - Tutor application (after registration)

/// Who can be a tutor: anyone who registers as Tutor, then passes super-admin verification.
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

    private let genders = ["Female", "Male"]
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
                    .padding(.top, 20)
                    .padding(.bottom, 22)

                formCard
                    .padding(.bottom, 16)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13.5, weight: .medium))
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
                                .font(.system(size: 16, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: canSubmit
                                ? [AppTheme.brand, AppTheme.brandDeep]
                                : [Color.gray.opacity(0.35), Color.gray.opacity(0.35)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(!canSubmit)
                .buttonStyle(AuthPressStyle())
                .padding(.bottom, 12)

                Button("Sign out") { authManager.logout() }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.muted)
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 22)
            .opacity(appeared ? 1 : 0)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) { appeared = true }
            if let p = authManager.currentUser?.phone, !p.isEmpty { phone = p }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(AppTheme.brandSoft).frame(width: 88, height: 88)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundColor(AppTheme.brandDeep)
            }
            Text("Tutor verification")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.ink)
            Text("Anyone can apply to teach on Tricon Academy. A super admin must verify your details before you get tutor access.")
                .font(.system(size: 14.5))
                .foregroundColor(AppTheme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your details")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppTheme.ink)

            labeledField("Phone number", "e.g. 0976…") {
                TextField("Phone number", text: $phone)
                    .keyboardType(.phonePad)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Highest education attained")
                    .font(.system(size: 13, weight: .semibold))
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.muted)
                Picker("Gender", selection: $gender) {
                    ForEach(genders, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            labeledField("Location / address", "Town, district, or full address") {
                TextField("Location or address", text: $addressLocation)
                    .textInputAutocapitalization(.words)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Specialist subjects")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.muted)
                Text("Pick the course(s) you teach. You may upload and delete only for these; every other subject stays view-only.")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.muted.opacity(0.9))
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                    ForEach(catalogueSubjects, id: \.self) { name in
                        let on = selectedSubjects.contains(name)
                        Button {
                            if on { selectedSubjects.remove(name) } else { selectedSubjects.insert(name) }
                        } label: {
                            Text(name)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(on ? .white : AppTheme.ink)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(on ? AppTheme.brandDeep : AppTheme.stroke)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                if !selectedSubjects.isEmpty {
                    Text("Selected: \(subjectMajorValue)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppTheme.brandDeep)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Reference contacts")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.muted)
                Text("Names, roles, and phone/email of people or authorities who can confirm your details.")
                    .font(.system(size: 12))
                    .foregroundColor(AppTheme.muted.opacity(0.9))
                TextEditor(text: $referenceContacts)
                    .frame(minHeight: 100)
                    .padding(10)
                    .background(fieldBackground)
                    .scrollContentBackground(.hidden)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.stroke, lineWidth: 1)
        )
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppTheme.canvas)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppTheme.stroke, lineWidth: 1)
            )
    }

    private func labeledField<Content: View>(
        _ title: String,
        _ placeholder: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppTheme.muted)
            content()
                .font(.system(size: 16))
                .padding(.horizontal, 14)
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

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                Spacer(minLength: 24)

                ZStack {
                    Circle()
                        .fill(AppTheme.brandSoft)
                        .frame(width: 100, height: 100)
                    Image(systemName: "hourglass")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(AppTheme.brandDeep)
                }

                VStack(spacing: 10) {
                    Text("Application under review")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.ink)
                        .multilineTextAlignment(.center)

                    Text("Your details were submitted successfully. A super admin will review your application.")
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label("How to check your result", systemImage: "info.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppTheme.ink)

                    Text("Do not create a new account. Log out, then log in later with the same email and password to see if you were approved, rejected, or still pending.")
                        .font(.system(size: 13.5))
                        .foregroundColor(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.brandSoft.opacity(0.65))
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text("Not approved after 2 days?")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(AppTheme.ink)

                    Text(AcademySupport.approvalWaitMessage)
                        .font(.system(size: 13.5))
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
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppTheme.stroke, lineWidth: 1)
                )

                if let notice {
                    Text(notice)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(AppTheme.brandDeep)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await refresh() }
                } label: {
                    HStack {
                        if isRefreshing { ProgressView() }
                        Text(isRefreshing ? "Checking…" : "Check status now")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppTheme.brandSoft)
                    .foregroundColor(AppTheme.brandDeep)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(isRefreshing)

                Button("Log out — check later by logging in") {
                    authManager.logout()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.brandDeep)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 22)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
    }

    private func contactRow(icon: String, title: String, value: String, url: URL?) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppTheme.brand)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.muted)
                if let url {
                    Link(value, destination: url)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                } else {
                    Text(value)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.ink)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    @MainActor
    private func refresh() async {
        isRefreshing = true
        notice = nil
        defer { isRefreshing = false }
        await authManager.refreshCurrentUserProfile()
        let status = authManager.currentUser?.tutorApprovalStatus
        if status == TutorApprovalStatus.approved.rawValue || status == nil {
            notice = "You're approved. Opening the app…"
        } else if status == TutorApprovalStatus.rejected.rawValue {
            notice = "Your application was rejected. Opening the decision screen…"
        } else {
            notice = "Still waiting for approval. Log out and log in later — do not register again."
        }
    }
}

// MARK: - Rejected application (with admin reason)

struct TutorRejectedView: View {

    @EnvironmentObject private var authManager: AuthManager
    @State private var isBusy = false
    @State private var errorMessage: String?

    private var reason: String {
        let r = authManager.currentUser?.adminStatusReason?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return r.isEmpty
            ? "No detailed reason was provided. You may contact Tricon Academy for more information."
            : r
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                Spacer(minLength: 28)

                ZStack {
                    Circle()
                        .fill(AppTheme.danger.opacity(0.12))
                        .frame(width: 100, height: 100)
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundColor(AppTheme.danger)
                }

                VStack(spacing: 10) {
                    Text("Application not approved")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.ink)
                        .multilineTextAlignment(.center)

                    Text("Your tutor application was reviewed and could not be approved at this time.")
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Reason from Tricon Academy")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.ink)
                    Text(reason)
                        .font(.system(size: 15))
                        .foregroundColor(AppTheme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.card)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(AppTheme.danger.opacity(0.2), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("Questions?")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.ink)
                    Text("Call \(AcademySupport.phoneDisplay) or email \(AcademySupport.email). Use Log in with this same account — do not create a new one.")
                        .font(.system(size: 13.5))
                        .foregroundColor(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.brandSoft.opacity(0.6))
                )

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundColor(AppTheme.danger)
                }

                Button {
                    Task { await resubmit() }
                } label: {
                    HStack {
                        if isBusy { ProgressView().tint(.white) }
                        Text(isBusy ? "Opening form…" : "Update details & resubmit")
                            .font(.system(size: 16, weight: .semibold))
                    }
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
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .disabled(isBusy)

                Button("Log out") { authManager.logout() }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.muted)
                    .padding(.bottom, 32)
            }
            .padding(.horizontal, 22)
        }
        .background(AppTheme.canvas.ignoresSafeArea())
    }

    @MainActor
    private func resubmit() async {
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
