
import Foundation
import SwiftData
import FactoryKit
import SwiftUI
import CoreData

protocol DatabaseServiceInterface: AnyObject, Sendable {
    
    var mainContext: ModelContext { get }
}

/// Use Database service as class with @MainActor because
/// CoreData/SwiftData better works in one-threaded manner.
/// Other services should be `actor`s.
final class DatabaseService: DatabaseServiceInterface {

    private let sharedModelContainer: ModelContainer
    @ObservationIgnored @Injected(\.logger) private var logger
    
    /// For tests use `isStoredInMemoryOnly = true`.
    /// 
    init(isStoredInMemoryOnly: Bool) {
        let schema = Schema([PlaylistItem.self, AppSettings.self])
        let cloudKitDatabase = ModelConfiguration.CloudKitDatabase.none
        if isStoredInMemoryOnly {
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: isStoredInMemoryOnly,
                cloudKitDatabase: cloudKitDatabase
            )
            do {
                sharedModelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
                logger.info("Database model container", private: modelConfiguration.url.path)
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        } else {
            var modelConfiguration: ModelConfiguration?
            #if DEBUG
            if let path = ProcessInfo.processInfo.arguments.first(where: {
                $0.hasPrefix("DATABASE_PATH=")
            }).flatMap({
                $0.components(separatedBy: "DATABASE_PATH=").last
            }).flatMap({
                $0.isEmpty ? nil : $0
            }) {
                let url = URL(fileURLWithPath: path, isDirectory: false)
                modelConfiguration = ModelConfiguration(
                    schema: schema, url: url, allowsSave: false, cloudKitDatabase: cloudKitDatabase)
            } else if ProcessInfo.processInfo.arguments.contains("--in-memory-database-only") {
                modelConfiguration = ModelConfiguration(
                    schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: cloudKitDatabase)
            }
            #endif
            if modelConfiguration == nil {
                modelConfiguration = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: isStoredInMemoryOnly,
                    cloudKitDatabase: cloudKitDatabase
                )
            }
            guard let modelConfiguration else {
                fatalError("Could not create ModelContainer.")
            }
            do {
                sharedModelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
                logger.info("Database model container", private: modelConfiguration.url.path)
            } catch {
                try? FileManager.default.removeItem(at: modelConfiguration.url)
                do {
                    sharedModelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
                    logger.error(error)
                } catch {
                    fatalError("Could not create ModelContainer: \(error)")
                }
            }
        }
    }
    
    var mainContext: ModelContext { sharedModelContainer.mainContext }
}

extension FactoryKit.Container {

    @MainActor
    var databaseService: Factory<DatabaseServiceInterface> {
        if ProcessInfo.processInfo.isPreview || ProcessInfo.processInfo.isRunningUnitTests {
            return self { DatabaseService(isStoredInMemoryOnly: true) }.singleton
        } else {
            return self { DatabaseService(isStoredInMemoryOnly: false) }.singleton
        }
    }
}
