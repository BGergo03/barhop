import AppIntents
import Foundation

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

struct LogBeerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Log a beer"
    static let description = IntentDescription("Adds a beer to your night, starting a night if none is active.")

    @Dependency private var handler: any NightIntentHandling

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
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
        handler.undoLastEntryFromIntent(entryID: entryID.flatMap(UUID.init(uuidString:)))
        return .result()
    }
}
