import Foundation

enum EmailServiceError: LocalizedError {
    case notConfigured
    case invalidEmail
    case network(String)
    case provider(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Email delivery is not configured. Add your EmailJS or Resend keys in EmailConfig.swift."
        case .invalidEmail:
            return "That email address looks invalid."
        case .network(let message):
            return "Could not reach the email service. \(message)"
        case .provider(let message):
            return message
        }
    }
}

/// Sends verification emails through EmailJS or Resend.
struct EmailService {

    static func sendVerificationCode(
        to email: String,
        name: String,
        code: String
    ) async throws {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("@"), trimmed.contains(".") else {
            throw EmailServiceError.invalidEmail
        }

        if EmailConfig.isEmailConfigured {
            switch EmailConfig.provider {
            case .emailJS:
                try await sendViaEmailJS(to: trimmed, name: name, code: code)
            case .resend:
                try await sendViaResend(to: trimmed, name: name, code: code)
            }
            return
        }

        #if DEBUG
        // Local development without API keys: log the code so registration remains testable.
        print("""
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        [Tricon Academy] DEBUG email delivery
        To: \(trimmed)
        Name: \(name)
        Verification code: \(code)
        Configure EmailConfig.swift to send real emails.
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """)
        // Simulate network latency so the UI loading state is realistic.
        try await Task.sleep(nanoseconds: 600_000_000)
        #else
        throw EmailServiceError.notConfigured
        #endif
    }

    // MARK: - EmailJS

    private static func sendViaEmailJS(to email: String, name: String, code: String) async throws {
        guard let url = URL(string: "https://api.emailjs.com/api/v1.0/email/send") else {
            throw EmailServiceError.network("Invalid EmailJS endpoint.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "service_id": EmailConfig.emailJSServiceID,
            "template_id": EmailConfig.emailJSTemplateID,
            "user_id": EmailConfig.emailJSPublicKey,
            "template_params": [
                "to_email": email,
                "to_name": name,
                "passcode": code,
                "app_name": EmailConfig.appName,
                "support_email": EmailConfig.supportEmail
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw EmailServiceError.network("No HTTP response.")
        }

        guard (200...299).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw EmailServiceError.provider("EmailJS error: \(detail)")
        }
    }

    // MARK: - Resend

    private static func sendViaResend(to email: String, name: String, code: String) async throws {
        guard let url = URL(string: "https://api.resend.com/emails") else {
            throw EmailServiceError.network("Invalid Resend endpoint.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(EmailConfig.resendAPIKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let html = """
        <div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;max-width:480px;margin:0 auto;padding:32px 24px;color:#111;">
          <h2 style="margin:0 0 8px;font-size:22px;">Verify your email</h2>
          <p style="margin:0 0 20px;color:#555;line-height:1.5;">
            Hi \(name.isEmpty ? "there" : name), use this code to finish creating your \(EmailConfig.appName) account:
          </p>
          <div style="font-size:32px;letter-spacing:8px;font-weight:700;background:#f3f4f6;border-radius:12px;padding:16px 20px;text-align:center;margin:0 0 20px;">
            \(code)
          </div>
          <p style="margin:0;color:#777;font-size:13px;line-height:1.5;">
            This code expires in 10 minutes. If you didn’t create an account, you can ignore this email.
          </p>
        </div>
        """

        let body: [String: Any] = [
            "from": EmailConfig.resendFromAddress,
            "to": [email],
            "subject": "\(code) is your \(EmailConfig.appName) verification code",
            "html": html,
            "text": "Your \(EmailConfig.appName) verification code is \(code). It expires in 10 minutes."
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw EmailServiceError.network("No HTTP response.")
        }

        guard (200...299).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw EmailServiceError.provider("Resend error: \(detail)")
        }
    }
}
