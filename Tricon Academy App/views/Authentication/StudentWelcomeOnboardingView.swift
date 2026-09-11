   import SwiftUI

/// Shown once after a student creates an account (or until school info is filled).
/// Blue subject-style chrome — matches login / register entry flow.
struct StudentWelcomeOnboardingView: View {

    @EnvironmentObject private var authManager: AuthManager

    @State private var school = ""
    @State private var schoolDistrict = ""
    @State private var selectedGrade: Level = .form1
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var appeared = false

    @FocusState private var focusedField: Field?

    private enum Field {
        case school, district
    }

    private let blue = AppTheme.authBlue
    private let blueDeep = AppTheme.authBlueDeep
    private let blueSoft = AppTheme.authBlueSoft
    private let canvas = AppTheme.canvas
    private let ink = AppTheme.ink
    private let muted = AppTheme.muted

    private var canSubmit: Bool {
        !school.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !schoolDistrict.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isLoading
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                header
                    .padding(.top, 24)
                    .padding(.bottom, 22)

                formCard
                    .padding(.bottom, 18)

                if let errorMessage {
                    Text(errorMessage)
                        .appFont(size: 13.5, weight: .medium)
                        .foregroundColor(AppTheme.danger)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .padding(.bottom, 12)
                }

                Button {
                    Task { await submit() }
                } label: {
                    HStack(spacing: 10) {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("Continue to Tricon Academy")
                                .appFont(size: 15.5, weight: .semibold)
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                }
                .buttonStyle(AppPrimaryButtonStyle())
                .disabled(!canSubmit)
                .padding(.bottom, 14)

                Button("Sign out") {
                    authManager.logout()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(muted)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 20)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
        }
        .background(AppTheme.authBlueWash)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
            if let g = authManager.currentUser?.grade, let level = Level(rawValue: g), Level.activeCases.contains(level) {
                selectedGrade = level
            }
            school = authManager.currentUser?.school ?? ""
            schoolDistrict = authManager.currentUser?.schoolDistrict ?? ""
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(blueSoft)
                    .frame(width: 88, height: 88)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.brand, AppTheme.brandFillDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: blue.opacity(0.32), radius: 14, x: 0, y: 7)

                Image(systemName: "checkmark")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(spacing: 6) {
                Text("Congratulations!")
                    .appFont(size: 24, weight: .bold)
                    .foregroundColor(ink)

                Text("Welcome to Tricon Academy")
                    .appFont(size: 16, weight: .semibold)
                    .foregroundColor(blueDeep)

                Text("You’re in. Tell us a bit about your school so we can personalise your learning experience.")
                    .appFont(size: 13.5, weight: .medium)
                    .foregroundColor(muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }

            if let name = authManager.currentUser?.fullName, !name.isEmpty {
                Text(name)
                    .appFont(size: 12.5, weight: .semibold)
                    .foregroundColor(blueDeep)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(blueSoft))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Form

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your school details")
                .appFont(size: 15, weight: .bold)
                .foregroundColor(ink)

            fieldBlock(title: "School name", systemImage: "building.2.fill") {
                TextField("e.g. Tricon Secondary School", text: $school)
                    .focused($focusedField, equals: .school)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .district }
            }

            fieldBlock(title: "District", systemImage: "mappin.and.ellipse") {
                TextField("e.g. Lusaka", text: $schoolDistrict)
                    .focused($focusedField, equals: .district)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Your grade / form", systemImage: "graduationcap.fill")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(muted)

                Picker("Grade", selection: $selectedGrade) {
                    ForEach(Level.activeCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.segmented)
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
        .shadow(color: blue.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    private func fieldBlock<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundColor(muted)

            content()
                .font(.system(size: 15))
                .foregroundColor(ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                        .fill(canvas)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                        .stroke(blue.opacity(0.12), lineWidth: 1)
                )
        }
    }

    @MainActor
    private func submit() async {
        errorMessage = nil
        guard canSubmit else {
            errorMessage = "Please enter your school, district, and grade."
            return
        }
        isLoading = true
        defer { isLoading = false }

        let result = await authManager.completeStudentProfile(
            school: school,
            schoolDistrict: schoolDistrict,
            grade: selectedGrade.rawValue
        )

        switch result {
        case .success:
            break
        case .failure(let error):
            errorMessage = error.errorDescription ?? "Could not save your details. Try again."
        }
    }
}

struct StudentWelcomeOnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        StudentWelcomeOnboardingView()
            .environmentObject(AuthManager.shared)
    }
}
