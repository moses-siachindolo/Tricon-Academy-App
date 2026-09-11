import SwiftUI

/// Shown after the user opens a Supabase recovery email (deep link into the app).
struct ResetPasswordConfirmView: View {
    @EnvironmentObject private var authManager: AuthManager

    @State private var password = ""
    @State private var confirm = ""
    @State private var showPassword = false
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var succeeded = false

    private let blue = AppTheme.authBlue
    private let blueDeep = AppTheme.authBlueDeep

    private var canSubmit: Bool {
        password.count >= 6 && password == confirm && !isLoading
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Set a new password")
                            .appFont(size: 24, weight: .bold)
                            .foregroundColor(AppTheme.ink)
                        Text("Choose a new password for your Tricon Academy account. You’ll use it the next time you log in.")
                            .appFont(size: 14)
                            .foregroundColor(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 8)

                    VStack(spacing: 12) {
                        secureRow(title: "New password", text: $password)
                        secureRow(title: "Confirm password", text: $confirm)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .appFont(size: 13, weight: .medium)
                            .foregroundColor(AppTheme.danger)
                    }

                    if succeeded {
                        Label("Password updated. You’re signed in.", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(blueDeep)
                    }

                    Button {
                        submit()
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Save new password")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .buttonStyle(AppPrimaryButtonStyle())
                    .disabled(!canSubmit)
                }
                .padding(22)
            }
            .background(AppTheme.authBlueWash)
            .navigationTitle("Reset password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        authManager.cancelPasswordResetFlow()
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func secureRow(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .appFont(size: 13, weight: .semibold)
                .foregroundColor(AppTheme.muted)
            HStack {
                Group {
                    if showPassword {
                        TextField(title, text: text)
                    } else {
                        SecureField(title, text: text)
                    }
                }
                .font(.system(size: 15))
                .textContentType(.newPassword)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)

                Button {
                    showPassword.toggle()
                } label: {
                    Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                        .foregroundColor(AppTheme.muted)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                    .fill(AppTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.controlRadius, style: .continuous)
                    .stroke(blue.opacity(0.14), lineWidth: 1)
            )
        }
    }

    private func submit() {
        errorMessage = nil
        guard password == confirm else {
            errorMessage = "Passwords do not match."
            return
        }
        isLoading = true
        Task {
            let result = await authManager.completePasswordReset(newPassword: password)
            await MainActor.run {
                isLoading = false
                switch result {
                case .success:
                    succeeded = true
                case .failure(let error):
                    errorMessage = error.errorDescription
                }
            }
        }
    }
}
