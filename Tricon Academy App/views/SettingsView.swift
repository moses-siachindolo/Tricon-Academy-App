import SwiftUI

/// Settings — form (students), locked majors + request access (tutors), theme, app info.
struct SettingsView: View {
    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject private var settings = AppSettings.shared

    @State private var selectedGrade: Level = .form1
    @State private var isSavingGrade = false
    @State private var gradeMessage: String?
    @State private var gradeSucceeded = false

    // Tutor subject requests (admin must approve)
    @State private var requestSelection: Set<String> = []
    @State private var isSubmittingRequest = false
    @State private var requestMessage: String?
    @State private var requestSucceeded = false

    private let brand = AppTheme.brand
    private let brandDeep = AppTheme.brandDeep
    private let brandSoft = AppTheme.brandSoft
    private let canvas = AppTheme.canvas
    private let ink = AppTheme.ink
    private let muted = AppTheme.muted

    private var isStudent: Bool {
        authManager.currentUser?.isStudent == true
    }

    private var isTutor: Bool {
        authManager.currentUser?.isTutor == true
    }

    private var approvedMajors: [String] {
        authManager.currentUser?.managedSubjectNames ?? []
    }

    private var otherSubjects: [Subject] {
        authManager.currentUser?.otherCatalogueSubjects ?? User.catalogueSubjects
    }

