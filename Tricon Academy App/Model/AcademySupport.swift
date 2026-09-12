import Foundation

/// Public support contacts shown on tutor pending / help screens.
enum AcademySupport {
    /// Call or WhatsApp for tutor approval follow-up.
    static let phoneDisplay = "0976134025"
    static let phoneURL = URL(string: "tel:+260976134025")

    /// Academy support email (also used for verification mail).
    static let email = EmailConfig.supportEmail
    static let emailURL = URL(string: "mailto:\(email)?subject=Tutor%20approval%20follow-up")

    static let approvalWaitMessage =
        "If you have not received a decision after 2 days, contact the academy team. Call \(phoneDisplay) or email \(email)."
}
