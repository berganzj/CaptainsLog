//
//  SettingsTabView.swift
//  CaptainsLog
//
//  Created on November 24, 2025.
//

import SwiftUI

struct SettingsTabView: View {
    @Binding var showingBackupSettings: Bool
    @EnvironmentObject var audioManager: AudioManager
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Data Management")) {
                    Button(action: {
                        showingBackupSettings = true
                    }) {
                        HStack {
                            Image(systemName: "externaldrive")
                                .foregroundColor(.blue)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading) {
                                Text("Backup & Restore")
                                    .foregroundColor(.primary)
                                Text("Manage your voice recordings and data")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                    
                    Button(action: {
                        audioManager.transcribeAllMissing()
                    }) {
                        HStack {
                            Image(systemName: "text.word.spacing")
                                .foregroundColor(.green)
                                .frame(width: 30)
                            
                            VStack(alignment: .leading) {
                                Text("Refresh Transcriptions")
                                    .foregroundColor(.primary)
                                Text("Re-process missing transcriptions")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Section(header: Text("Transcription Status")) {
                    TranscriptionStatusView()
                        .environmentObject(audioManager)
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading) {
                            Text("Captain's Log")
                            Text("Voice Journal with AI Transcription")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "star.circle")
                            .foregroundColor(.yellow)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading) {
                            Text("Stardate System")
                            Text("Federation standard temporal measurement")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsTabView(showingBackupSettings: .constant(false))
        .environmentObject(AudioManager())
}