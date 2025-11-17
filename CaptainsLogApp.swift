//
//  CaptainsLogApp.swift
//  CaptainsLog
//
//  Created on November 16, 2025.
//

import SwiftUI

@main
struct CaptainsLogApp: App {
    let persistenceController = PersistenceController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}