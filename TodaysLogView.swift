//
//  TodaysLogView.swift
//  CaptainsLog
//
//  Created on November 16, 2025.
//

import SwiftUI
import CoreData

struct TodaysLogView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var audioManager: AudioManager
    @StateObject private var analyticsManager = AnalyticsManager()
    @State private var showingNewEntry = false
    @State private var newTextEntry = ""
    @State private var isRecording = false
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LogEntry.timestamp, ascending: false)],
        predicate: NSPredicate(format: "timestamp >= %@ AND timestamp < %@", 
                             Calendar.current.startOfDay(for: Date()) as NSDate,
                             Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))! as NSDate),
        animation: .default)
    private var todaysEntries: FetchedResults<LogEntry>
    
    var body: some View {
        NavigationView {
            VStack {
                if todaysEntries.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No log entries today")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Begin your Captain's Log")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(todaysEntries) { entry in
                            LogEntryRow(entry: entry)
                        }
                        .onDelete(perform: deleteEntries)
                    }
                }
                
                // Entry input area
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        // Voice recording button
                        Button(action: toggleRecording) {
                            Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(isRecording ? .red : .blue)
                        }
                        .disabled(audioManager.isPlaying)
                        
                        // Text entry field
                        TextField("Enter log entry...", text: $newTextEntry, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(1...4)
                        
                        // Add text entry button
                        Button(action: addTextEntry) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.green)
                        }
                        .disabled(newTextEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(.horizontal)
                    
                    if isRecording {
                        Text("Recording... Tap stop to finish")
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.bottom, 8)
                    }
                }
                .padding(.bottom)
            }
            .navigationTitle("Today's Log")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func toggleRecording() {
        if isRecording {
            audioManager.stopRecording { success in
                if success {
                    addVoiceEntry()
                }
                isRecording = false
            }
        } else {
            audioManager.startRecording { success in
                isRecording = success
            }
        }
    }
    
    private func addTextEntry() {
        withAnimation {
            let content = newTextEntry.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Basic analytics for current version (no ML dependencies)
            let analytics = analyticsManager.analyzeTextEntry(content)
            
            let newEntry = LogEntry(context: viewContext)
            newEntry.id = UUID()
            newEntry.timestamp = Date()
            newEntry.type = "text"
            newEntry.content = content
            newEntry.stardate = generateStardate()
            
            do {
                try viewContext.save()
                newTextEntry = ""
            } catch {
                print("Error saving text entry: \(error)")
            }
        }
    }
    
    private func addVoiceEntry() {
        withAnimation {
            // Get audio duration for basic analytics
            let audioDuration = audioManager.lastRecordingDuration ?? 0.0
            let analytics = analyticsManager.analyzeAudioEntry(
                filename: audioManager.lastRecordingFilename ?? "",
                duration: audioDuration
            )
            
            let newEntry = LogEntry(context: viewContext)
            newEntry.id = UUID()
            newEntry.timestamp = Date()
            newEntry.type = "voice"
            newEntry.audioFilename = audioManager.lastRecordingFilename
            newEntry.stardate = generateStardate()
            
            do {
                try viewContext.save()
            } catch {
                print("Error saving voice entry: \(error)")
            }
        }
    }
    
    private func deleteEntries(offsets: IndexSet) {
        withAnimation {
            offsets.map { todaysEntries[$0] }.forEach { entry in
                if entry.type == "voice", let filename = entry.audioFilename {
                    audioManager.deleteRecording(filename: filename)
                }
                viewContext.delete(entry)
            }
            
            do {
                try viewContext.save()
            } catch {
                print("Error deleting entries: \(error)")
            }
        }
    }
    
    private func generateStardate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.DDD.HH"
        let stardate = formatter.string(from: Date())
        return stardate
    }
}

struct TodaysLogView_Previews: PreviewProvider {
    static var previews: some View {
        TodaysLogView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(AudioManager())
    }
}