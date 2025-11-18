//
//  AudioManager.swift
//  CaptainsLog
//
//  Created on November 16, 2025.
//

import Foundation
import AVFoundation
import Combine

class AudioManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var currentlyPlayingFile: String? = nil
    @Published var isTranscribing = false
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var speechSynthesizer = AVSpeechSynthesizer()
    private var recordingStartTime: Date?
    private var whisperManager = WhisperManager()
    
    var lastRecordingFilename: String?
    var lastRecordingDuration: Double?
    var lastRecordingTranscription: String?
    
    private var recordingSession: AVAudioSession {
        AVAudioSession.sharedInstance()
    }
    
    override init() {
        super.init()
        setupAudioSession()
        speechSynthesizer.delegate = self
        
        // Monitor transcription state from WhisperManager
        whisperManager.$isTranscribing
            .receive(on: DispatchQueue.main)
            .assign(to: \.isTranscribing, on: self)
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func setupAudioSession() {
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try recordingSession.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        recordingSession.requestRecordPermission { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    
    func startRecording(completion: @escaping (Bool) -> Void) {
        requestMicrophonePermission { [weak self] granted in
            guard granted else {
                completion(false)
                return
            }
            
            self?.beginRecording(completion: completion)
        }
    }
    
    private func beginRecording(completion: @escaping (Bool) -> Void) {
        let recordingURL = getRecordingURL()
        lastRecordingFilename = recordingURL.lastPathComponent
        recordingStartTime = Date() // Track start time for duration calculation
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            DispatchQueue.main.async {
                self.isRecording = true
                completion(true)
            }
        } catch {
            print("Failed to start recording: \(error)")
            DispatchQueue.main.async {
                completion(false)
            }
        }
    }
    
    func stopRecording(completion: @escaping (Bool) -> Void) {
        // Calculate recording duration for ML analytics
        if let startTime = recordingStartTime {
            lastRecordingDuration = Date().timeIntervalSince(startTime)
        }
        
        audioRecorder?.stop()
        audioRecorder = nil
        recordingStartTime = nil
        
        DispatchQueue.main.async {
            self.isRecording = false
            
            // Trigger transcription if we have a recording
            if let filename = self.lastRecordingFilename {
                self.transcribeRecording(filename: filename)
            }
            
            completion(true)
        }
    }
    
    /// Transcribe the recorded audio using WhisperManager
    private func transcribeRecording(filename: String) {
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("Audio file not found for transcription: \(filename)")
            return
        }
        
        whisperManager.transcribeAudio(from: url) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let transcription):
                    self?.lastRecordingTranscription = transcription
                    print("Transcription successful: \(transcription)")
                case .failure(let error):
                    self?.lastRecordingTranscription = nil
                    print("Transcription failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func playRecording(filename: String, completion: @escaping (Bool) -> Void) {
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            completion(false)
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            
            DispatchQueue.main.async {
                self.isPlaying = true
                self.currentlyPlayingFile = filename
                completion(true)
            }
        } catch {
            print("Failed to play recording: \(error)")
            completion(false)
        }
    }
    
    func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentlyPlayingFile = nil
        }
    }
    
    func speakText(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        
        speechSynthesizer.speak(utterance)
    }
    
    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
    }
    
    func deleteRecording(filename: String) {
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            print("Failed to delete recording: \(error)")
        }
    }
    
    /// Transcribe an existing recording file
    func transcribeExistingRecording(filename: String, completion: @escaping (String?) -> Void) {
        let url = getDocumentsDirectory().appendingPathComponent(filename)
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            completion(nil)
            return
        }
        
        whisperManager.transcribeAudio(from: url) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let transcription):
                    completion(transcription)
                case .failure(let error):
                    print("Transcription failed: \(error.localizedDescription)")
                    completion(nil)
                }
            }
        }
    }
    
    private func getRecordingURL() -> URL {
        let filename = "recording_\(Date().timeIntervalSince1970).m4a"
        return getDocumentsDirectory().appendingPathComponent(filename)
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioManager: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            print("Recording failed")
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            print("Recording error: \(error)")
        }
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentlyPlayingFile = nil
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            print("Playback error: \(error)")
        }
        
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentlyPlayingFile = nil
        }
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension AudioManager: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Speech finished
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // Speech cancelled
    }
}