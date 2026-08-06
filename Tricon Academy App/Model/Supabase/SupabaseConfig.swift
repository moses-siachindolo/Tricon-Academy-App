import Foundation

/// Supabase project credentials for Tricon Academy.
///
/// Project: `xkwxgvfagilznywuptgk`
/// Client apps must only use the **publishable** / **anon** key — never the secret/service_role key.
///
/// Run `supabase/schema.sql` once in the Supabase SQL Editor if tables are not created yet.
enum SupabaseConfig {
    /// Project URL
    static var projectURL: String {
        if let env = ProcessInfo.processInfo.environment["SUPABASE_URL"], !env.isEmpty {
            return env
        }
        return "https://xkwxgvfagilznywuptgk.supabase.co"
    }

    /// Publishable / anon key (safe for the iOS client with RLS enabled).
    static var anonKey: String {
        if let env = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"], !env.isEmpty {
            return env
        }
        return "sb_publishable_GF6tuHJIg1m_-By9yBEcaQ_r-LnuBOI"
    }

    /// Storage bucket for papers, notes, and videos.
    static let contentBucket = "content"

    /// Deep-link opened from password-reset emails (must be allow-listed in Supabase Auth → URL Configuration).
    /// Scheme is registered in Info.plist as `triconacademy`.
    static let authRedirectURL = "triconacademy://auth/callback"

    /// True when real credentials are configured (not placeholders).
    static var isConfigured: Bool {
        let url = projectURL
        let key = anonKey
        guard let host = URL(string: url)?.host, host.contains("supabase") else { return false }
        if url.contains("YOUR_PROJECT_REF") { return false }
        if key.contains("YOUR_SUPABASE") || key.count < 20 { return false }
        return true
    }
}
