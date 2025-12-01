//
//  BackupManager.swift
//  CaptainsLog
//
//  Created on November 24, 2025.
//

import Foundation
import CoreData
import CloudKit

/// Manager for backing up and restoring voice recordings and transcriptions
class BackupManager: ObservableObject {
    @Published var isBackingUp = false
    @Published var isRestoring = false
    @Published var backupProgress: Double = 0.0
    @Published var lastBackupDate: Date?
    
    private let persistenceController: PersistenceController
    private let fileManager = FileManager.default
    
    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
        loadLastBackupDate()
    }
    
    /// Get backup directory URL
    private var backupDirectory: URL {
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent("Backups")
    }
    
    /// Get audio files directory
    private var audioDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    /// Create full backup of all data
    func createBackup() async throws {
        DispatchQueue.main.async {
            self.isBackingUp = true
            self.backupProgress = 0.0
        }
        
        defer {
            DispatchQueue.main.async {
                self.isBackingUp = false
                self.backupProgress = 0.0
            }
        }
        
        // Create backup directory
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
        
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let backupFolder = backupDirectory.appendingPathComponent("backup_\(timestamp)")
        try fileManager.createDirectory(at: backupFolder, withIntermediateDirectories: true)
        
        // Backup Core Data
        await updateProgress(0.1)
        try await backupCoreData(to: backupFolder)
        
        // Backup audio files
        await updateProgress(0.3)
        try await backupAudioFiles(to: backupFolder)
        
        // Create metadata file
        await updateProgress(0.9)
        try createBackupMetadata(to: backupFolder)
        
        // Update last backup date
        DispatchQueue.main.async {
            self.lastBackupDate = Date()
            self.saveLastBackupDate()
        }
        
        await updateProgress(1.0)
        print("✅ Backup completed successfully at: \(backupFolder.path)")
    }
    
    /// Backup Core Data store
    private func backupCoreData(to folder: URL) async throws {
        let context = persistenceController.backgroundContext()
        
        try await context.perform {
            // Export LogEntries as JSON
            let fetchRequest: NSFetchRequest<LogEntry> = LogEntry.fetchRequest()
            let entries = try context.fetch(fetchRequest)
            
            let exportData = entries.map { entry -> [String: Any] in
                var entryData: [String: Any] = [:]
                entryData["id"] = entry.id?.uuidString ?? ""
                entryData["timestamp"] = entry.timestamp?.timeIntervalSince1970 ?? 0
                entryData["type"] = entry.type ?? ""
                entryData["content"] = entry.content ?? ""
                entryData["audioFilename"] = entry.audioFilename ?? ""
                entryData["audioTranscription"] = entry.audioTranscription ?? ""
                entryData["stardate"] = entry.stardate ?? ""
                return entryData
            }
            
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            let backupFile = folder.appendingPathComponent("logentries.json")
            try jsonData.write(to: backupFile)
        }
    }
    
    /// Backup audio files
    private func backupAudioFiles(to folder: URL) async throws {
        let audioBackupFolder = folder.appendingPathComponent("audio")
        try fileManager.createDirectory(at: audioBackupFolder, withIntermediateDirectories: true)
        
        // Get all audio files
        let audioFiles = try fileManager.contentsOfDirectory(at: audioDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension.lowercased() == "m4a" }
        
        let totalFiles = audioFiles.count
        
        for (index, audioFile) in audioFiles.enumerated() {
            let destinationURL = audioBackupFolder.appendingPathComponent(audioFile.lastPathComponent)
            try fileManager.copyItem(at: audioFile, to: destinationURL)
            
            let progress = 0.3 + (0.6 * Double(index + 1) / Double(max(totalFiles, 1)))
            await updateProgress(progress)
        }
        
        print("Backed up \(totalFiles) audio files")
    }
    
    /// Create backup metadata
    private func createBackupMetadata(to folder: URL) throws {
        let metadata = [
            "version": "1.0",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "platform": "iOS",
            "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
        let metadataFile = folder.appendingPathComponent("backup_info.json")
        try jsonData.write(to: metadataFile)
    }
    
    /// Restore from backup
    func restoreBackup(from backupFolder: URL) async throws {
        DispatchQueue.main.async {
            self.isRestoring = true
            self.backupProgress = 0.0
        }
        
        defer {
            DispatchQueue.main.async {
                self.isRestoring = false
                self.backupProgress = 0.0
            }
        }
        
        // Validate backup
        guard fileManager.fileExists(atPath: backupFolder.appendingPathComponent("backup_info.json").path),
              fileManager.fileExists(atPath: backupFolder.appendingPathComponent("logentries.json").path) else {
            throw BackupError.invalidBackup
        }
        
        // Restore Core Data
        await updateProgress(0.1)
        try await restoreCoreData(from: backupFolder)
        
        // Restore audio files
        await updateProgress(0.5)
        try await restoreAudioFiles(from: backupFolder)
        
        await updateProgress(1.0)
        print("✅ Restore completed successfully")
    }
    
    /// Restore Core Data from backup
    private func restoreCoreData(from folder: URL) async throws {
        let context = persistenceController.backgroundContext()
        
        let jsonFile = folder.appendingPathComponent("logentries.json")
        let jsonData = try Data(contentsOf: jsonFile)
        guard let entriesData = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            throw BackupError.corruptData
        }
        
        try await context.perform {
            // Clear existing data (optional - could merge instead)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: LogEntry.fetchRequest())
            try context.execute(deleteRequest)
            
            // Import entries
            for entryData in entriesData {
                let entry = LogEntry(context: context)
                entry.id = UUID(uuidString: entryData["id"] as? String ?? "") ?? UUID()
                entry.timestamp = Date(timeIntervalSince1970: entryData["timestamp"] as? TimeInterval ?? 0)
                entry.type = entryData["type"] as? String
                entry.content = entryData["content"] as? String
                entry.audioFilename = entryData["audioFilename"] as? String
                entry.audioTranscription = entryData["audioTranscription"] as? String
                entry.stardate = entryData["stardate"] as? String
            }
            
            try context.save()
        }
    }
    
    /// Restore audio files from backup
    private func restoreAudioFiles(from folder: URL) async throws {
        let audioBackupFolder = folder.appendingPathComponent("audio")
        
        guard fileManager.fileExists(atPath: audioBackupFolder.path) else {
            print("No audio files to restore")
            return
        }
        
        let audioFiles = try fileManager.contentsOfDirectory(at: audioBackupFolder, includingPropertiesForKeys: nil)
        let totalFiles = audioFiles.count
        
        for (index, audioFile) in audioFiles.enumerated() {
            let destinationURL = audioDirectory.appendingPathComponent(audioFile.lastPathComponent)
            
            // Remove existing file if it exists
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            try fileManager.copyItem(at: audioFile, to: destinationURL)
            
            let progress = 0.5 + (0.5 * Double(index + 1) / Double(max(totalFiles, 1)))
            await updateProgress(progress)
        }
        
        print("Restored \\(totalFiles) audio files")
    }
    
    /// Get list of available backups
    func getAvailableBackups() -> [BackupInfo] {
        guard fileManager.fileExists(atPath: backupDirectory.path) else {
            return []
        }
        
        do {
            let backupFolders = try fileManager.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.creationDateKey])
                .filter { $0.hasDirectoryPath && $0.lastPathComponent.hasPrefix("backup_") }
            
            return backupFolders.compactMap { folder in
                guard let metadataData = try? Data(contentsOf: folder.appendingPathComponent("backup_info.json")),
                      let metadata = try? JSONSerialization.jsonObject(with: metadataData) as? [String: Any],
                      let timestampString = metadata["timestamp"] as? String,
                      let timestamp = ISO8601DateFormatter().date(from: timestampString) else {
                    return nil
                }
                
                let size = folderSize(at: folder)
                return BackupInfo(
                    url: folder,
                    timestamp: timestamp,
                    size: size,
                    version: metadata["version"] as? String ?? "unknown"
                )
            }
            .sorted { $0.timestamp > $1.timestamp }
        } catch {
            print("Error reading backup directory: \\(error)")
            return []
        }
    }
    
    /// Delete backup
    func deleteBackup(_ backup: BackupInfo) throws {
        try fileManager.removeItem(at: backup.url)
    }
    
    /// Calculate folder size
    private func folderSize(at url: URL) -> Int64 {
        var size: Int64 = 0
        let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])
        
        while let fileURL = enumerator?.nextObject() as? URL {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                size += Int64(resourceValues.fileSize ?? 0)
            } catch {
                continue
            }
        }
        
        return size
    }
    
    /// Update progress on main thread
    private func updateProgress(_ progress: Double) async {
        await MainActor.run {
            self.backupProgress = progress
        }
    }
    
    /// Save last backup date
    private func saveLastBackupDate() {
        UserDefaults.standard.set(lastBackupDate, forKey: "LastBackupDate")
    }
    
    /// Load last backup date
    private func loadLastBackupDate() {
        lastBackupDate = UserDefaults.standard.object(forKey: "LastBackupDate") as? Date
    }
}

// MARK: - Supporting Types

struct BackupInfo: Identifiable {
    let id = UUID()
    let url: URL
    let timestamp: Date
    let size: Int64
    let version: String
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    var formattedDate: String {
        DateFormatter.localizedString(from: timestamp, dateStyle: .medium, timeStyle: .short)
    }
}

enum BackupError: LocalizedError {
    case invalidBackup
    case corruptData
    case insufficientSpace
    
    var errorDescription: String? {
        switch self {
        case .invalidBackup:
            return "The backup folder is invalid or corrupted"
        case .corruptData:
            return "The backup data is corrupted and cannot be restored"
        case .insufficientSpace:
            return "Insufficient storage space for backup"
        }
    }
}