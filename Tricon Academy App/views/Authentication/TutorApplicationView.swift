import SwiftUI

// MARK: - Tutor application (after registration)

/// Tutor applications are reviewed by the academy team before access is granted.
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

                applicationSections
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
                        if isLoading { ProgressView().tint(.white) }
                        Text(isLoading ? "Submitting…" : "Submit application")
                            .appFont(size: 15.5, weight: .semibold)
                    }
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .disabled(!canSubmit)
                .padding(.bottom, 12)

                Text("Complete all sections and select at least one subject to submit.")
                    .appFont(size: 12.5)
                    .foregroundColor(AppTheme.muted)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16)

                Button("Sign out") { authManager.logout() }
                    .disabled(isLoading)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppTheme.muted)
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.authBlueWash)
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
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
            Text("Tell us about your qualifications and the subjects you teach. The team at the academy will review your application before you receive tutor access.")
                .appFont(size: 13.5, weight: .medium)
                .foregroundColor(AppTheme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var applicationSections: some View {
        VStack(spacing: 18) {
            contactSection
            educationSection
            subjectsSection
            referencesSection
        }
    }

    private var contactSection: some View {
        TutorApplicationSection(
            number: "01", title: "Personal details",
            subtitle: "How the academy can contact you."
        ) {
            labeledField("Phone number") {
                TextField("e.g. 0976 123 456", text: $phone)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
            }
            labeledField("Town / district or address") {
                TextField("Enter your location", text: $addressLocation)
                    .textInputAutocapitalization(.words)
            }
            labeledField("Gender") {
                Picker("Gender", selection: $gender) {
                    ForEach(genders, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(blueDeep)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var educationSection: some View {
        TutorApplicationSection(
            number: "02", title: "Education & qualifications",
            subtitle: "Share your highest qualification and last institution."
        ) {
            labeledField("Highest qualification") {
                Picker("Highest qualification", selection: $highestEducation) {
                    Text("Select a qualification").tag("")
                    ForEach(educationLevels, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(blueDeep)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            labeledField("Last school, college or university") {
                TextField("Enter institution name", text: $lastInstitution)
                    .textInputAutocapitalization(.words)
            }
        }
    }

    private var subjectsSection: some View {
        TutorApplicationSection(
            number: "03", title: "Teaching subjects",
            subtitle: "Select the subjects you are qualified to teach. You can choose more than one."
        ) {
            subjectGroup("Core subjects", subjects: coreSubjectChoices)
            Divider()
            subjectGroup("Optional subjects", subjects: optionalSubjectChoices)
            VStack(alignment: .leading, spacing: 6) {
                Label(selectionSummary, systemImage: "checkmark.circle")
                    .appFont(size: 13, weight: .semibold)
                    .foregroundColor(blueDeep)
                Text("Your approved subjects determine which lessons and resources you can manage.")
                    .appFont(size: 12.5)
                    .foregroundColor(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(blueSoft)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.controlRadius))
        }
    }

    private var coreSubjectChoices: [Subject] {
        allSubjects.filter { $0.name != "Optionals" }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var optionalSubjectChoices: [Subject] {
        optionalSubjects.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private var selectionSummary: String {
        switch selectedSubjects.count {
        case 0: return "Choose at least one subject"
        case 1: return "1 subject selected"
        default: return "\(selectedSubjects.count) subjects selected"
        }
    }

    private var subjectColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize { return [GridItem(.flexible())] }
        return [GridItem(.adaptive(minimum: 240), spacing: 10)]
    }

    private func subjectGroup(_ title: String, subjects: [Subject]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .appFont(size: 13, weight: .semibold)
                .foregroundColor(AppTheme.muted)
            LazyVGrid(columns: subjectColumns, spacing: 10) {
                ForEach(subjects) { subject in
                    TutorSubjectChoice(
                        subject: subject,
                        isSelected: selectedSubjects.contains(subject.name)
                    ) {
                        if selectedSubjects.contains(subject.name) {
                            selectedSubjects.remove(subject.name)
                        } else {
                            selectedSubjects.insert(subject.name)
                        }
                    }
                }
            }
        }
    }

    private var referencesSection: some View {
        TutorApplicationSection(
            number: "04", title: "References",
            subtitle: "Provide a name, role and phone number or email for someone who can confirm your qualifications or teaching experience."
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Reference details")
                    .appFont(size: 12.5, weight: .semibold)
                    .foregroundColor(AppTheme.muted)
                TextEditor(text: $referenceContacts)
                    .font(.system(size: 15))
                    .frame(minHeight: 130)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(fieldBackground)
                    .accessibilityLabel("Reference details")
                Text("Please make sure your reference is happy to be contacted.")
                    .appFont(size: 12.5)
                    .foregroundColor(AppTheme.muted)
            }
        }
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
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .appFont(size: 12.5, weight: .semibold)
                .foregroundColor(AppTheme.muted)
            content()
                .accessibilityLabel(title)
                .font(.system(size: 15))
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(fieldBackground)
        }
    }

    @MainActor
    private func submit() async {
        guard !isLoading else { return }
        errorMessage = nil
        guard canSubmit else {
            errorMessage = "Complete all sections and select at least one teaching subject."
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

private struct TutorApplicationSection<Content: View>: View {
    let number: String
    let title: String
    let subtitle: String
    let content: Content

    init(number: String, title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.number = number
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                Text(number)
                    .appFont(size: 12, weight: .bold)
                    .foregroundColor(AppTheme.authBlueDeep)
                    .padding(10)
                    .background(AppTheme.authBlueSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .appFont(size: 17, weight: .bold)
                        .foregroundColor(AppTheme.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle)
                        .appFont(size: 13)
                        .foregroundColor(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(elevated: false)
    }
}

private struct TutorSubjectChoice: View {
    let subject: Subject
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: subject.icon)
                    .font(.system(size: 19, weight: .medium))
                    .frame(width: 26)
                    .accessibilityHidden(true)
                Text(subject.name)
                    .appFont(size: 14, weight: .semibold)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21))
                    .accessibilityHidden(true)
            }
            .foregroundColor(isSelected ? AppTheme.authBlueDeep : AppTheme.ink)
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
            .background(isSelected ? AppTheme.authBlueSoft : AppTheme.canvas)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.controlRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.controlRadius)
                    .stroke(isSelected ? AppTheme.authBlue : AppTheme.stroke, lineWidth: isSelected ? 1.5 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: AppTheme.controlRadius))
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Double tap to \(isSelected ? "remove" : "select") this teaching subject")
    }
}

// MARK: - Application review


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
                reviewHeader
                applicationSummary
                reviewProgress
                statusActions
                supportCard
                Button("Sign out") { authManager.logout() }
                    .appFont(size: 14, weight: .medium)
                    .foregroundColor(AppTheme.muted)
                    .frame(minHeight: 44)
                    .disabled(isRefreshing)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(AppTheme.authBlueWash)
    }

    private var reviewHeader: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 36, weight: .medium))
                .foregroundColor(blueDeep)
                .frame(width: 88, height: 88)
                .background(blueSoft)
                .clipShape(Circle())
                .accessibilityHidden(true)
            Text("Application under review")
                .appFont(size: 25, weight: .bold)
                .foregroundColor(AppTheme.ink)
                .accessibilityAddTraits(.isHeader)
            Text("The team at the academy is reviewing your application.")
                .appFont(size: 15, weight: .medium)
                .foregroundColor(AppTheme.ink)
            Text("Thank you for applying to teach at Tricon Academy. Your details have been submitted successfully.")
                .appFont(size: 14)
                .foregroundColor(AppTheme.muted)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var applicationSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Your application", systemImage: "person.text.rectangle")
                .appFont(size: 16, weight: .bold)
                .foregroundColor(AppTheme.ink)
            if let user = authManager.currentUser {
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.fullName).appFont(size: 15, weight: .semibold)
                    Text(user.email).appFont(size: 13).foregroundColor(AppTheme.muted)
                }
                let subjects = User.parseSubjectList(user.subjectMajor)
                if !subjects.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Teaching subjects")
                            .appFont(size: 12.5, weight: .semibold)
                            .foregroundColor(AppTheme.muted)
                        Text(subjects.joined(separator: " · "))
                            .appFont(size: 14)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .foregroundColor(AppTheme.ink)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(elevated: false)
    }

    private var reviewProgress: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("What happens next")
                .appFont(size: 16, weight: .bold)
                .foregroundColor(AppTheme.ink)
            reviewStep("Application received", detail: "Your details and subject choices have been submitted.", icon: "checkmark.circle.fill", active: true)
            reviewStep("Academy review", detail: "Our team reviews your qualifications, subjects and references.", icon: "clock.fill", active: true)
            reviewStep("Tutor access", detail: "Once approved, you can manage resources and lessons for your approved subjects.", icon: "lock.fill", active: false)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(elevated: false)
    }

    private func reviewStep(_ title: String, detail: String, icon: String, active: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 19))
                .foregroundColor(active ? blueDeep : AppTheme.muted)
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .appFont(size: 14, weight: .semibold)
                    .foregroundColor(AppTheme.ink)
                Text(detail)
                    .appFont(size: 13)
                    .foregroundColor(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var statusActions: some View {
        VStack(spacing: 12) {
            if let notice {
                Text(notice)
                    .appFont(size: 13.5, weight: .medium)
                    .foregroundColor(blueDeep)
                    .multilineTextAlignment(.center)
            }
            Button {
                Task { await refresh() }
            } label: {
                HStack(spacing: 8) {
                    if isRefreshing { ProgressView() }
                    Text(isRefreshing ? "Checking…" : "Check application status")
                }
            }
            .buttonStyle(AppPrimaryButtonStyle())
            .disabled(isRefreshing)
            Text("You can return later and sign in with the same account to check for a decision.")
                .appFont(size: 12.5)
                .foregroundColor(AppTheme.muted)
                .multilineTextAlignment(.center)
        }
    }

    private var supportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Need help with your application?")
                .appFont(size: 15, weight: .bold)
                .foregroundColor(AppTheme.ink)
            Text(AcademySupport.approvalWaitMessage)
                .appFont(size: 13)
                .foregroundColor(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            contactRow(icon: "phone.fill", title: "Call the academy", value: AcademySupport.phoneDisplay, url: AcademySupport.phoneURL)
            contactRow(icon: "envelope.fill", title: "Email the academy", value: AcademySupport.email, url: AcademySupport.emailURL)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(elevated: false)
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
            notice = "The team at the academy is still reviewing your application. Please check again later."
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
