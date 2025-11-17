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
    
    var body: some View {
        TabView {
            TodaysLogView()
                .tabItem {
                    Image(systemName: "calendar.circle")
                    Text("Today's Log")
                }
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(audioManager)
            
            HistoryView()
                .tabItem {
                    Image(systemName: "clock.circle")
                    Text("History")
                }
                .environment(\.managedObjectContext, viewContext)
                .environmentObject(audioManager)
        }
        .accentColor(.blue)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}