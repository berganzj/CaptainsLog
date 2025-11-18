//
//  LogEntryRow.swift
//  CaptainsLog
//
//  Created on November 16, 2025.
//

import SwiftUI
import AVFoundation

struct LogEntryRow: View {
    let entry: LogEntry
    @EnvironmentObject private var audioManager: AudioManager
    @State private var isPlaying = false
    @State private var showingTranscription = false
    @State private var isTranscribing = false
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with stardate and time
            HStack {
                Text("Stardate \(entry.stardate ?? "Unknown")")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(timeFormatter.string(from: entry.timestamp ?? Date()))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Content based on entry type
            if entry.type == "text" {
                HStack(alignment: .top) {
                    Text(entry.content ?? "")
                        .font(.body)
                        .lineLimit(nil)
                    
                    Spacer()
                    
                    Button(action: speakText) {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundColor(.blue)
                            .font(.title2)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            } else if entry.type == "voice" {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(.orange)
                            .font(.title2)
                        
                        Text("Voice Recording")
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        // Transcription toggle button
                        if entry.audioTranscription != nil {
                            Button(action: { showingTranscription.toggle() }) {
                                Image(systemName: showingTranscription ? "text.bubble.fill" : "text.bubble")
                                    .foregroundColor(.green)
                                    .font(.title2)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        
                        Button(action: togglePlayback) {
                            Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title)
                        }
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    
                    // Show transcription if available and toggled
                    if showingTranscription, let transcription = entry.audioTranscription {
                        HStack {
                            Text(transcription)
                                .font(.body)
                                .padding(8)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)
                            
                            Button(action: { audioManager.speakText(transcription) }) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    
                    // Transcription status
                    if isTranscribing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("Transcribing...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else if entry.audioTranscription == nil {
                        Button("Transcribe") {
                            transcribeAudio()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .onReceive(audioManager.$isPlaying) { playing in
            if !playing {
                isPlaying = false
            }
        }
        .onReceive(audioManager.$currentlyPlayingFile) { filename in
            if filename != entry.audioFilename {
                isPlaying = false
            }
        }
    }
    
    private func speakText() {
        guard let content = entry.content else { return }
        audioManager.speakText(content)
    }
    
    private func togglePlayback() {
        guard let filename = entry.audioFilename else { return }
        
        if isPlaying {
            audioManager.stopPlayback()
        } else {
            audioManager.playRecording(filename: filename) { success in
                isPlaying = success
            }
        }
    }
    
    private func transcribeAudio() {
        guard let filename = entry.audioFilename else { return }
        
        isTranscribing = true
        audioManager.transcribeExistingRecording(filename: filename) { [weak entry] transcription in
            DispatchQueue.main.async {
                self.isTranscribing = false
                if let transcription = transcription {
                    entry?.audioTranscription = transcription
                    // Save the context if available
                    try? entry?.managedObjectContext?.save()
                }
            }
        }
    }
}

struct LogEntryRow_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let sampleTextEntry = LogEntry(context: context)
        sampleTextEntry.id = UUID()
        sampleTextEntry.timestamp = Date()
        sampleTextEntry.type = "text"
        sampleTextEntry.content = "Captain's Log, Stardate 2401.234. We have encountered a fascinating nebula."
        sampleTextEntry.stardate = "2401.234"
        
        let sampleVoiceEntry = LogEntry(context: context)
        sampleVoiceEntry.id = UUID()
        sampleVoiceEntry.timestamp = Date().addingTimeInterval(-3600)
        sampleVoiceEntry.type = "voice"
        sampleVoiceEntry.audioFilename = "recording_123.m4a"
        sampleVoiceEntry.stardate = "2401.233"
        
        return VStack {
            LogEntryRow(entry: sampleTextEntry)
                .environmentObject(AudioManager())
            Divider()
            LogEntryRow(entry: sampleVoiceEntry)
                .environmentObject(AudioManager())
        }
        .padding()
    }
}