import SwiftUI
import UIKit

struct LoginView: View {

    @EnvironmentObject private var authManager: AuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var rememberMe = true

    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var showResetSheet = false
    @State private var resetEmail = ""
    @State private var resetPassword = ""
    @State private var resetConfirm = ""
    @State private var resetMessage: String?
    @State private var resetSucceeded = false
    @State private var appeared = false

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email, password
    }

    // MARK: - Palette

    private let canvas = Color.white
    private let ink = Color.black
    private let mutedIcon = Color(red: 0.45, green: 0.45, blue: 0.48)
    private let fieldFill = Color(red: 0.965, green: 0.965, blue: 0.97)
    private let brand = AppTheme.brand
    private let brandDeep = Color(red: 0.04, green: 0.36, blue: 0.26)
    private let danger = Color(red: 0.85, green: 0.22, blue: 0.20)

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && !isLoading
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                canvas.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        Text("Log in to your\naccount")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(ink)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                            .padding(.top, 24)
                            .padding(.bottom, 36)

                        VStack(spacing: 14) {
                            minimalField(
                                placeholder: "Email address",
                                text: $email,
                                field: .email,
                                keyboard: .emailAddress,
                                contentType: .emailAddress
                            )

                            minimalSecureField(
                                placeholder: "Password",
                                text: $password,
                                field: .password,
                                isVisible: $showPassword
                            )
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13.5, weight: .medium))
                                .foregroundColor(danger)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 14)
                        }

                        HStack {
                            Button {
                                withAnimation(.easeOut(duration: 0.15)) { rememberMe.toggle() }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: rememberMe ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 18))
                                        .foregroundColor(rememberMe ? brand : mutedIcon)
                                    Text("Remember me")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(ink)
                                }
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button {
                                resetEmail = email
                                resetPassword = ""
                                resetConfirm = ""
                                resetMessage = nil
                                resetSucceeded = false
                                showResetSheet = true
                            } label: {
                                Text("Forgot password?")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(brand)
                                    .underline()
                            }
                        }
                        .padding(.top, 18)

                        Button {
                            handleLogin()
                        } label: {
                            ZStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Text("Log In")
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                LinearGradient(
                                    colors: canSubmit
                                        ? [brand, brandDeep]
                                        : [brand.opacity(0.55), brandDeep.opacity(0.55)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(Capsule())
                            .shadow(color: canSubmit ? brand.opacity(0.35) : .clear, radius: 12, x: 0, y: 6)
                        }
                        .buttonStyle(AuthPressStyle())
                        .disabled(!canSubmit)
                        .padding(.top, 28)

                        VStack(spacing: 6) {
                            Text("Don’t have an account?")
                                .font(.system(size: 15))
                                .foregroundColor(ink)

                            NavigationLink(destination: RegisterView()) {
                                Text("Sign Up")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundColor(brand)
                                    .underline()
                            }
                        }
                        .padding(.top, 28)

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 28)
                    .frame(minHeight: geo.size.height, alignment: .top)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                }
            }
        }
        .background(canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .disabled(isLoading)
        .onAppear {
            withAnimation(.easeOut(duration: 0.35)) { appeared = true }
        }
        .sheet(isPresented: $showResetSheet) {
            resetPasswordSheet
        }
    }

    // MARK: - Password reset

    private var resetPasswordSheet: some View {
        NavigationView {
            Form {
                Section {
                    Text(
                        authManager.isCloudEnabled
                            ? "Enter your account email. We’ll email a reset link that opens Tricon Academy so you can set a new password (not a blank localhost page)."
                            : "Enter the email for your account on this device and choose a new password (min. 6 characters)."
                    )
                    .font(.footnote)
                    .foregroundColor(.secondary)
                }

                Section("Account") {
                    TextField("Email", text: $resetEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .disableAutocorrection(true)
                    if !authManager.isCloudEnabled {
                        SecureField("New password", text: $resetPassword)
                        SecureField("Confirm password", text: $resetConfirm)
                    }
                }

                if let resetMessage {
                    Section {
                        Text(resetMessage)
                            .font(.footnote)
                            .foregroundColor(resetSucceeded ? .green : .red)
                    }
                }

                Section {
                    Button(authManager.isCloudEnabled ? "Send reset email" : "Reset password") {
                        handleResetPassword()
                    }
                    .disabled(
                        resetEmail.trimmingCharacters(in: .whitespaces).isEmpty
                            || (!authManager.isCloudEnabled
                                && (resetPassword.count < 6 || resetPassword != resetConfirm))
                    )
                }
            }
            .navigationTitle("Reset password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showResetSheet = false }
                }
            }
        }
    }

    private func handleResetPassword() {
        if authManager.isCloudEnabled {
            Task {
                let result = await authManager.resetPassword(email: resetEmail, newPassword: resetPassword)
                await MainActor.run {
                    switch result {
                    case .success:
                        resetSucceeded = true
                        resetMessage = "Check your email. Open the link on this iPhone — it will return you to Tricon Academy to set a new password."
                    case .failure(let error):
                        resetSucceeded = false
                        resetMessage = error.errorDescription
                    }
                }
            }
            return
        }

        guard resetPassword == resetConfirm else {
            resetSucceeded = false
            resetMessage = "Passwords do not match."
            return
        }
        Task {
            let result = await authManager.resetPassword(email: resetEmail, newPassword: resetPassword)
            await MainActor.run {
                switch result {
                case .success:
                    resetSucceeded = true
                    resetMessage = "Password updated. You can log in with your new password."
                    email = resetEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                    password = resetPassword
                case .failure(let error):
                    resetSucceeded = false
                    resetMessage = error.errorDescription
                }
            }
        }
    }

    // MARK: - Actions

    private func handleLogin() {
        errorMessage = nil
        isLoading = true

        Task {
            let result = await authManager.login(email: email, password: password, remember: rememberMe)
            await MainActor.run {
                isLoading = false
                switch result {
                case .success:
                    break
                case .failure(let error):
                    errorMessage = error.errorDescription
                }
            }
        }
    }

    // MARK: - Fields

    private func minimalField(
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboard: UIKeyboardType = .default,
        contentType: UITextContentType? = nil
    ) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 16))
            .foregroundColor(ink)
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
            .textContentType(contentType)
            .focused($focusedField, equals: field)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(fieldFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
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
            .textContentType(.password)
            .focused($focusedField, equals: field)

            Button {
                isVisible.wrappedValue.toggle()
            } label: {
                Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(mutedIcon)
            }
            .accessibilityLabel(isVisible.wrappedValue ? "Hide password" : "Show password")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(fieldFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    focusedField == field ? ink.opacity(0.16) : Color.clear,
                    lineWidth: 1
                )
        )
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            LoginView()
        }
        .environmentObject(AuthManager.shared)
    }
}
