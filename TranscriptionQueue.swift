//
//  TranscriptionQueue.swift
//  CaptainsLog
//
//  Created on November 24, 2025.
//

import Foundation
import CoreData
import Combine

/// Background transcription queue for processing multiple voice recordings
class TranscriptionQueue: ObservableObject {
    @Published var isProcessing = false
    @Published var queueCount = 0
    @Published var currentProgress: Double = 0.0
    @Published var processingFile: String? = nil
    
    private var queue: [LogEntry] = []
    private let whisperManager: WhisperManager
    private let persistenceController: PersistenceController
    private var isCurrentlyProcessing = false
    
    init(whisperManager: WhisperManager, persistenceController: PersistenceController) {
        self.whisperManager = whisperManager
        self.persistenceController = persistenceController
    }
    
    /// Add voice entry to transcription queue
    func enqueue(_ entry: LogEntry) {
        guard entry.type == "voice",
              entry.audioTranscription == nil,
              let filename = entry.audioFilename else {
            return
        }
        
        // Check if already in queue
        if queue.contains(where: { $0.id == entry.id }) {
            return
        }
        
        queue.append(entry)
        updateQueueCount()
        
        // Start processing if not already running
        if !isCurrentlyProcessing {
            processNext()
        }
    }
    
    /// Process all entries without transcriptions
    func transcribeAllMissing() {
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<LogEntry> = LogEntry.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "type == 'voice' AND audioTranscription == nil AND audioFilename != nil")
        
        do {
            let entriesNeedingTranscription = try context.fetch(fetchRequest)
            for entry in entriesNeedingTranscription {
                enqueue(entry)
            }
            print("Added \\(entriesNeedingTranscription.count) entries to transcription queue")
        } catch {
            print("Error fetching entries for transcription: \\(error)")
        }
    }
    
    /// Remove entry from queue
    func dequeue(_ entry: LogEntry) {
        queue.removeAll { $0.id == entry.id }
        updateQueueCount()
    }
    
    /// Clear the entire queue
    func clearQueue() {
        queue.removeAll()
        updateQueueCount()
        isCurrentlyProcessing = false
        
        DispatchQueue.main.async {
            self.isProcessing = false
            self.processingFile = nil
            self.currentProgress = 0.0
        }
    }
    
    /// Process next item in queue
    private func processNext() {
        guard !isCurrentlyProcessing, !queue.isEmpty else {
            DispatchQueue.main.async {
                self.isProcessing = false
                self.processingFile = nil
                self.currentProgress = 0.0
            }
            return
        }
        
        isCurrentlyProcessing = true
        let entry = queue.removeFirst()
        updateQueueCount()
        
        guard let filename = entry.audioFilename else {
            processNext() // Skip invalid entries
            return
        }
        
        DispatchQueue.main.async {
            self.isProcessing = true
            self.processingFile = filename
            self.currentProgress = 0.0
        }
        
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioURL = documentsURL.appendingPathComponent(filename)
        
        // Monitor progress from WhisperManager
        let progressCancellable = whisperManager.$currentProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.currentProgress = progress
            }
        
        whisperManager.transcribeAudio(from: audioURL) { [weak self] result in
            guard let self = self else { return }
            
            progressCancellable.cancel()
            
            // Update entry with transcription result
            self.persistenceController.performBackgroundTask { context in
                do {
                    // Find the entry in background context
                    let fetchRequest: NSFetchRequest<LogEntry> = LogEntry.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "id == %@", entry.id! as CVarArg)
                    
                    if let bgEntry = try context.fetch(fetchRequest).first {
                        switch result {
                        case .success(let transcription):
                            bgEntry.audioTranscription = transcription
                            print("✅ Transcription completed for: \\(filename)")
                        case .failure(let error):
                            print("❌ Transcription failed for \\(filename): \\(error.localizedDescription)")
                            // Don't save error state, allow retry later
                        }
                        
                        if context.hasChanges {
                            try context.save()
                        }
                    }
                } catch {
                    print("Error saving transcription: \\(error)")
                }
            }
            
            DispatchQueue.main.async {
                self.isCurrentlyProcessing = false
                self.processNext() // Process next item
            }
        }
    }
    
    /// Update queue count on main thread
    private func updateQueueCount() {
        DispatchQueue.main.async {
            self.queueCount = self.queue.count
        }
    }
    
    /// Get queue status summary
    func getQueueStatus() -> String {
        if isProcessing {
            let remaining = queueCount
            if let file = processingFile {
                return "Processing \\(file)... (\\(remaining) remaining)"
            } else {
                return "Processing... (\\(remaining) remaining)"
            }
        } else if queueCount > 0 {
            return "\\(queueCount) files queued for transcription"
        } else {
            return "No files in transcription queue"
        }
    }
}