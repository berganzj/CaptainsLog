//
//  WhisperManager.swift
//  CaptainsLog
//
//  Created on November 17, 2025.
//

import Foundation
import Speech
import AVFoundation

/// Manager for handling audio transcription
/// Currently uses Apple's Speech framework as a bridge to future Whisper integration
class WhisperManager: NSObject, ObservableObject {
    @Published var isTranscribing = false
    @Published var transcriptionAvailable = false
    @Published var currentProgress: Double = 0.0
    
    private let speechRecognizer = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Retry configuration
    private let maxRetryAttempts = 3
    private let retryDelay: TimeInterval = 2.0
    
    // Quality tracking
    struct TranscriptionResult {
        let text: String
        let confidence: Float
        let duration: TimeInterval
        let wordCount: Int
        let retryAttempt: Int
    }
    
    override init() {
        super.init()
        requestTranscriptionPermission()
    }
    
    /// Request permission for speech recognition
    func requestTranscriptionPermission() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                self.transcriptionAvailable = authStatus == .authorized
            }
        }
    }
    
    /// Transcribe audio file to text with retry logic and quality metrics
    /// - Parameters:
    ///   - audioURL: URL of the audio file to transcribe
    ///   - completion: Completion handler with transcribed text or error
    func transcribeAudio(from audioURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        transcribeAudioWithRetry(from: audioURL, attempt: 1, completion: completion)
    }
    
    /// Internal method with retry logic
    private func transcribeAudioWithRetry(from audioURL: URL, attempt: Int, completion: @escaping (Result<String, Error>) -> Void) {
        guard transcriptionAvailable,
              let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable else {
            completion(.failure(WhisperError.speechRecognitionUnavailable))
            return
        }
        
        // Validate audio file exists
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            completion(.failure(WhisperError.audioFileNotFound))
            return
        }
        
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = true // Enable progress tracking
        request.taskHint = .dictation
        request.contextualStrings = ["Captain's Log", "Stardate", "Enterprise", "Federation"] // Star Trek context
        
        DispatchQueue.main.async {
            self.isTranscribing = true
            self.currentProgress = 0.0
        }
        
        let startTime = Date()
        
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }
            
            // Update progress for partial results
            if let result = result {
                DispatchQueue.main.async {
                    self.currentProgress = result.isFinal ? 1.0 : min(0.8, Double(result.bestTranscription.formattedString.count) / 100.0)
                }
                
                if result.isFinal {
                    let duration = Date().timeIntervalSince(startTime)
                    let transcriptionText = result.bestTranscription.formattedString
                    let confidence = self.calculateConfidence(from: result)
                    
                    DispatchQueue.main.async {
                        self.isTranscribing = false
                        self.currentProgress = 1.0
                    }
                    
                    // Create quality metrics
                    let qualityResult = TranscriptionResult(
                        text: transcriptionText,
                        confidence: confidence,
                        duration: duration,
                        wordCount: transcriptionText.split(separator: " ").count,
                        retryAttempt: attempt
                    )
                    
                    print("Transcription completed - Confidence: \(confidence), Duration: \(duration)s, Words: \(qualityResult.wordCount), Attempt: \(attempt)")
                    
                    // Check if quality is acceptable or if we should retry
                    if self.isQualityAcceptable(qualityResult) || attempt >= self.maxRetryAttempts {
                        completion(.success(transcriptionText))
                    } else {
                        print("Transcription quality low, retrying (attempt \(attempt + 1))")
                        DispatchQueue.main.asyncAfter(deadline: .now() + self.retryDelay) {
                            self.transcribeAudioWithRetry(from: audioURL, attempt: attempt + 1, completion: completion)
                        }
                    }
                    return
                }
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.isTranscribing = false
                    self.currentProgress = 0.0
                }
                
                // Check if we should retry on error
                if attempt < self.maxRetryAttempts && self.isRetryableError(error) {
                    print("Transcription failed with retryable error, attempt \(attempt + 1): \(error.localizedDescription)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.retryDelay) {
                        self.transcribeAudioWithRetry(from: audioURL, attempt: attempt + 1, completion: completion)
                    }
                } else {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Clean up transcription resources
    func cleanup() {
        recognitionTask?.cancel()
        recognitionRequest?.endAudio()
        audioEngine.stop()
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        DispatchQueue.main.async {
            self.isTranscribing = false
            self.currentProgress = 0.0
        }
    }
    
    /// Transcribe multiple audio files in sequence
    func transcribeMultipleAudio(urls: [URL], progressUpdate: @escaping (Int, Int) -> Void, completion: @escaping ([(URL, Result<String, Error>)]) -> Void) {
        var results: [(URL, Result<String, Error>)] = []
        
        func transcribeNext(index: Int) {
            guard index < urls.count else {
                completion(results)
                return
            }
            
            let url = urls[index]
            progressUpdate(index + 1, urls.count)
            
            transcribeAudio(from: url) { result in
                results.append((url, result))
                transcribeNext(index: index + 1)
            }
        }
        
        transcribeNext(index: 0)
    }
    
    /// Calculate confidence score from segments
    private func calculateConfidence(from segments: [TranscriptionSegment]) -> Float {
        guard !segments.isEmpty else { return 0.0 }
        
        let totalConfidence = segments.reduce(0.0) { $0 + $1.confidence }
        return totalConfidence / Float(segments.count)
    }
    
    /// Determine if transcription quality is acceptable
    private func isQualityAcceptable(_ result: TranscriptionResult) -> Bool {
        // Quality criteria:
        // 1. Confidence above threshold
        // 2. Minimum word count (not just silence)
        // 3. Reasonable duration (not too fast/slow)
        
        let minConfidence: Float = 0.3
        let minWords = 2
        let maxDurationPerWord: TimeInterval = 2.0
        
        guard result.confidence >= minConfidence else {
            print("Low confidence: \(result.confidence)")
            return false
        }
        
        guard result.wordCount >= minWords else {
            print("Too few words: \(result.wordCount)")
            return false
        }
        
        let avgTimePerWord = result.duration / Double(result.wordCount)
        guard avgTimePerWord <= maxDurationPerWord else {
            print("Speaking too slow: \(avgTimePerWord)s per word")
            return false
        }
        
        return true
    }
    
    /// Check if error is retryable
    private func isRetryableError(_ error: Error) -> Bool {
        let nsError = error as NSError
        
        // Retryable error codes
        let retryableCodes = [
            201, // Network error
            203, // Audio format error (might be temporary)
            209, // No audio input
            216, // Recognition service unavailable
        ]
        
        return retryableCodes.contains(nsError.code)
    }
}

// MARK: - Error Types
enum WhisperError: LocalizedError {
    case speechRecognitionUnavailable
    case audioFileNotFound
    case transcriptionFailed
    
    var errorDescription: String? {
        switch self {
        case .speechRecognitionUnavailable:
            return "Speech recognition is not available or authorized"
        case .audioFileNotFound:
            return "Audio file could not be found"
        case .transcriptionFailed:
            return "Transcription process failed"
        }
    }
}

// MARK: - Future Whisper Integration Placeholder
extension WhisperManager {
    /// Placeholder for future OpenAI Whisper integration
    /// This method will eventually replace the Apple Speech framework implementation
    /// when the dependency for OpenAI Whisper is ready
    private func transcribeWithWhisper(from audioURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        // TODO: Integrate OpenAI Whisper when dependencies are ready
        // This will provide better accuracy and offline capabilities
        // For now, fallback to Apple's Speech framework
        transcribeAudio(from: audioURL, completion: completion)
    }
}