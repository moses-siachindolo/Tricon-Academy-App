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

    private let brand = Color(red: 0.12, green: 0.62, blue: 0.36)
    private let brandDeep = Color(red: 0.08, green: 0.42, blue: 0.26)
    private let ink = Color(red: 0.09, green: 0.11, blue: 0.13)
    private let muted = Color(red: 0.45, green: 0.48, blue: 0.52)
    private let fieldFill = Color(red: 0.965, green: 0.968, blue: 0.975)
    private let cardFill = Color.white

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && !isLoading
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header
                        .padding(.top, 8)
                        .padding(.bottom, 26)

                    card
                        .padding(.bottom, 22)

                    NavigationLink(destination: RegisterView()) {
                        HStack(spacing: 4) {
                            Text("Don’t have an account?")
                                .foregroundColor(muted)
                            Text("Sign Up")
                                .fontWeight(.semibold)
                                .foregroundColor(brand)
                        }
                        .font(.system(size: 14))
                    }
                    .padding(.bottom, 28)
                }
                .padding(.horizontal, 22)
                .frame(minHeight: geo.size.height, alignment: .top)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 14)
            }
            .background(Color(red: 0.976, green: 0.980, blue: 0.985).ignoresSafeArea())
        }
        .navigationTitle("Log In")
        .navigationBarTitleDisplayMode(.inline)
        .disabled(isLoading)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) { appeared = true }
        }
        .sheet(isPresented: $showResetSheet) {
            resetPasswordSheet
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [brand, brandDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 68, height: 68)
                    .shadow(color: brand.opacity(0.32), radius: 16, x: 0, y: 10)

                Image(systemName: "graduationcap.fill")
                    .font(.system(size: 29, weight: .semibold))
                    .foregroundColor(.white)
            }

            Text("Welcome back")
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundColor(ink)

            Text("Log in as a student, tutor, or admin to continue learning.")
                .font(.system(size: 14))
                .foregroundColor(muted)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.horizontal, 10)
        }
    }

    // MARK: - Card

    private var card: some View {
        VStack(spacing: 18) {
            VStack(spacing: 14) {
                authField(icon: "envelope.fill", placeholder: "Email address", text: $email, field: .email, keyboard: .emailAddress)
                secureField(icon: "lock.fill", placeholder: "Password", text: $password, field: .password, isVisible: $showPassword)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(red: 0.75, green: 0.15, blue: 0.15))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            HStack {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { rememberMe.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: rememberMe ? "checkmark.square.fill" : "square")
                            .foregroundColor(rememberMe ? brand : muted)
                        Text("Remember me")
                            .font(.system(size: 13))
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
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(brand)
                }
            }

            primaryButton
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 24, x: 0, y: 10)
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
    }

    private var primaryButton: some View {
        Button {
            handleLogin()
        } label: {
            Group {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Log In")
                        .fontWeight(.semibold)
                }
            }
            .font(.system(size: 17))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                LinearGradient(
                    colors: canSubmit ? [brand, brandDeep] : [brand.opacity(0.45), brandDeep.opacity(0.45)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: canSubmit ? brand.opacity(0.30) : .clear, radius: 16, x: 0, y: 8)
        }
        .buttonStyle(AuthPressStyle())
        .disabled(!canSubmit)
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
            // Cloud: email recovery only (no local password rewrite).
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

    private func authField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        let isFocused = focusedField == field
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isFocused ? brand : muted)
                .frame(width: 20)
            TextField(placeholder, text: text)
                .font(.system(size: 15))
                .keyboardType(keyboard)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .textContentType(.emailAddress)
                .focused($focusedField, equals: field)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(fieldFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isFocused ? brand.opacity(0.55) : Color.black.opacity(0.05), lineWidth: isFocused ? 1.6 : 1)
        )
        .shadow(color: isFocused ? brand.opacity(0.12) : .clear, radius: 10, x: 0, y: 4)
        .animation(.easeOut(duration: 0.18), value: isFocused)
    }

    private func secureField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        field: Field,
        isVisible: Binding<Bool>
    ) -> some View {
        let isFocused = focusedField == field
        return HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isFocused ? brand : muted)
                .frame(width: 20)
            if isVisible.wrappedValue {
                TextField(placeholder, text: text)
                    .font(.system(size: 15))
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: field)
            } else {
                SecureField(placeholder, text: text)
                    .font(.system(size: 15))
                    .focused($focusedField, equals: field)
            }
            Button {
                isVisible.wrappedValue.toggle()
            } label: {
                Image(systemName: isVisible.wrappedValue ? "eye.slash" : "eye")
                    .font(.system(size: 14))
                    .foregroundColor(muted)
            }
            .accessibilityLabel(isVisible.wrappedValue ? "Hide password" : "Show password")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(fieldFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isFocused ? brand.opacity(0.55) : Color.black.opacity(0.05), lineWidth: isFocused ? 1.6 : 1)
        )
        .shadow(color: isFocused ? brand.opacity(0.12) : .clear, radius: 10, x: 0, y: 4)
        .animation(.easeOut(duration: 0.18), value: isFocused)
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
