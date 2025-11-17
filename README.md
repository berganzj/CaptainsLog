# Captain's Log 🖖

A Star Trek-inspired daily journal application for iOS with voice recording, text-to-speech, and ML-ready data architecture.

## Features

### Current (v1.0)
- **Voice Recording**: Record audio journal entries with timestamp metadata
- **Text Entries**: Write journal entries with real-time analysis
- **Text-to-Speech**: Listen to your written entries
- **Daily Timeline**: View all entries for today with chronological ordering
- **Historical Logs**: Browse and search past journal entries
- **Star Trek Theming**: Authentic stardate generation and space-themed UI
- **Core Data Persistence**: Robust data storage with ML-ready schema

### Future ML Enhancements (Planned)
- **Sentiment Analysis**: CoreML-powered mood detection and trends
- **Speech Transcription**: Automatic voice-to-text conversion
- **Topic Clustering**: AI-driven categorization of journal themes  
- **Personal Insights**: Pattern recognition across historical entries
- **Predictive Journaling**: Smart prompts based on writing patterns

## Architecture

### ML-Ready Data Model
The Core Data schema is designed for future machine learning integration:

```swift
LogEntry Entity:
├── Basic Fields (id, timestamp, content, type)
├── ML Metadata (wordCount, duration, mood, topics)
├── Analytics (analysisMetadata JSON, mlFeatureVector binary)
└── Future Fields (audioTranscription, locationContext)
```

### Analytics Framework
- **AnalyticsManager**: Extensible class ready for CoreML integration
- **Feature Extraction**: Automatic metadata generation for ML training
- **JSON Serialization**: Structured data export for model training
- **NaturalLanguage Integration**: Built-in topic and sentiment detection

## Development

### Requirements
- iOS 17.0+
- Xcode 15.0+
- Swift 5.0+

### Setup
1. Clone the repository
2. Open `CaptainsLog.xcodeproj` in Xcode
3. Build and run on iOS simulator or device

### Permissions
- **Microphone Access**: Required for voice recording functionality
- **Speech Recognition**: Future enhancement for transcription

## Data Privacy
- All journal data stored locally on device
- No network communication in current version
- User maintains full control over personal data

## Star Trek References
- **Stardate Format**: Authentic Trek-style date generation
- **Captain's Log Terminology**: Classic opening phrases
- **Space-Themed UI**: Colors and iconography inspired by Federation interfaces

Built with SwiftUI, AVFoundation, Core Data, and NaturalLanguage frameworks.
