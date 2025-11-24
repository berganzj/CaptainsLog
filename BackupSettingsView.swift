//
//  BackupSettingsView.swift
//  CaptainsLog
//
//  Created on November 24, 2025.
//

import SwiftUI

struct BackupSettingsView: View {
    @StateObject private var backupManager: BackupManager
    @State private var availableBackups: [BackupInfo] = []
    @State private var showingBackupAlert = false
    @State private var showingRestoreAlert = false
    @State private var selectedBackup: BackupInfo?
    @State private var showingError = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss
    
    init(persistenceController: PersistenceController) {
        self._backupManager = StateObject(wrappedValue: BackupManager(persistenceController: persistenceController))
    }
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Backup Status")) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Last Backup")
                                .font(.headline)
                            Text(lastBackupText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Create Backup") {
                            showingBackupAlert = true
                        }
                        .disabled(backupManager.isBackingUp || backupManager.isRestoring)
                    }
                    
                    if backupManager.isBackingUp || backupManager.isRestoring {
                        HStack {
                            ProgressView(value: backupManager.backupProgress)
                            Text("\\(Int(backupManager.backupProgress * 100))%")
                                .font(.caption)
                        }
                    }
                }
                
                Section(header: Text("Available Backups")) {
                    if availableBackups.isEmpty {
                        Text("No backups available")
                            .foregroundColor(.secondary)
                            .italic()
                    } else {
                        ForEach(availableBackups, id: \\.url) { backup in
                            BackupRowView(backup: backup) {
                                selectedBackup = backup
                                showingRestoreAlert = true
                            } onDelete: {
                                deleteBackup(backup)
                            }
                        }
                    }
                }
                
                Section(header: Text("Information")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Backup includes:")
                        Text("• All journal entries and transcriptions")
                            .font(.caption)
                        Text("• Voice recordings")
                            .font(.caption)
                        Text("• App settings and preferences")
                            .font(.caption)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Backup Location:")
                        Text("Device local storage")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Data Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        loadAvailableBackups()
                    }
                    .disabled(backupManager.isBackingUp || backupManager.isRestoring)
                }
            }
            .onAppear {
                loadAvailableBackups()
            }
            .alert("Create Backup", isPresented: $showingBackupAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Create") {
                    createBackup()
                }
            } message: {
                Text("This will create a backup of all your journal entries and voice recordings. This may take a few moments.")
            }
            .alert("Restore Backup", isPresented: $showingRestoreAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Restore", role: .destructive) {
                    if let backup = selectedBackup {
                        restoreBackup(backup)
                    }
                }
            } message: {
                if let backup = selectedBackup {
                    Text("This will replace all current data with the backup from \\(backup.formattedDate). This cannot be undone.")
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var lastBackupText: String {
        if let lastBackup = backupManager.lastBackupDate {
            return DateFormatter.localizedString(from: lastBackup, dateStyle: .medium, timeStyle: .short)
        } else {
            return "Never"
        }
    }
    
    private func loadAvailableBackups() {
        availableBackups = backupManager.getAvailableBackups()
    }
    
    private func createBackup() {
        Task {
            do {
                try await backupManager.createBackup()
                await MainActor.run {
                    loadAvailableBackups()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func restoreBackup(_ backup: BackupInfo) {
        Task {
            do {
                try await backupManager.restoreBackup(from: backup.url)
                await MainActor.run {
                    loadAvailableBackups()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func deleteBackup(_ backup: BackupInfo) {
        do {
            try backupManager.deleteBackup(backup)
            loadAvailableBackups()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

struct BackupRowView: View {
    let backup: BackupInfo
    let onRestore: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading) {
                    Text(backup.formattedDate)
                        .font(.headline)
                    Text(backup.formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack {
                    Button("Restore") {
                        onRestore()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("Delete") {
                        onDelete()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    BackupSettingsView(persistenceController: PersistenceController.preview)
}