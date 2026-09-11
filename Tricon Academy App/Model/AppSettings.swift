import Foundation
import Combine
import SwiftUI
import UIKit

/// Single source of truth for Light / Dark appearance across the whole app.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    /// `true` = Dark, `false` = Light. Persisted and applied immediately.
    @Published var useDarkTheme: Bool {
        didSet {
            guard oldValue != useDarkTheme else { return }
            defaults.set(useDarkTheme, forKey: Keys.darkTheme)
            applyGlobally()
        }
    }

    var preferredColorScheme: ColorScheme {
        useDarkTheme ? .dark : .light
    }

    var interfaceStyle: UIUserInterfaceStyle {
        useDarkTheme ? .dark : .light
    }

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let darkTheme = "app.settings.darkTheme.v1"
    }

    private init() {
        if defaults.object(forKey: Keys.darkTheme) == nil {
            useDarkTheme = false
        } else {
            useDarkTheme = defaults.bool(forKey: Keys.darkTheme)
        }
        applyGlobally()
    }

    func setDarkTheme(_ on: Bool) {
        useDarkTheme = on
    }

    /// Push the chosen style onto every window and UIKit chrome so SwiftUI
    /// semantic colors and UIAppearance update on the same tap.
    func applyGlobally() {
        let style = interfaceStyle
        let scheme = preferredColorScheme
        AppChrome.apply(for: scheme)

        let applyToWindows = {
            for scene in UIApplication.shared.connectedScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }
                for window in windowScene.windows {
                    window.overrideUserInterfaceStyle = style
                    window.tintColor = UIColor(AppTheme.brand)
                }
            }
        }

        if Thread.isMainThread {
            applyToWindows()
        } else {
            DispatchQueue.main.async(execute: applyToWindows)
        }
    }
}
