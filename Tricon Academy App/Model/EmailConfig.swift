import Foundation

/// Configuration for outbound verification emails.
///
/// ## Real email (pick one)
///
/// ### Option A — EmailJS (easiest free tier for mobile)
/// 1. Create a free account at https://www.emailjs.com
/// 2. Add an email service (Gmail, Outlook, etc.)
/// 3. Create a template with variables: `{{to_email}}`, `{{to_name}}`, `{{passcode}}`, `{{app_name}}`
/// 4. Paste Service ID, Template ID, and Public Key below
///
/// ### Option B — Resend
/// 1. Create a free account at https://resend.com
/// 2. Create an API key
/// 3. Verify a domain (or use `beth.t@example.com` to your own inbox while testing)
/// 4. Paste the API key and from-address below
///
/// Until a provider is configured, verification still works in **DEBUG** builds
/// (code is printed to the Xcode console). Release builds require a real provider.
enum EmailConfig {

    enum Provider {
        case emailJS
        case resend
    }

    // MARK: - Active provider

    static let provider: Provider = .emailJS

    // MARK: - EmailJS

    static let emailJSServiceID = "YOUR_EMAILJS_SERVICE_ID"
    static let emailJSTemplateID = "YOUR_EMAILJS_TEMPLATE_ID"
    static let emailJSPublicKey = "YOUR_EMAILJS_PUBLIC_KEY"

    // MARK: - Resend

    static let resendAPIKey = "re_YOUR_RESEND_API_KEY"
    static let resendFromAddress = "Tricon Academy <onboarding@resend.dev>"

    // MARK: - Branding used in the email body

    static let appName = "Tricon Academy"
    static let supportEmail = "support@triconacademy.com"

    // MARK: - Helpers

    static var isEmailConfigured: Bool {
        switch provider {
        case .emailJS:
            return !emailJSServiceID.hasPrefix("YOUR_")
                && !emailJSTemplateID.hasPrefix("YOUR_")
                && !emailJSPublicKey.hasPrefix("YOUR_")
        case .resend:
            return !resendAPIKey.hasPrefix("re_YOUR_") && !resendAPIKey.isEmpty
        }
    }
}
