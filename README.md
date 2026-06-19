<p align="center">
  <img src="assets/icon.png" width="120" />
</p>

<h1 align="center">DartCam</h1>

<p align="center">
  <strong>Minimal dart scorer — snap a photo or tap to score.</strong><br/>
  Built for friend hangouts. Works on Android, iOS, and web.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-android%20%7C%20ios%20%7C%20web-blue?style=flat-square" alt="Platforms" />
  <img src="https://img.shields.io/badge/version-0.1.0--beta-FF6D00?style=flat-square" alt="Version" />
  <img src="https://img.shields.io/badge/flutter-3.44-02569B?style=flat-square&logo=flutter" alt="Flutter" />
</p>

---

## Download

> **Latest:** [v0.1.0 Beta](https://github.com/sayanmohsin/dartcam/releases/tag/v0.1.0-beta) — download the APK and install on your Android device.

APK: `DartCam-v0.1.0-beta.apk`

---

## What is DartCam?

DartCam is a clean, no-fuss dart scoring app. No accounts, no cloud, no distractions — just you, the board, and the game.

**Two ways to score:**

- **Camera** — snap a photo of the board after your throw, DartCam detects where your darts landed
- **Manual** — tap in your scores the quick way

## Features

| | |
|---|---|
| Camera detection | Snap a photo, DartCam spots your darts using on-device image processing |
| Manual entry | Quick tap-to-score with multiplier validation (no triple bull, no double 25) |
| Match modes | 301, 501, 701, 1001 with double-out enforcement |
| Bust detection | Over-bust, can't-finish-on-1, must-finish-on-double — all handled |
| Undo | Made a mistake? Undo the last dart |
| Multiplayer | 2–8 players with automatic turn rotation |
| Dark theme | Neon orange accent on dark background — easy on the eyes for late-night games |
| Branded splash | Clean loading screen with fade-in animation |
| About page | Built by [Sayan Mohsin](https://github.com/sayanmohsin) |

## How It Works

DartCam uses a **snapshot comparison** approach:

1. **Calibrate** — take a photo of your empty board
2. **Throw** — take a photo after each turn
3. **Compare** — DartCam diffs the two images to find new dart positions
4. **Score** — translates pixel positions to dartboard scores

All processing happens **on your device**. No internet required.

## Screenshots

> _Add screenshots of your app here_

```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│   Splash    │  │   Setup     │  │   Scoring   │
│   Screen    │  │   Screen    │  │    Screen   │
└─────────────┘  └─────────────┘  └─────────────┘
```

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.44+)
- Android Studio / VS Code
- Android device or emulator

### Run the app

```bash
# Clone the repo
git clone https://github.com/sayanmohsin/dartcam.git
cd dartcam

# Install dependencies
flutter pub get

# Run on connected device
flutter run
```

### Build release APK

```bash
flutter build apk --release
```

> The release APK requires a signing key. See [Android signing docs](https://docs.flutter.dev/deployment/android#signing-the-app) for setup.

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart) |
| Camera | image_picker |
| Image processing | Pure Dart (image package) |
| State management | ValueNotifier + MatchStateManager |
| Icons | flutter_launcher_icons |
| Native splash | flutter_native_splash |
| URL launching | url_launcher |

## Project Structure

```
lib/
├── main.dart                          # App entry, theme, SetupScreen, GameScreen
├── core/
│   ├── constants/dartboard_constants.dart  # Board dimensions, wedge values
│   └── vision/
│       ├── cv_engine.dart             # Image diffing + blob detection
│       └── scoring_geometry.dart      # Pixel-to-score translation
├── data/
│   ├── models/
│   │   ├── match_state.dart           # DartMatch, PlayerProfile, TurnMutation
│   │   └── scoring.dart               # ScoredDart, DetectedPoint
│   └── state/match_state_manager.dart # State management + bust logic
└── presentation/
    ├── screens/
    │   ├── 00_splash_screen.dart      # Branded loading screen
    │   ├── 01_turn_screen.dart        # Main scoring UI
    │   ├── 03_detection_screen.dart   # Camera capture + CV processing
    │   └── 04_about_screen.dart       # About page
    └── widgets/
        ├── manual_picker_grid.dart    # Dart score picker modal
        └── score_badge.dart           # Score display badge
```

## Status

**Beta** — camera detection works best with:
- Well-lit dartboards
- Clear dart visibility (no blurry shots)
- Consistent board position between calibration and throw photos

Manual entry works perfectly as a fallback.

## Known Limitations

- Camera detection is sensitive to lighting conditions
- Board must stay in roughly the same position between calibration and throw photos
- No score history persistence (matches are session-only)
- Release APK requires manual signing key setup

## License

This project is private. All rights reserved.

## Built by

**[Sayan Mohsin](https://github.com/sayanmohsin)**
