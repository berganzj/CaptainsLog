//
//  TranscriptionStatusView.swift
//  CaptainsLog
//
//  Created on November 24, 2025.
//

import SwiftUI

/// View to show transcription queue status and quality metrics
struct TranscriptionStatusView: View {
    @EnvironmentObject private var audioManager: AudioManager
    @State private var showingDetails = false
    
    private var transcriptionQueue: TranscriptionQueue? {
        audioManager.transcriptionQueuePublisher
    }
    
    var body: some View {
        if let queue = transcriptionQueue {
            GlassContainer(cornerRadius: 16, padding: 16) {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "waveform.path")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Transcription Status")
                                .font(.headline)
                            
                            Text(queue.getQueueStatus())
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if queue.isProcessing {
                            VStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                
                                Text("\(Int(queue.currentProgress * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button(action: { showingDetails.toggle() }) {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if showingDetails {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Queue Details")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Spacer()
                                Button("Process All") {
                                    audioManager.transcribeAllMissing()
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("Queued: \(queue.queueCount)")
                                        .font(.caption)
                                    Text("Processing: \(queue.isProcessing ? "Yes" : "No")")
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("Progress: \(Int(queue.currentProgress * 100))%")
                                        .font(.caption)
                                    if queue.processingFile != nil {
                                        Text("File: \(queue.processingFile ?? "")")
                                            .font(.caption2)
                                            .lineLimit(1)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
    }
}

/// Compact transcription indicator for individual entries
struct TranscriptionIndicator: View {
    let entry: LogEntry
    @State private var confidence: Float = 0.0
    
    var body: some View {
        HStack(spacing: 4) {
            if entry.audioTranscription != nil {
                HStack(spacing: 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    // Quality indicator (mock implementation for now)
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(qualityColor(for: index))
                            .frame(width: 4, height: 4)
                    }
                    
                    Text("\(Int(confidence * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(spacing: 2) {
                    Image(systemName: "clock")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("Queued")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
        }
        .onAppear {
            // Simulate quality assessment
            if entry.audioTranscription != nil {
                confidence = calculateMockConfidence()
            }
        }
    }
    
    private func qualityColor(for index: Int) -> Color {
        let threshold = Float(index + 1) / 3.0
        return confidence >= threshold ? .green : .gray.opacity(0.3)
    }
    
    private func calculateMockConfidence() -> Float {
        guard let transcription = entry.audioTranscription else { return 0.0 }
        
        // Mock confidence based on transcription characteristics
        let wordCount = transcription.split(separator: " ").count
        let hasStarTrekTerms = transcription.lowercased().contains("captain") || 
                              transcription.lowercased().contains("log") ||
                              transcription.lowercased().contains("stardate")
        
        var confidence: Float = 0.5
        
        if wordCount > 5 {
            confidence += 0.2
        }
        if hasStarTrekTerms {
            confidence += 0.2
        }
        if transcription.count > 20 {
            confidence += 0.1
        }
        
        return min(1.0, confidence)
    }
}

struct TranscriptionStatusView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            TranscriptionStatusView()
                .environmentObject(AudioManager())
            
            Divider()
            
            TranscriptionIndicator(entry: LogEntry())
        }
        .padding()
    }
}
