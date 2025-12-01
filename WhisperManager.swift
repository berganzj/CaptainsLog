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
    
    struct TranscriptionSegment {
        let text: String
        let confidence: Float
        let startTime: TimeInterval
        let endTime: TimeInterval
    }
    
    override init() {
        super.init()
        requestTranscriptionPermission()
    }
    
    /// Request permission for speech recognition
    func requestTranscriptionPermission() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self.transcriptionAvailable = true
                    print("Speech recognition authorized")
                case .denied, .restricted, .notDetermined:
                    self.transcriptionAvailable = false
                    print("Speech recognition not authorized: \(authStatus)")
                @unknown default:
                    self.transcriptionAvailable = false
                    print("Speech recognition unknown status: \(authStatus)")
                }
            }
        }
    }
    
    /// Transcribe audio with retry logic
    func transcribeAudioWithRetry(from audioURL: URL, completion: @escaping (Result<TranscriptionResult, Error>) -> Void) {
        transcribeAudioWithRetry(from: audioURL, attempt: 1, completion: completion)
    }
    
    private func transcribeAudioWithRetry(from audioURL: URL, attempt: Int, completion: @escaping (Result<TranscriptionResult, Error>) -> Void) {
        guard attempt <= maxRetryAttempts else {
            completion(.failure(TranscriptionError.maxRetriesExceeded))
            return
        }
        
        guard transcriptionAvailable else {
            completion(.failure(TranscriptionError.notAuthorized))
            return
        }
        
        DispatchQueue.main.async {
            self.isTranscribing = true
            self.currentProgress = 0.0
        }
        
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self.currentProgress = result.isFinal ? 1.0 : 0.5
                }
                
                if result.isFinal {
                    let confidence = self.calculateConfidence(from: result)
                    let transcriptionResult = TranscriptionResult(
                        text: result.bestTranscription.formattedString,
                        confidence: confidence,
                        duration: 0.0, // Audio duration would need to be calculated
                        wordCount: result.bestTranscription.segments.count,
                        retryAttempt: attempt
                    )
                    
                    if self.isQualityAcceptable(transcriptionResult) {
                        DispatchQueue.main.async {
                            self.isTranscribing = false
                            self.currentProgress = 1.0
                        }
                        completion(.success(transcriptionResult))
                    } else if attempt < self.maxRetryAttempts {
                        print("Transcription quality below threshold, retrying attempt \(attempt + 1)")
                        DispatchQueue.main.async {
                            self.isTranscribing = false
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + self.retryDelay) {
                            self.transcribeAudioWithRetry(from: audioURL, attempt: attempt + 1, completion: completion)
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.isTranscribing = false
                        }
                        completion(.success(transcriptionResult)) // Return best attempt even if quality is low
                    }
                }
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    self.isTranscribing = false
                }
                if attempt < self.maxRetryAttempts {
                    print("Transcription failed on attempt \(attempt), retrying: \(error.localizedDescription)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.retryDelay) {
                        self.transcribeAudioWithRetry(from: audioURL, attempt: attempt + 1, completion: completion)
                    }
                } else {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Stop any ongoing transcription
    func stopTranscription() {
        recognitionTask?.cancel()
        recognitionRequest?.endAudio()
        audioEngine.stop()
        if audioEngine.inputNode.isInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        DispatchQueue.main.async {
            self.isTranscribing = false
        }
    }
    
    /// Calculate confidence score from recognition result
    private func calculateConfidence(from result: SFSpeechRecognitionResult) -> Float {
        guard !result.bestTranscription.segments.isEmpty else { return 0.0 }
        
        let totalConfidence = result.bestTranscription.segments.reduce(0.0) { total, segment in
            return total + segment.confidence
        }
        
        return totalConfidence / Float(result.bestTranscription.segments.count)
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
        // 2. Reasonable word count
        // 3. Text not empty
        
        let minConfidence: Float = 0.3
        let minWordCount = 1
        
        return result.confidence >= minConfidence &&
               result.wordCount >= minWordCount &&
               !result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Transcribe audio using batch processing for multiple files
    func transcribeBatch(urls: [URL], completion: @escaping ([Result<TranscriptionResult, Error>]) -> Void) {
        var results: [Result<TranscriptionResult, Error>] = Array(repeating: .failure(TranscriptionError.notStarted), count: urls.count)
        let dispatchGroup = DispatchGroup()
        
        for (index, url) in urls.enumerated() {
            dispatchGroup.enter()
            transcribeAudioWithRetry(from: url) { result in
                results[index] = result
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(results)
        }
    }
    
    /// Fallback transcription method (compatible with existing code)
    func transcribeAudio(from audioURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        transcribeAudioWithRetry(from: audioURL) { result in
            switch result {
            case .success(let transcriptionResult):
                completion(.success(transcriptionResult.text))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Transcribe using OpenAI Whisper (placeholder for future implementation)
    func transcribeWithWhisper(audioURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        // TODO: Implement OpenAI Whisper integration
        // This will provide better accuracy and offline capabilities
        // For now, fallback to Apple's Speech framework
        transcribeAudio(from: audioURL, completion: completion)
    }
}

// MARK: - Error Types
enum TranscriptionError: LocalizedError {
    case notAuthorized
    case audioEngineError
    case recognitionFailed
    case maxRetriesExceeded
    case notStarted
    case invalidAudioFile
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition not authorized"
        case .audioEngineError:
            return "Audio engine error"
        case .recognitionFailed:
            return "Speech recognition failed"
        case .maxRetriesExceeded:
            return "Maximum retry attempts exceeded"
        case .notStarted:
            return "Transcription not started"
        case .invalidAudioFile:
            return "Invalid audio file"
        }
    }
}
