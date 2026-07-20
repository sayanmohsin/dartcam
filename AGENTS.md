# Agent Notes

This is the source repository for **DartCam**, a minimal, on-device dart scorer built with Flutter.

## Current State

### Persistence — `thingd` (embedded Rust engine via FRB)
All game state is persisted through `thingd`, an embedded Rust crate (v0.49.7, `SqliteThingStore` with `sqlite` feature). The FRB bridge (`rust/src/api/bridge.rs`) exposes all 6 storage traits:

| Trait | Methods | Used For |
|---|---|---|
| **ObjectStore** | put/get/delete/batch/list | Match configs, player profiles, user email, match history index |
| **EventLog** | append/list/delete/stream | Turn mutations, detection logs |
| **Searcher** | search (Tantivy FTS) | Looking up past matches |
| **AggregateStore** | aggregate/timeseries | Player stats (win counts, avg scores) |
| **QueueStore** | push/claim/ack/nack/list/dead | Async CV processing pipeline |
| **LinkStore** | create/delete/get/neighbors/count | Player↔Match relationships |

### CV Pipeline — TFLite (DeepDarts D2)
- `lib/core/vision/ml_engine.dart` — TFLite inference + YOLOv4-tiny decoding + NMS
- `lib/core/vision/dartboard_scorer.dart` — Pure Dart perspective transform (DLT homography) + polar coordinate scoring
- `lib/presentation/screens/03_detection_screen.dart` — Detection UI, edit/confirm flow

### State Management
- `MatchStateManager` extends `ValueNotifier<DartMatchState>`
- Event-sourced: turns appended to thingd event log, state rebuilt by replay
- Player profiles persisted with lifetime stats (matches, wins, 180s, checkouts)
- Graph links created between players and matches on completion

### Cloud Sync (optional)
- thingd.cloud instance configured via `thingd-cli`
- API token in `.env`, baked into build via `--dart-define-from-file=.env`
- Email entered on first launch scopes data in the shared cloud instance
- `CloudUsageService` pushes aggregate match results + player stats

### Email
- One-time email entry on first launch (saved in local thingd config)
- Editable from Cloud Settings screen
- Used as scoping field in cloud requests

## Tech Stack
- **Framework:** Flutter (Dart)
- **Computer Vision:** On-device ML via `tflite_flutter` (DeepDarts D2, YOLOv4-tiny) + pure Dart scoring math
- **State Management:** `ValueNotifier` + `MatchStateManager`
- **Local Persistence:** `thingd` v0.49.7 (embedded Rust, SQLite via FRB)
- **Cloud:** thingd.cloud REST API (optional, email-scoped)

## Key File Locations
- `lib/main.dart` — App entry and routing
- `lib/data/state/match_state_manager.dart` — Core game loop state machine (event-sourced)
- `lib/core/vision/ml_engine.dart` — TFLite inference + YOLOv4-tiny decoding
- `lib/core/vision/dartboard_scorer.dart` — Perspective transform + polar coordinate scoring
- `lib/services/thingd_service.dart` — Dart wrapper for all 6 thingd traits
- `lib/services/thingd_service_interface.dart` — Abstract interface for testability
- `lib/services/cloud_auth_service.dart` — Cloud connection management
- `lib/services/cloud_usage_service.dart` — Cloud sync (match results, player stats)
- `rust/src/api/bridge.rs` — FRB bridge exposing all 6 thingd traits
- `test/fakes/fake_thingd_service.dart` — In-memory fake for unit tests
- `test/match_state_manager_test.dart` — 17 state machine tests
- `rust/tests/bridge_tests.rs` — 27 Rust integration tests for all traits
- `scripts/setup-cloud.sh` — One-time thingd-cli project setup

## Testing
- **Rust:** `cd rust && cargo test` — 27 tests (all 6 traits)
- **Dart:** `flutter test` — 81 tests (models, ML engine, scorer, state machine, picker)
- **Integration:** `flutter test integration_test/` — Persistence benchmarks

## thingd-cli Cloud Setup
```bash
npx @thingd/cli cloud login
npx @thingd/cli cloud project create dartcam
npx @thingd/cli cloud instance create dartcam prod
npx @thingd/cli cloud token create dartcam-app
cp .env.example .env  # paste the token
flutter build apk --release --dart-define-from-file=.env
```