    private var pendingRequestNames: [String] {
        User.parseSubjectList(authManager.currentUser?.pendingSubjectRequest)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {

                if isStudent {
                    formSection
                }

                if isTutor {
                    tutorLockedMajorsSection
                    tutorRequestAccessSection
                    tutorOtherSubjectsSection
                }

                appearanceSection
                aboutSection

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
        }
        .background(brandWash)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Settings")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(ink)
            }
        }
        .onAppear {
            if let level = authManager.currentUser?.studentLevel {
                selectedGrade = level
            } else if let g = authManager.currentUser?.grade,
                      let level = Level(rawValue: g),
                      Level.activeCases.contains(level) {
                selectedGrade = level
            }
            requestSelection = Set(pendingRequestNames)
        }
    }

    private var brandWash: some View {
        ZStack {
            canvas.ignoresSafeArea()
            LinearGradient(
                colors: [brandSoft.opacity(0.4), canvas, canvas],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Form (students)

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Your form")

            VStack(alignment: .leading, spacing: 10) {
                compactSectionHeader(
                    icon: "graduationcap.fill",
                    title: "Learning form",
                    subtitle: "Home and Browse show this form only."
                )

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 6),
                        GridItem(.flexible(), spacing: 6)
                    ],
                    spacing: 6
                ) {
                    ForEach(Level.activeCases) { level in
                        formChip(level)
                    }
                }

                if isSavingGrade {
                    compactStatus(text: "Updating form…", loading: true)
                } else if let gradeMessage {
                    compactStatus(
                        text: gradeMessage,
                        success: gradeSucceeded
                    )
                }
            }
            .padding(12)
            .background(cardChrome)
        }
    }

    private func formChip(_ level: Level) -> some View {
        let selected = selectedGrade == level
        return Button {
            selectedGrade = level
            Task { await saveGrade() }
        } label: {
            HStack(spacing: 6) {
                Text(level.shortLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(selected ? .white : brandDeep)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle()
                            .fill(selected ? Color.white.opacity(0.22) : brandSoft)
                    )

                Text(level.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(selected ? .white : ink)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                Group {
                    if selected {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [brand, brandDeep],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(brandSoft.opacity(0.5))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(selected ? Color.clear : brand.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(SoftPressStyle())
        .disabled(isSavingGrade)
    }

    @MainActor
    private func saveGrade() async {
        gradeMessage = nil
        isSavingGrade = true
        defer { isSavingGrade = false }

        let result = await authManager.updateStudentGrade(selectedGrade.rawValue)
        switch result {
        case .success:
            gradeSucceeded = true
            gradeMessage = "Home and Browse now show \(selectedGrade.rawValue) only."
        case .failure(let error):
            gradeSucceeded = false
            gradeMessage = error.errorDescription ?? "Could not update form."
            if let level = authManager.currentUser?.studentLevel {
                selectedGrade = level
            }
        }
    }

    // MARK: - Tutor: locked majors (admin-approved only)

    private var tutorLockedMajorsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Specialist subjects")

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 8) {
                    compactSectionHeader(
                        icon: "lock.fill",
                        title: "Approved majors",
                        subtitle: "Locked after verification. Only an admin can change these."
                    )
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(brandDeep)
                        .padding(6)
                        .background(Circle().fill(brandSoft))
                }

                if approvedMajors.isEmpty {
                    Text("None on file — complete tutor verification or wait for admin approval.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(muted)
                } else {
                    FlowChips(items: approvedMajors, brand: brand, brandDeep: brandDeep, brandSoft: brandSoft, ink: ink)
                }

                Text("Home and uploads use only the subjects listed above.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(muted)
            }
            .padding(12)
            .background(cardChrome)
        }
    }

    // MARK: - Tutor: request more subjects (admin approval)

    private var tutorRequestAccessSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Request more subjects")

            VStack(alignment: .leading, spacing: 10) {
                compactSectionHeader(
                    icon: "hand.raised.fill",
                    title: "Admin approval required",
                    subtitle: "Select subjects to manage. A super admin must approve before they appear on your dashboard."
                )

                if !pendingRequestNames.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Pending: \(pendingRequestNames.joined(separator: " · "))")
                            .font(.system(size: 11.5, weight: .semibold))
                            .lineLimit(2)
                        Spacer(minLength: 4)
                        Button("Withdraw") {
                            Task { await cancelRequest() }
                        }
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.danger)
                        .disabled(isSubmittingRequest)
                    }
                    .foregroundColor(brandDeep)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(brandSoft.opacity(0.65))
                    )
                }

                if otherSubjects.isEmpty {
                    Text("You already cover the full catalogue.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(muted)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 100), spacing: 6)],
                        spacing: 6
                    ) {
                        ForEach(otherSubjects) { subject in
                            requestChip(subject.name)
                        }
                    }

                    Button {
                        Task { await submitRequest() }
                    } label: {
                        HStack(spacing: 6) {
                            if isSubmittingRequest {
                                ProgressView().tint(.white).scaleEffect(0.8)
                            } else {
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                Text(requestSelection.isEmpty ? "Select subjects to request" : "Submit for approval")
                                    .font(.system(size: 12.5, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(
                            LinearGradient(
                                colors: requestSelection.isEmpty || isSubmittingRequest
                                    ? [Color.gray.opacity(0.32), Color.gray.opacity(0.32)]
                                    : [brand, brandDeep],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .disabled(requestSelection.isEmpty || isSubmittingRequest)
                    .buttonStyle(SoftPressStyle())

                    if let requestMessage {
                        compactStatus(text: requestMessage, success: requestSucceeded)
                    }
                }
            }
            .padding(12)
            .background(cardChrome)
        }
    }

    private func requestChip(_ name: String) -> some View {
        let on = requestSelection.contains(name)
        let alreadyPending = pendingRequestNames.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
        return Button {
            if on {
                requestSelection.remove(name)
            } else {
                requestSelection.insert(name)
            }
            requestMessage = nil
        } label: {
            HStack(spacing: 4) {
                Text(name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if alreadyPending && on {
                    Image(systemName: "clock")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .foregroundColor(on ? .white : ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    if on {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [brand, brandDeep],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(brandSoft.opacity(0.5))
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(on ? Color.clear : brand.opacity(0.12), lineWidth: 1)
            )
        }
        .buttonStyle(SoftPressStyle())
        .disabled(isSubmittingRequest)
    }

    @MainActor
    private func submitRequest() async {
        requestMessage = nil
        isSubmittingRequest = true
        defer { isSubmittingRequest = false }

        let ordered = User.catalogueSubjectNames.filter { requestSelection.contains($0) }
        let result = await authManager.requestExtraSubjects(ordered)
        switch result {
        case .success:
            requestSucceeded = true
            requestMessage = "Request sent. An admin must approve before these appear on your dashboard."
            requestSelection = Set(User.parseSubjectList(authManager.currentUser?.pendingSubjectRequest))
        case .failure(let error):
            requestSucceeded = false
            requestMessage = error.errorDescription ?? "Could not submit request."
        }
    }

    @MainActor
    private func cancelRequest() async {
        isSubmittingRequest = true
        defer { isSubmittingRequest = false }
        let result = await authManager.cancelPendingSubjectRequest()
        switch result {
        case .success:
            requestSucceeded = true
            requestMessage = "Pending request withdrawn."
            requestSelection = []
        case .failure(let error):
            requestSucceeded = false
            requestMessage = error.errorDescription ?? "Could not withdraw request."
        }
    }

    // MARK: - Tutor: view other subjects

    private var tutorOtherSubjectsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Browse other subjects")

            VStack(alignment: .leading, spacing: 8) {
                compactSectionHeader(
                    icon: "eye.fill",
                    title: "View only",
                    subtitle: "Open any course to study. Upload stays limited to approved majors."
                )

                if otherSubjects.isEmpty {
                    Text("Full catalogue covered.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(muted)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(otherSubjects.enumerated()), id: \.element.id) { index, subject in
                            NavigationLink {
                                SubjectLevelPickerView(subject: subject)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: subject.icon)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(brandDeep)
                                        .frame(width: 28, height: 28)
                                        .background(
                                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                .fill(brandSoft)
                                        )

                                    Text(subject.name)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(ink)

                                    Spacer(minLength: 4)

                                    Text("View")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(brandDeep)

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(AppTheme.subtle)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)

                            if index < otherSubjects.count - 1 {
                                Divider()
                                    .background(brand.opacity(0.08))
                                    .padding(.leading, 48)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(brandSoft.opacity(0.3))
                    )
                }
            }
            .padding(12)
            .background(cardChrome)
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Appearance")

            VStack(alignment: .leading, spacing: 10) {
                compactSectionHeader(
                    icon: "paintbrush.fill",
                    title: "App theme",
                    subtitle: "White or black look for the whole app."
                )

                HStack(spacing: 8) {
                    themeCard(
                        title: "White",
                        subtitle: "Light",
                        icon: "sun.max.fill",
                        isSelected: !settings.useDarkTheme,
                        previewCanvas: Color(red: 0.96, green: 0.97, blue: 0.97),
                        previewCard: .white,
                        previewInk: Color(red: 0.1, green: 0.12, blue: 0.11)
                    ) {
                        settings.useDarkTheme = false
                    }

                    themeCard(
                        title: "Black",
                        subtitle: "Dark",
                        icon: "moon.fill",
                        isSelected: settings.useDarkTheme,
                        previewCanvas: Color(red: 0.08, green: 0.08, blue: 0.09),
                        previewCard: Color(red: 0.16, green: 0.16, blue: 0.18),
                        previewInk: Color.white.opacity(0.9)
                    ) {
                        settings.useDarkTheme = true
                    }
                }
            }
            .padding(12)
            .background(cardChrome)
        }
    }

    private func themeCard(
        title: String,
        subtitle: String,
        icon: String,
        isSelected: Bool,
        previewCanvas: Color,
        previewCard: Color,
        previewInk: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(previewCanvas)
                        .frame(height: 48)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(previewCard)
                                .frame(width: 34, height: 18)
                                .padding(8),
                            alignment: .topLeading
                        )
                        .overlay(
                            Circle()
                                .fill(previewInk.opacity(0.35))
                                .frame(width: 10, height: 10)
                                .padding(8),
                            alignment: .bottomTrailing
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(isSelected ? brand : brand.opacity(0.12), lineWidth: isSelected ? 1.5 : 1)
                        )

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundColor(brand)
                            .padding(5)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    }
                }

                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isSelected ? brandDeep : muted)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(title)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(ink)
                        Text(subtitle)
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundColor(muted)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(SoftPressStyle())
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("About")

            VStack(spacing: 0) {
                settingsInfoRow(title: "App", value: "Tricon Academy")
                Divider()
                    .background(brand.opacity(0.08))
                    .padding(.leading, 12)
                settingsInfoRow(title: "Version", value: "1.0")
            }
            .background(cardChrome)
        }
    }

    private func settingsInfoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(ink)
            Spacer()
            Text(value)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(brandDeep)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Shared chrome

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(brandDeep)
            .tracking(0.4)
            .textCase(.uppercase)
            .padding(.horizontal, 2)
    }

    private func compactSectionHeader(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(brandSoft)
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(brandDeep)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundColor(ink)
                Text(subtitle)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func compactStatus(text: String, success: Bool? = nil, loading: Bool = false) -> some View {
        HStack(spacing: 6) {
            if loading {
                ProgressView().tint(brand).scaleEffect(0.8)
            } else if let success {
                Image(systemName: success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(success ? brandDeep : AppTheme.danger)
            }
            Text(text)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundColor(success == false ? AppTheme.danger : (success == true ? brandDeep : muted))
        }
    }

    private var cardChrome: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppTheme.card)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(brand.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: brand.opacity(0.04), radius: 8, x: 0, y: 3)
            .shadow(color: Color.black.opacity(0.02), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Simple flow-style chips for locked majors

private struct FlowChips: View {
    let items: [String]
    let brand: Color
    let brandDeep: Color
    let brandSoft: Color
    let ink: Color

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 96), spacing: 6)],
            spacing: 6
        ) {
            ForEach(items, id: \.self) { name in
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 8, weight: .bold))
                    Text(name)
                        .font(.system(size: 11, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundColor(brandDeep)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(brandSoft)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(brand.opacity(0.14), lineWidth: 1)
                )
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            SettingsView()
        }
        .environmentObject(AuthManager.shared)
    }
}
