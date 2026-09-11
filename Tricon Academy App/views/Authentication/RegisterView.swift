import SwiftUI
import UIKit

struct RegisterView: View {

    @EnvironmentObject private var authManager: AuthManager

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedRole: UserRole = .student

    @State private var showPassword = false
    @State private var showConfirmPassword = false

    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var appeared = false

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case firstName, lastName, email, password, confirmPassword
    }

    // MARK: - Palette (entry green — independent of post-login blue brand)

    private let canvas = AppTheme.canvas
    private let ink = AppTheme.ink
    private let mutedIcon = AppTheme.secondaryInk
    private let fieldFill = AppTheme.field
    private let brand = AppTheme.brand
    private let brandDeep = AppTheme.brandDeep
    private let danger = AppTheme.danger

    private var fullName: String {
        [firstName, lastName]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private var canSubmit: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty
            && !lastName.trimmingCharacters(in: .whitespaces).isEmpty
            && isValidEmail(email)
            && password.count >= 6
            && password == confirmPassword
            && !isLoading
    }

    private var emailIsInvalid: Bool {
        !email.isEmpty && !isValidEmail(email)
    }

    private var passwordsMismatch: Bool {
        !confirmPassword.isEmpty && password != confirmPassword
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                canvas.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Text("Create account")
                            .appFont(size: 26, weight: .semibold)
                            .foregroundColor(ink)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                            .padding(.bottom, 20)

                        VStack(spacing: 14) {
                            minimalField(
                                placeholder: "First name",
                                text: $firstName,
                                field: .firstName,
                                contentType: .givenName,
                                autocap: .words
                            )

                            minimalField(
                                placeholder: "Last name",
                                text: $lastName,
                                field: .lastName,
                                contentType: .familyName,
                                autocap: .words
                            )

                            minimalField(
                                placeholder: "Email address",
                                text: $email,
                                field: .email,
                                keyboard: .emailAddress,
                                contentType: .emailAddress,
                                autocap: .never
                            )

                            if emailIsInvalid {
                                fieldHint("Enter a valid email address.")
                            }

                            minimalSecureField(
                                placeholder: "Password",
                                text: $password,
                                field: .password,
                                isVisible: $showPassword
                            )

                            minimalSecureField(
                                placeholder: "Confirm password",
                                text: $confirmPassword,
                                field: .confirmPassword,
                                isVisible: $showConfirmPassword
                            )

                            if passwordsMismatch {
                                fieldHint("Passwords do not match.")
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .appFont(size: 13.5, weight: .medium)
                                .foregroundColor(danger)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 14)
                        }

                        // Brand green CTA — solid, high contrast
                        Button {
                            Task { await handleRegister() }
                        } label: {
                            ZStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Create Account")
                                }
                            }
                        }
                        .buttonStyle(AppPrimaryButtonStyle())
                        .disabled(!canSubmit)
                        .padding(.top, 22)

                        VStack(spacing: 6) {
                            Text("Already have an account?")
                                .appFont(size: 15)
                                .foregroundColor(ink)

                            NavigationLink(destination: LoginView()) {
                                Text("Log In")
                                    .appFont(size: 15, weight: .bold)
                                    .foregroundColor(brand)
                                    .underline()
                            }
                        }
                        .padding(.top, 20)

                        // Role switch at bottom (menu)
                        Menu {
                            ForEach(UserRole.registrableRoles) { role in
                                Button {
                                    selectedRole = role
                                } label: {
                                    if selectedRole == role {
                                        Label(role.displayName, systemImage: "checkmark")
                                    } else {
                                        Text(role.displayName)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text("Signing up as \(selectedRole.displayName)")
                                    .appFont(size: 14, weight: .semibold)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(brand)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 24)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 28)
                    .frame(minHeight: geo.size.height, alignment: .top)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                }
            }
        }
        .background(canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(canvas, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .disabled(isLoading)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) { appeared = true }
        }
    }

    // MARK: - Fields

    private func fieldHint(_ message: String) -> some View {
        Text(message)
            .appFont(size: 12.5, weight: .medium)
            .foregroundColor(danger)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 6)
            .padding(.top, -4)
    }

    private func minimalField(
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil,
        autocap: TextInputAutocapitalization = .words
    ) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 16))
            .foregroundColor(ink)
            .keyboardType(keyboard)
            .textInputAutocapitalization(autocap)
            .disableAutocorrection(true)
            .textContentType(contentType)
            .focused($focusedField, equals: field)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                    .fill(fieldFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                    .stroke(
                        focusedField == field ? ink.opacity(0.16) : Color.clear,
                        lineWidth: 1
                    )
            )
    }

    private func minimalSecureField(
        placeholder: String,
        text: Binding<String>,
        field: Field,
        isVisible: Binding<Bool>
    ) -> some View {
        HStack(spacing: 10) {
            Group {
                if isVisible.wrappedValue {
                    TextField(placeholder, text: text)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                } else {
                    SecureField(placeholder, text: text)
                }
            }
            .font(.system(size: 16))
            .foregroundColor(ink)
            .textContentType(.newPassword)
            .focused($focusedField, equals: field)

            Button {
                isVisible.wrappedValue.toggle()
            } label: {
                AppIconLabel(systemName: isVisible.wrappedValue ? "eye.slash" : "eye",
                             tint: AppTheme.secondaryInk, fill: AppTheme.fill)
            }
            .buttonStyle(SoftPressStyle())
            .accessibilityLabel(isVisible.wrappedValue ? "Hide password" : "Show password")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .fill(fieldFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                .stroke(
                    focusedField == field ? ink.opacity(0.16) : Color.clear,
                    lineWidth: 1
                )
        )
    }

    // MARK: - Actions

    @MainActor
    private func handleRegister() async {
        errorMessage = nil

        guard !firstName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your first name."
            return
        }
        guard !lastName.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your last name."
            return
        }
        guard isValidEmail(email) else {
            errorMessage = "Please enter a valid email address."
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }

        isLoading = true
        defer { isLoading = false }

        let result = await authManager.register(
            fullName: fullName,
            email: email,
            phone: "",
            password: password,
            preferredRole: selectedRole
        )

        switch result {
        case .success:
            break
        case .failure(let error):
            errorMessage = error.errorDescription
        }
    }

    private func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard !trimmed.contains(" ") else { return false }
        let regex = "^[A-Za-z0-9]+([._%+-][A-Za-z0-9]+)*@[A-Za-z0-9]+([.-][A-Za-z0-9]+)*\\.[A-Za-z]{2,}$"
        return NSPredicate(format: "SELF MATCHES %@", regex).evaluate(with: trimmed)
    }
}

// MARK: - Shared UI bits

typealias AuthPressStyle = SoftPressStyle

struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            RegisterView()
        }
        .environmentObject(AuthManager.shared)
    }
}
