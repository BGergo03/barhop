import Foundation
import SwiftData
import os

enum ModelContainerFactory {
    static let schema = Schema([Night.self, Entry.self, Venue.self, TrailPoint.self])

    static let shared: ModelContainer = make()

    private static let logger = Logger(subsystem: "com.bgergo03.barhop", category: "Persistence")

    static func make(inMemory: Bool = false) -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else if let groupURL = AppGroup.containerURL {
            logger.info("Using App Group store")
            configuration = ModelConfiguration(schema: schema, url: groupURL.appending(path: "Barhop.store"))
        } else {
            logger.warning("App Group unavailable, falling back to the app container store")
            configuration = ModelConfiguration(schema: schema)
        }
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
