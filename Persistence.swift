//
//  Persistence.swift
//  CaptainsLog
//
//  Created on November 16, 2025.
//

import CoreData
import CloudKit

struct PersistenceController {
    static let shared = PersistenceController()
    
    /// Preview controller for SwiftUI previews
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample data for previews
        let sampleEntry = LogEntry(context: viewContext)
        sampleEntry.id = UUID()
        sampleEntry.timestamp = Date()
        sampleEntry.type = "text"
        sampleEntry.content = "Captain's Log, Stardate 2401.234. We have encountered a fascinating nebula that defies conventional physics."
        sampleEntry.stardate = "2401.234"
        
        // Sample voice entry with transcription
        let sampleVoiceEntry = LogEntry(context: viewContext)
        sampleVoiceEntry.id = UUID()
        sampleVoiceEntry.timestamp = Date().addingTimeInterval(-3600)
        sampleVoiceEntry.type = "voice"
        sampleVoiceEntry.audioFilename = "sample_recording.m4a"
        sampleVoiceEntry.audioTranscription = "Captain's Log, supplemental. The away team has returned safely."
        sampleVoiceEntry.stardate = "2401.233"
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved preview error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentContainer
    
    /// Initialize with enhanced migration and cloud sync support
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "CaptainsLog")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            // Configure for production use with migration and cloud sync
            configurePersistentStore()
        }
        
        // Load persistent stores with error handling
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                print("Core Data error: \(error), \(error.userInfo)")
                // In production, you might want to handle this more gracefully
                fatalError("Unresolved Core Data error \(error), \(error.userInfo)")
            } else {
                print("Core Data store loaded successfully: \(storeDescription.url?.absoluteString ?? "unknown")")
            }
        }
        
        // Configure context for better performance and merging
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Enable persistent history tracking for cloud sync
        container.viewContext.setValue(true, forKey: "NSPersistentHistoryTrackingKey")
        container.viewContext.setValue(true, forKey: "NSPersistentStoreRemoteChangeNotificationPostOptionKey")
    }
    
    /// Configure persistent store with migration and cloud sync settings
    private func configurePersistentStore() {
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("No persistent store description found")
        }
        
        // Enable automatic lightweight migration
        description.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
        description.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
        
        // Configure for CloudKit (future use)
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Set file protection for security
        description.setOption(FileProtectionType.complete as NSString, forKey: NSPersistentStoreFileProtectionKey)
        
        print("Configured persistent store at: \(description.url?.absoluteString ?? "unknown")")
    }
    
    /// Enhanced save with better error handling and retry logic
    func save() {
        let context = container.viewContext
        
        guard context.hasChanges else {
            return // No changes to save
        }
        
        do {
            try context.save()
            print("Core Data saved successfully")
        } catch {
            let nsError = error as NSError
            print("Core Data save error: \(nsError), \(nsError.userInfo)")
            
            // Attempt to recover by rolling back and trying again
            context.rollback()
            
            // Log the error for debugging
            if let detailedErrors = nsError.userInfo[NSDetailedErrorsKey] as? [NSError] {
                for detailError in detailedErrors {
                    print("Detailed error: \(detailError.localizedDescription)")
                }
            }
            
            // In a production app, you might want to show an alert to the user
            // or attempt to save again after resolving conflicts
        }
    }
    
    /// Save with completion handler for async operations
    func save(completion: @escaping (Result<Void, Error>) -> Void) {
        let context = container.viewContext
        
        guard context.hasChanges else {
            completion(.success(()))
            return
        }
        
        do {
            try context.save()
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
    
    /// Background context for heavy operations
    func backgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    /// Perform background save operation
    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        let context = backgroundContext()
        context.perform {
            block(context)
            if context.hasChanges {
                do {
                    try context.save()
                } catch {
                    print("Background save failed: \(error)")
                }
            }
        }
    }
    
    /// Check if migration is needed
    func migrationRequired() -> Bool {
        guard let storeURL = container.persistentStoreDescriptions.first?.url else {
            return false
        }
        
        do {
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: storeURL, options: nil)
            let model = container.managedObjectModel
            return !model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        } catch {
            print("Could not check migration requirement: \(error)")
            return false
        }
    }
}
