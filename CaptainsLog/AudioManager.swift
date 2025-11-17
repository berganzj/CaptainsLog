//
//  AudioManager.swift
//  CaptainsLog
//
//  Created on November 16, 2025.
//

import Foundation
import AVFoundation
import Speech

class AudioManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var currentlyPlayingFile: String? = nil
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var speechSynthesizer = AVSpeechSynthesizer()
    private var recordingStartTime: Date?
    
    var lastRecordingFilename: String?
    var lastRecordingDuration: Double?
    
    private var recordingSession: AVAudioSession {
        AVAudioSession.sharedInstance()
    }
    
    override init() {
        super.init()
        setupAudioSession()
        speechSynthesizer.delegate = self
    }
    
    private func setupAudioSession() {
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
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
            completion(true)
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