//
//  HistoryView.swift
//  CaptainsLog
//
//  Created on November 16, 2025.
//

import SwiftUI
import CoreData

struct HistoryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var audioManager: AudioManager
    @EnvironmentObject private var dayTransitionManager: DayTransitionManager
    @State private var selectedDate: Date = Date()
    @State private var showingDatePicker = false
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LogEntry.timestamp, ascending: false)],
        animation: .default)
    private var allEntries: FetchedResults<LogEntry>
    
    private var groupedEntries: [Date: [LogEntry]] {
        Dictionary(grouping: allEntries) { entry in
            Calendar.current.startOfDay(for: entry.timestamp ?? Date())
        }
    }
    
    private var sortedDates: [Date] {
        groupedEntries.keys.sorted(by: >)
    }
    
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
                
                if allEntries.isEmpty {
                    Spacer()
                    GlassContainer(cornerRadius: 20, padding: 24) {
                        VStack(spacing: 16) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 60))
                                .foregroundColor(.blue.opacity(0.6))
                            
                            Text("No log entries yet")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Text("Start logging to build your history")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(sortedDates, id: \.self) { date in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(formatSectionDate(date))
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal)
                                    
                                    ForEach(groupedEntries[date] ?? []) { entry in
                                        LogEntryRow(entry: entry)
                                            .padding(.horizontal)
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Log History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Filter") {
                        showingDatePicker = true
                    }
                    .glassButton()
                    .foregroundColor(.white)
                }
            }
            .onChange(of: dayTransitionManager.shouldRefreshToday) { oldValue, newValue in
                if newValue {
                    // Force UI refresh when day changes for proper "Today"/"Yesterday" labels
                    print("Day transition detected in HistoryView - refreshing labels")
                }
            }
        }
        .sheet(isPresented: $showingDatePicker) {
            DateFilterView(selectedDate: $selectedDate)
        }
    }
    
    private func formatSectionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else if Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
    }
    
    private func deleteEntries(offsets: IndexSet, from entries: [LogEntry]) {
        withAnimation {
            offsets.map { entries[$0] }.forEach { entry in
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
}

struct DateFilterView: View {
    @Binding var selectedDate: Date
    @Environment(\.presentationMode) var presentationMode
    
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
                
                VStack {
                    GlassContainer(cornerRadius: 20, padding: 24) {
                        DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(GraphicalDatePickerStyle())
                    }
                    .padding()
                    
                    Spacer()
                }
            }
            .navigationTitle("Filter by Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        // TODO: Implement date filtering
                        presentationMode.wrappedValue.dismiss()
                    }
                    .glassButton()
                    .foregroundColor(.white)
                }
            }
        }
    }
}

struct HistoryView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
            .environmentObject(AudioManager())
            .environmentObject(DayTransitionManager())
    }
}
