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
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [
                        Color.blue.opacity(0.1),
                        Color.purple.opacity(0.1),
                        Color.pink.opacity(0.05)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Data Management section
                        GlassContainer(cornerRadius: 16, padding: 16) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Data Management")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
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
                                .buttonStyle(PlainButtonStyle())
                                
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
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                        
                        // Transcription Status section
                        GlassContainer(cornerRadius: 16, padding: 16) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Transcription Status")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                TranscriptionStatusView()
                                    .environmentObject(audioManager)
                            }
                        }
                        .padding(.horizontal)
                        
                        // About section
                        GlassContainer(cornerRadius: 16, padding: 16) {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("About")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
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
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
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
