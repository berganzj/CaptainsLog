//
//  DayTransitionManager.swift
//  CaptainsLog
//
//  Created on November 17, 2025.
//

import Foundation
import Combine

/// Manager for handling day transitions and automatic view refreshes
class DayTransitionManager: ObservableObject {
    @Published var currentDate = Date()
    @Published var shouldRefreshToday = false
    
    private var cancellables = Set<AnyCancellable>()
    private var midnightTimer: Timer?
    
    init() {
        setupDayChangeNotifications()
        scheduleMidnightRefresh()
    }
    
    deinit {
        cancellables.removeAll()
        midnightTimer?.invalidate()
    }
    
    /// Setup notifications for day change events
    private func setupDayChangeNotifications() {
        // Monitor for day change notifications from the system
        NotificationCenter.default.publisher(for: .NSCalendarDayChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleDayChange()
            }
            .store(in: &cancellables)
        
        // Monitor for timezone changes
        NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleDayChange()
            }
            .store(in: &cancellables)
        
        // Monitor for system clock changes
        NotificationCenter.default.publisher(for: .NSSystemClockDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleDayChange()
            }
            .store(in: &cancellables)
    }
    
    /// Schedule a timer to refresh at midnight
    private func scheduleMidnightRefresh() {
        let calendar = Calendar.current
        let now = Date()
        
        // Calculate next midnight
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else {
            return
        }
        
        let timeInterval = tomorrow.timeIntervalSince(now)
        
        // Schedule timer for midnight
        midnightTimer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            self?.handleDayChange()
            // Reschedule for next day
            self?.scheduleMidnightRefresh()
        }
    }
    
    /// Handle day change events
    private func handleDayChange() {
        let newDate = Date()
        let calendar = Calendar.current
        
        // Check if we actually changed days
        if !calendar.isDate(currentDate, inSameDayAs: newDate) {
            print("Day transition detected: \(currentDate) -> \(newDate)")
            
            currentDate = newDate
            shouldRefreshToday = true
            
            // Reset the refresh flag after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.shouldRefreshToday = false
            }
            
            // Reschedule midnight timer if it was a manual day change
            midnightTimer?.invalidate()
            scheduleMidnightRefresh()
        }
    }
    
    /// Get the current day's start and end dates
    func getCurrentDayBounds() -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: currentDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
        return (start: startOfDay, end: endOfDay)
    }
    
    /// Force refresh for testing or manual triggers
    func forceRefresh() {
        handleDayChange()
    }
}