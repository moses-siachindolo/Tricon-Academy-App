import SwiftUI

/// Kept for future use. Email OTP was removed from the signup flow so accounts
/// are created instantly via `AuthManager.register` or Apple/Google sign-in.
struct EmailVerificationView: View {
    var body: some View {
        Text("Email verification is not required right now.")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding()
            .navigationTitle("Verify Email")
            .navigationBarTitleDisplayMode(.inline)
    }
}

struct EmailVerificationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            EmailVerificationView()
        }
    }
}
