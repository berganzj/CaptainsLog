//
//  ContentView.swift
//  CaptainsLog
//
//  Created on November 16, 2025.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var audioManager = AudioManager()
    @StateObject private var dayTransitionManager = DayTransitionManager()
    @State private var showingBackupSettings = false
    
    var body: some View {
        TabView {
            TodaysLogView()
                .tabItem {
                    Image(systemName: "calendar.circle")
                    Text("Today's Log")
                }
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(audioManager)
                .environmentObject(dayTransitionManager)
            
            HistoryView()
                .tabItem {
                    Image(systemName: "clock.circle")
                    Text("History")
                }
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(audioManager)
                .environmentObject(dayTransitionManager)
            
            SettingsTabView(showingBackupSettings: $showingBackupSettings)
                .tabItem {
                    Image(systemName: "gear.circle")
                    Text("Settings")
                }
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(audioManager)
        }
        .accentColor(.blue)
        .sheet(isPresented: $showingBackupSettings) {
            BackupSettingsView(persistenceController: PersistenceController.shared)
        }
        .onAppear {
            // Configure transcription queue after persistence is available
            audioManager.configureTranscriptionQueue(persistenceController: PersistenceController.shared)
            
            // Process any missing transcriptions on app startup
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                audioManager.transcribeAllMissing()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}