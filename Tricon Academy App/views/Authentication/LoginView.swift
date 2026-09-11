import SwiftUI
import UIKit

struct LoginView: View {

    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
    @State private var isResetting = false
    @State private var appeared = false

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email, password
    }

    // MARK: - Palette

    private let canvas = AppTheme.canvas
    private let ink = AppTheme.ink
    private let mutedIcon = AppTheme.secondaryInk
    private let brand = AppTheme.brand
    private let danger = AppTheme.danger

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && !isLoading
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                AuthBackdrop()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        AuthHeading(title: "Welcome back", icon: "book.closed.fill")
                            .padding(.top, 20)
                            .padding(.bottom, 28)

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
                                .appFont(size: 13.5, weight: .medium)
                                .foregroundColor(danger)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(14)
                                .background(AppTheme.dangerSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .padding(.top, 14)
                        }

                        optionsLayout {
                            Button {
                                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { rememberMe.toggle() }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: rememberMe ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 18))
                                        .foregroundColor(rememberMe ? brand : mutedIcon)
                                    Text("Remember me")
                                        .appFont(size: 14, weight: .medium)
                                        .foregroundColor(ink)
                                }
                                }
                            .buttonStyle(SoftPressStyle())
                            .frame(minHeight: 44)
                            .accessibilityValue(rememberMe ? "On" : "Off")

                            if !dynamicTypeSize.isAccessibilitySize {
                                Spacer(minLength: 8)
                            }

                            Button {
                                resetEmail = email
                                resetPassword = ""
                                resetConfirm = ""
                                resetMessage = nil
                                resetSucceeded = false
                                showResetSheet = true
                            } label: {
                                Text("Forgot password?")
                                    .appFont(size: 14, weight: .semibold)
                                    .foregroundColor(brand)
                                    .frame(minHeight: 44)
                            }
                            .buttonStyle(SoftPressStyle())
                        }
                        .padding(.top, 18)

                        Button {
                            handleLogin()
                        } label: {
                            ZStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.secondaryInk))
                                } else {
                                    Label("Log In", systemImage: "arrow.right")
                                }
                            }
                        }
                        .buttonStyle(AuthPrimaryButtonStyle())
                        .disabled(!canSubmit)
                        .padding(.top, 22)

                        VStack(spacing: 6) {
                            Text("Don’t have an account?")
                                .appFont(size: 15)
                                .foregroundColor(ink)

                            NavigationLink(destination: RegisterView()) {
                                Text("Sign Up")
                                    .appFont(size: 15, weight: .bold)
                                    .foregroundColor(brand)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                                    .background(AppTheme.brandSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(SoftPressStyle())
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 24)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 480)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geo.size.height, alignment: .top)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared || reduceMotion ? 0 : 12)
                }
            }
        }
        .background(canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(canvas, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(brand)
        .disabled(isLoading)
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) { appeared = true }
        }
        .sheet(isPresented: $showResetSheet) {
            resetPasswordSheet
        }
    }

    private var optionsLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(spacing: 8))
    }

    // MARK: - Password reset

    private var resetPasswordSheet: some View {
        NavigationView {
            Form {
                Section {
                    Text(
                        authManager.isCloudEnabled
                            ? "Enter your account email. We’ll email a reset link that opens Tricon Academy so you can set a new password."
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
                    Button(isResetting ? "Please wait…" : (authManager.isCloudEnabled ? "Send reset email" : "Reset password")) {
                        handleResetPassword()
                    }
                    .disabled(
                        isResetting || resetSucceeded || resetEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || (!authManager.isCloudEnabled
                                && (resetPassword.count < 6 || resetPassword != resetConfirm))
                    )
                }
            }
            .disabled(isResetting)
            .interactiveDismissDisabled(isResetting)
            .navigationTitle("Reset password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showResetSheet = false }
                        .disabled(isResetting)
                }
            }
        }
    }

    private func handleResetPassword() {
        guard !isResetting else { return }
        guard authManager.isCloudEnabled || resetPassword == resetConfirm else {
            resetSucceeded = false
            resetMessage = "Passwords do not match."
            return
        }
        isResetting = true
        resetMessage = nil
        Task {
            let result = await authManager.resetPassword(email: resetEmail, newPassword: resetPassword)
            await MainActor.run {
                isResetting = false
                switch result {
                case .success:
                    resetSucceeded = true
                    if authManager.isCloudEnabled {
                        resetMessage = "Check your email. Open the link on this iPhone to set a new password."
                    } else {
                        resetMessage = "Password updated. You can log in with your new password."
                        email = resetEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                        password = resetPassword
                    }
                case .failure(let error):
                    resetSucceeded = false
                    resetMessage = error.errorDescription
                }
            }
        }
    }

    // MARK: - Actions

    private func handleLogin() {
        guard canSubmit else { return }
        focusedField = nil
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
            .appFont(size: 16)
            .foregroundColor(ink)
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .disableAutocorrection(true)
            .textContentType(contentType)
            .focused($focusedField, equals: field)
            .submitLabel(.next)
            .onSubmit { focusedField = .password }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .modifier(AuthFieldSurface(isFocused: focusedField == field))
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
            .appFont(size: 16)
            .foregroundColor(ink)
            .textContentType(.password)
            .focused($focusedField, equals: field)
            .submitLabel(.go)
            .onSubmit { handleLogin() }

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
        .modifier(AuthFieldSurface(isFocused: focusedField == field))
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
