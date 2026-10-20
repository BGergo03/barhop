import Foundation

enum AppGroup {
    static let identifier = "group.com.bgergo03.barhop.shared"

    /// `nil` when the App Group capability isn't available (e.g. refused for a
    /// free personal team). Callers fall back to the app's own container.
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
