import AppIntents
import Foundation
import os

/// What the intents ask of the app. `NightEngine` implements it and registers itself with
/// `AppDependencyManager` at launch. The intents are `LiveActivityIntent`s, so `perform()`
/// runs in the app process (SPEC §2); the widget extension only needs the types to build
/// its buttons and never resolves the dependency.
@MainActor
protocol NightIntentHandling: Sendable {
    /// Logs a beer, starting a night if none is active.
    func logBeerFromIntent() async
    /// Removes the last entry if it is `entryID` (when given) and was logged under a minute ago.
    func undoLastEntryFromIntent(entryID: UUID?)
}

/// Thrown when the system runs an intent in the widget extension instead of the app. The
/// extension has no engine and never writes data (SPEC §2), so this fails loudly rather than
/// crashing on the unresolved dependency.
struct IntentOutsideAppError: Error, CustomLocalizedStringResourceConvertible {
    var localizedStringResource: LocalizedStringResource { "Open Barhop to log beers." }
}

private enum IntentProcess {
    private static let logger = Logger(subsystem: "com.bgergo03.barhop", category: "Intents")

    /// Logs which process ran the intent (for the on-device check) and throws outside the app.
    static func requireApp(_ intent: String) throws {
        let inExtension = Bundle.main.bundleURL.pathExtension == "appex"
        logger.info("\(intent, privacy: .public) running in \(inExtension ? "widget extension" : "app", privacy: .public)")
        if inExtension { throw IntentOutsideAppError() }
    }
}

struct LogBeerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Log a beer"
    static let description = IntentDescription("Adds a beer to your night, starting a night if none is active.")

    @Dependency private var handler: any NightIntentHandling

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        try IntentProcess.requireApp("LogBeerIntent")
        await handler.logBeerFromIntent()
        return .result()
    }
}

struct UndoLastEntryIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Undo last beer"
    static let isDiscoverable = false

    /// The entry the Live Activity offered to undo, so a tap never removes a different one.
    @Parameter(title: "Entry ID") var entryID: String?

    @Dependency private var handler: any NightIntentHandling

    init() {}

    init(entryID: UUID?) {
        self.entryID = entryID?.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try IntentProcess.requireApp("UndoLastEntryIntent")
        handler.undoLastEntryFromIntent(entryID: entryID.flatMap(UUID.init(uuidString:)))
        return .result()
    }
}
