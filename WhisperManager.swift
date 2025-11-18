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
    
    private let speechRecognizer = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
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
    
    /// Transcribe audio file to text
    /// - Parameters:
    ///   - audioURL: URL of the audio file to transcribe
    ///   - completion: Completion handler with transcribed text or error
    func transcribeAudio(from audioURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        guard transcriptionAvailable,
              let speechRecognizer = speechRecognizer,
              speechRecognizer.isAvailable else {
            completion(.failure(WhisperError.speechRecognitionUnavailable))
            return
        }
        
        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        request.shouldReportPartialResults = false
        request.taskHint = .dictation
        
        DispatchQueue.main.async {
            self.isTranscribing = true
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isTranscribing = false
            }
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let result = result, result.isFinal else {
                return
            }
            
            completion(.success(result.bestTranscription.formattedString))
        }
    }
    
    /// Clean up transcription resources
    func cleanup() {
        recognitionTask?.cancel()
        recognitionRequest?.endAudio()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
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