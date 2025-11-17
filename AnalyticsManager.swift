//
//  AnalyticsManager.swift
//  CaptainsLog
//
//  Created on November 16, 2025.
//

import Foundation
import CoreML
import NaturalLanguage

/// Analytics manager designed for future CoreML integration
/// Currently provides basic metadata extraction, designed to be enhanced with ML models
class AnalyticsManager: ObservableObject {
    
    // MARK: - Current Basic Analytics
    
    /// Extracts basic metadata from text content for future ML training
    func analyzeTextEntry(_ content: String) -> LogAnalytics {
        let analytics = LogAnalytics()
        
        // Word count (useful for ML features)
        analytics.wordCount = content.split(separator: " ").count
        
        // Extract basic topics using NaturalLanguage framework
        analytics.topics = extractTopics(from: content)
        
        // Detect potential mood indicators (basic implementation)
        analytics.mood = detectBasicMood(from: content)
        
        // Store raw content length for ML feature engineering
        analytics.contentMetrics = generateContentMetrics(from: content)
        
        return analytics
    }
    
    /// Analyzes audio file metadata for future ML integration
    func analyzeAudioEntry(filename: String, duration: Double) -> LogAnalytics {
        let analytics = LogAnalytics()
        
        // Store audio duration
        analytics.duration = duration
        
        // Placeholder for future speech-to-text transcription
        analytics.audioTranscription = nil // Will be filled by future ML models
        
        // Audio metadata for ML feature extraction
        analytics.audioMetrics = generateAudioMetrics(filename: filename, duration: duration)
        
        return analytics
    }
    
    // MARK: - ML-Ready Data Extraction
    
    private func extractTopics(from content: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = content
        
        var topics: [String] = []
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
        
        tagger.enumerateTags(in: content.startIndex..<content.endIndex,
                           unit: .word,
                           scheme: .nameType,
                           options: options) { tag, tokenRange in
            if let tag = tag {
                let topic = String(content[tokenRange])
                if topic.count > 2 { // Filter short words
                    topics.append(topic.lowercased())
                }
            }
            return true
        }
        
        return Array(Set(topics)).prefix(5).map { String($0) } // Limit to top 5 unique topics
    }
    
    private func detectBasicMood(from content: String) -> String {
        let positiveWords = ["good", "great", "excellent", "happy", "successful", "amazing", "wonderful"]
        let negativeWords = ["bad", "terrible", "awful", "sad", "failed", "difficult", "challenging"]
        
        let lowercased = content.lowercased()
        let positiveCount = positiveWords.filter { lowercased.contains($0) }.count
        let negativeCount = negativeWords.filter { lowercased.contains($0) }.count
        
        if positiveCount > negativeCount {
            return "positive"
        } else if negativeCount > positiveCount {
            return "negative"
        } else {
            return "neutral"
        }
    }
    
    private func generateContentMetrics(from content: String) -> [String: Any] {
        return [
            "character_count": content.count,
            "sentence_count": content.components(separatedBy: ".").count,
            "paragraph_count": content.components(separatedBy: "\n\n").count,
            "avg_word_length": content.split(separator: " ").map { $0.count }.reduce(0, +) / max(1, content.split(separator: " ").count)
        ]
    }
    
    private func generateAudioMetrics(filename: String, duration: Double) -> [String: Any] {
        return [
            "duration_seconds": duration,
            "filename": filename,
            "estimated_word_rate": duration > 0 ? Int(duration * 2.5) : 0, // ~2.5 words per second estimate
            "file_size_category": categorizeAudioLength(duration)
        ]
    }
    
    private func categorizeAudioLength(_ duration: Double) -> String {
        switch duration {
        case 0..<30: return "short"
        case 30..<120: return "medium"
        case 120..<300: return "long"
        default: return "extended"
        }
    }
}

// MARK: - Analytics Data Models

/// Container for analytics data - designed to be serializable for ML training
struct LogAnalytics {
    var wordCount: Int = 0
    var duration: Double = 0.0
    var mood: String = "neutral"
    var topics: [String] = []
    var audioTranscription: String? = nil
    var contentMetrics: [String: Any] = [:]
    var audioMetrics: [String: Any] = [:]
    
    /// Serializes analytics to JSON string for storage
    func toJSONString() -> String {
        let encoder = JSONEncoder()
        
        // Create a simplified dictionary for JSON serialization
        let data: [String: Any] = [
            "word_count": wordCount,
            "duration": duration,
            "mood": mood,
            "topics": topics,
            "audio_transcription": audioTranscription ?? "",
            "content_metrics": contentMetrics,
            "audio_metrics": audioMetrics,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            print("Analytics serialization error: \(error)")
            return "{}"
        }
    }
}

// MARK: - Future ML Integration Points

extension AnalyticsManager {
    
    /// Future: Load and run CoreML models for sentiment analysis
    func advancedSentimentAnalysis(_ content: String) -> String {
        // TODO: Implement CoreML sentiment analysis model
        // This will replace the basic mood detection
        return detectBasicMood(from: content)
    }
    
    /// Future: Speech-to-text transcription using CoreML
    func transcribeAudio(filename: String, completion: @escaping (String?) -> Void) {
        // TODO: Implement CoreML speech recognition
        // Will transcribe audio files and store in audioTranscription field
        completion(nil)
    }
    
    /// Future: Generate ML feature vectors for clustering/classification
    func generateFeatureVector(from analytics: LogAnalytics) -> Data? {
        // TODO: Convert analytics to ML feature vector
        // Will populate mlFeatureVector field in Core Data
        return nil
    }
    
    /// Future: Pattern recognition across historical entries
    func analyzePatterns(entries: [LogEntry]) -> [String: Any] {
        // TODO: Implement ML pattern detection
        // - Mood trends over time
        // - Topic clustering
        // - Personal insights
        return [:]
    }
}