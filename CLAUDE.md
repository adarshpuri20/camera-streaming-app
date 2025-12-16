# CLAUDE.md – Maya Cam Flutter Client

## Tech Stack

- **Framework**: Flutter (mobile + web)
- **Language**: Dart
- **Key packages**:
  - `camera` – camera access and preview
  - `livekit_client` – WebRTC streaming to LiveKit
- **Role in system**:
  - Provides camera preview and streaming UI
  - Calls backend API (`POST /live/start`, `POST /live/stop`) at `api.mayacam.link`
  - Connects to LiveKit at `wss://livekit.mayacam.link` using JWT token from backend

## Project Structure

lib/
├── main.dart # App entry point
├── screens/ # UI screens (preview, live, status)
├── services/ # API client, LiveKit client logic
├── models/ # Data models (Session, RecordingState, etc)
└── config.dart # Configuration (API base URL, LiveKit URL)

test/ # Unit & widget tests
integration_test/ # End-to-end tests (optional, scaffold if needed)
pubspec.yaml # Dart dependencies
pubspec.lock # Locked versions
analysis_options.yaml # Lint rules

text

## How to Run Locally

### Prerequisites
- Flutter SDK installed (`flutter --version` to verify)
- Device, emulator, or Chrome for web testing
- Backend API running at `https://api.mayacam.link` (or `http://localhost:8000` for local dev)

### Setup

cd camera_streaming_app

Install dependencies
flutter pub get

(Optional) Clean and rebuild
flutter clean
flutter pub get

text

### Run on Web (Chrome)

flutter run -d chrome

text

### Run on Device/Emulator

List available devices
flutter devices

Run on specific device
flutter run -d <device-id>

text

### Run on iOS (macOS only)

flutter run -d ios

text

### Run on Android

flutter run -d android

text

## Configuration

### Backend & LiveKit URLs

- **File**: `lib/config.dart` (or wherever URLs are defined)
- **Key variables**:
  - `API_BASE_URL` – Backend API base (e.g., `https://api.mayacam.link`)
  - `LIVEKIT_URL` – LiveKit server URL (e.g., `wss://livekit.mayacam.link`)

When Claude modifies API endpoints or URLs, it should update `lib/config.dart` first, then propagate changes to services.

## How to Run Tests

### Unit & Widget Tests

Run all tests
flutter test

Run specific test file
flutter test test/services/api_client_test.dart

Run with verbose output
flutter test --verbose

text

### Integration Tests (End-to-End)

Web
flutter test integration_test/app_test.dart -d chrome

Device/emulator
flutter test integration_test/app_test.dart -d <device-id>

text

### Key Test Flows to Implement

If tests don't yet exist, Claude should scaffold:

1. **Start Recording Flow**:
   - User taps "Go Live"
   - App calls `POST /live/start` with `{tenantId, siteId, cameraId, mode}`
   - Backend returns session token and LiveKit connection URL
   - App connects to LiveKit and publishes camera/audio tracks
   - Expected: UI shows "Recording Active" status

2. **Stop Recording Flow**:
   - User taps "Stop"
   - App calls `POST /live/stop` with `{sessionId}`
   - Backend stops egress
   - App disconnects from LiveKit
   - Expected: UI shows "Recording Stopped" status and cleanup completes

3. **Error Handling**:
   - Backend unreachable
   - LiveKit connection fails
   - Camera permissions denied

## Architecture Summary

### UI Layer
- **Main entry**: `lib/main.dart`
- **Screens**:
  - Camera preview screen (shows live feed)
  - Go Live / Stop button controls
  - Session status display (pending → active → stopped → completed)

### Networking Layer
- **API Service**: Calls backend endpoints (`/live/start`, `/live/stop`)
- **Authentication**: Uses JWT token from backend for LiveKit connections
- **Error Handling**: Graceful fallback and user-facing error messages

### Streaming Layer
- **LiveKit Client**: Configured with URL + token
- **Media Tracks**: Camera (video) + microphone (audio) published to room
- **Permissions**: Camera and microphone access for all platforms

## Key Conventions

1. **Configuration**: All URLs, API keys, and environment variables go in `lib/config.dart` (never hardcode)
2. **Secrets**: Never hardcode tokens or credentials—always request from backend
3. **Error Handling**: Wrap API calls in try/catch, display user-friendly error messages
4. **Permissions**: Request camera/microphone permissions at app startup or before "Go Live"
5. **State Management**: Use Flutter's recommended patterns (Provider, Riverpod, or GetX—note which is used)
6. **Logging**: Add debug logs for key lifecycle events (app start, API calls, LiveKit connect/disconnect)

## Platform-Specific Gotchas

- **Web**: WebRTC permissions handled by browser; test in Chrome/Firefox
- **iOS**: Requires NSCameraUsageDescription and NSMicrophoneUsageDescription in `Info.plist`
- **Android**: Requires CAMERA and RECORD_AUDIO permissions in `AndroidManifest.xml`

## How Claude Should Work in This Repo

When assisting:

1. **Clarify scope**:
   - Which platform(s)? (web, iOS, Android, all)
   - Is this a new feature, bug fix, or refactor?

2. **Propose a plan**:
   - Outline changes before writing code
   - Suggest test coverage needed

3. **Make small, reviewable changes**:
   - One feature per commit
   - Example commit: `feat: add zoom slider to camera preview`

4. **Provide precise diffs**:
   - Show exact file changes
   - Include line numbers or context

5. **Update tests**:
   - Add unit/widget tests for new logic
   - Update integration tests if flow changes

6. **Suggest manual validation**:
   - Example: "Run `flutter run -d chrome`, tap 'Go Live', verify camera preview streams, check console for API response"

## Useful Commands

Format code
dart format lib/

Analyze code for issues
flutter analyze

Generate build files (iOS/Android)
flutter pub run build_runner build

Update dependencies
flutter pub upgrade

Create a release build (web)
flutter build web

Create a release build (iOS)
flutter build ios

Create a release build (Android)
flutter build apk

text

## Deployment

- **Web**: Run `flutter build web`, deploy `build/web/` to static hosting
- **iOS**: Build via Xcode or `flutter build ios`, submit to App Store
- **Android**: Build via Android Studio or `flutter build apk`, submit to Play Store

All changes start on a feature branch off `main` and are merged via PR.
