import SwiftUI

/// Shown once after a student creates an account (or until school info is filled).
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

    private let brand = AppTheme.brand
    private let brandDeep = AppTheme.brandDeep
    private let brandSoft = AppTheme.brandSoft
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
                    .padding(.top, 28)
                    .padding(.bottom, 28)

                formCard
                    .padding(.bottom, 20)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 13.5, weight: .medium))
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
                                .font(.system(size: 16, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: canSubmit
                                ? [brand, brandDeep]
                                : [Color.gray.opacity(0.35), Color.gray.opacity(0.35)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: canSubmit ? brand.opacity(0.28) : .clear, radius: 12, x: 0, y: 6)
                }
                .disabled(!canSubmit)
                .buttonStyle(AuthPressStyle())
                .padding(.bottom, 16)

                Button("Sign out") {
                    authManager.logout()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(muted)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 22)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 12)
        }
        .background(canvas.ignoresSafeArea())
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
            if let g = authManager.currentUser?.grade, let level = Level(rawValue: g), Level.activeCases.contains(level) {
                selectedGrade = level
            }
            school = authManager.currentUser?.school ?? ""
            schoolDistrict = authManager.currentUser?.schoolDistrict ?? ""
        }
    }

    // MARK: - Header (congratulations)

    private var header: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(brandSoft)
                    .frame(width: 96, height: 96)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [brand, brandDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .shadow(color: brand.opacity(0.35), radius: 16, x: 0, y: 8)

                Image(systemName: "checkmark")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(spacing: 8) {
                Text("Congratulations!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(ink)

                Text("Welcome to Tricon Academy")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(brandDeep)

                Text("You’re in. Tell us a bit about your school so we can personalise your learning experience.")
                    .font(.system(size: 14.5))
                    .foregroundColor(muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }

            if let name = authManager.currentUser?.fullName, !name.isEmpty {
                Text(name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(brandDeep)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(brandSoft))
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Form

    private var formCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Your school details")
                .font(.system(size: 16, weight: .bold))
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(muted)

                Picker("Grade", selection: $selectedGrade) {
                    ForEach(Level.activeCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.segmented)
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
        .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
    }

    private func fieldBlock<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(muted)

            content()
                .font(.system(size: 16))
                .foregroundColor(ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(canvas)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppTheme.stroke, lineWidth: 1)
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
