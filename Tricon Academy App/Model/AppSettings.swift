import Foundation
import Combine
import SwiftUI

/// App-wide preferences: light/dark (white/black) appearance.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    /// `true` = black (dark) theme, `false` = white (light) theme.
    @Published var useDarkTheme: Bool {
        didSet { defaults.set(useDarkTheme, forKey: Keys.darkTheme) }
    }

    var preferredColorScheme: ColorScheme {
        useDarkTheme ? .dark : .light
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let darkTheme = "app.settings.darkTheme.v1"
    }

    private init() {
        // Default light unless user previously chose dark.
        if defaults.object(forKey: Keys.darkTheme) == nil {
            useDarkTheme = false
        } else {
            useDarkTheme = defaults.bool(forKey: Keys.darkTheme)
        }
    }
}
