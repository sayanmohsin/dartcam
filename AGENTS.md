# Agent Notes

This is the source repository for **DartCam**, a minimal, on-device dart scorer built with Flutter.

## Current State
The app currently uses `shared_preferences` as its primary persistence layer. It manages game state in `MatchStateManager` by saving the entire `DartMatchState` (including match history) as a single serialized JSON string.

The current CV pipeline uses pixel-diffing (`cv_engine.dart`) which is fundamentally broken — too sensitive to lighting changes and camera movement. We are migrating to a TFLite-based approach using the pre-trained DeepDarts D2 model.

## Planned Migration (Active Priority)
We are currently in the process of **migrating from `shared_preferences` to `thingd`**.
Because `thingd-core` is a Rust crate, it will be embedded natively into this Flutter app using **Flutter Rust Bridge (FRB)**.

**Detailed Migration Plan:**
*See the `DartCam Migration to thingd` section at the bottom of this document for the exact step-by-step implementation plan.*

If you are asked to work on features involving state, persistence, undo functionality, or player profiles, **do not build them on top of `shared_preferences`**. Refer to the migration plan and implement them using the event-sourced `thingd` stream approach.

## Tech Stack
- **Framework:** Flutter (Dart)
- **Computer Vision:** On-device ML via `tflite_flutter` (DeepDarts D2, YOLOv4-tiny) + pure Dart scoring math
- **State Management:** `ValueNotifier` + `MatchStateManager` (Currently migrating to `thingd`)
- **Persistence:** `shared_preferences` (Currently migrating to `thingd-core` via FFI)

## Key File Locations
- `lib/main.dart` — App entry and routing
- `lib/data/state/match_state_manager.dart` — Core game loop state machine (migration target)
- `lib/core/vision/cv_engine.dart` — TFLite model runner and OpenCV homography scoring (being replaced)
- `lib/core/vision/ml_engine.dart` — NEW: TFLite inference + YOLOv4-tiny decoding (migration target)
- `lib/core/vision/dartboard_scorer.dart` — NEW: Perspective transform + polar coordinate scoring

---

# DartCam Migration to `thingd`

This section details the step-by-step implementation plan for migrating DartCam's persistence layer from `shared_preferences` to the embedded `thingd-core` Rust engine.

## The Goal
DartCam currently stores its entire match state, including every historical turn (`TurnMutation`), into a single JSON string in `shared_preferences`. This scales poorly, risks data loss, and makes adding future features (like match history, player leaderboards, or cloud sync) very difficult.

We will embed `thingd-core` into the Flutter app to provide a high-performance local SQLite database with built-in object, event, and queue semantics. 

## Phase 1: Native Rust Bridge Setup
`thingd-core` is a Rust crate. We need to bridge it to Dart.

1. **Add Dependencies**: 
   - Add `flutter_rust_bridge` (FRB) to `pubspec.yaml`.
   - Initialize the FRB rust template in the `rust/` directory.
2. **Import `thingd-core`**:
   - In `rust/Cargo.toml`, add `thingd-core = "0.25.0"` (ensure the version matches what is published on crates.io).
3. **Write the FFI layer**:
   - In `rust/src/api.rs`, write wrapper functions that instantiate `SqliteThingStore::open(path)` and expose its core methods:
     - `put_object(collection, object)`
     - `append_event(stream, event)`
     - `list_events(stream)`
4. **Generate Bindings**: 
   - Run the FRB code generator to create the Dart interfaces in `lib/src/rust/`.

## Phase 2: Event-Sourced Match Engine
Currently, `MatchStateManager` maintains a `List<TurnMutation> history`. We will transition this to an event-sourced stream using `thingd`'s Event Log.

1. **Event Append**:
   - Modify `recordTurn()` in `MatchStateManager`. Instead of adding to a Dart array and calling `_save()`, call `thingd.appendEvent("match_${matchId}", turnMutationJson)`.
2. **Match Replay**:
   - Modify `MatchStateManager.load()`. Instead of loading a JSON blob, stream all events from the `match_${matchId}` stream (`thingd.listEvents`) and replay them through a reducer to rebuild the current `DartMatchState`.
3. **Undo Feature**:
   - Since `thingd` streams are append-only logs, an undo operation becomes either:
     a) Appending a compensating `turn_undone` event.
     b) (If `thingd` supports it) deleting the last event. Replaying the stream up to `length - 1` is also an option.

## Phase 3: Object Storage for Metadata
Move all non-event data out of `shared_preferences` and into `thingd` Document Collections.

1. **Active Match Status**: 
   - Store the current active match ID in `shared_preferences` (the *only* thing that should stay there).
   - Store the match configuration (Game Type 501, Date Started) in a `thingd` object: `thingd.putObject('matches', matchId, config)`.
2. **Player Profiles**:
   - Store players globally instead of just inside the match state.
   - `thingd.putObject('players', playerId, { name, totalWins, totalDartsThrown })`.
   - Update player stats asynchronously at the end of a match.

## Phase 4: Queueing Computer Vision Tasks (Optional but Recommended)
DartCam's `cv_engine.dart` runs synchronously or in a simple isolate.

1. **Background Queue**:
   - When a photo is taken, instead of waiting for the UI to process it, push a job to a local `thingd` queue: `thingd.pushJob('vision_tasks', { imagePath: '...' })`.
2. **Worker Isolate**:
   - A Dart isolate claims jobs from the queue, runs the TFLite inference and OpenCV math, and appends the calculated score event to the match stream.
   - This keeps the UI completely fluid even on slower Android devices.

## Migration Verification Steps
- [ ] FRB generates successfully on iOS and Android.
- [ ] Starting a new 501 game successfully creates a `matches` object and a `match_...` event stream.
- [ ] Throwing a dart instantly appends an event and updates the UI.
- [ ] Closing the app mid-game and reopening perfectly replays the event stream to restore the exact score.
- [ ] Manual Entry fallback continues to work by bypassing the queue and directly appending an event.

---

# DartCam CV Migration to TFLite (On-Device ML)

This section details the migration plan from fragile pixel-diffing to a robust on-device ML approach using the **DeepDarts D2** pre-trained model.

## The Goal
The current classical CV approach (pixel-diffing) fails due to lighting variations and slight camera movements. We will replace it with a deep learning approach that:
1. Detects dart tips + 4 calibration points using a YOLOv4-tiny model
2. Uses calibration points to compute a perspective transform (handles camera angles)
3. Scores darts using polar coordinates on the corrected board plane

**Model:** DeepDarts D2 (`deepdarts_d2.tflite`) — YOLOv4-tiny, 84% accuracy on handheld camera photos.
**Source:** [DeepDarts (CVSports 2021)](https://github.com/iambhabha/Dart-Vision) — pre-trained TFLite models available on Google Drive.

## Key Architecture Decision: No OpenCV Required
The perspective transform and polar coordinate scoring can be implemented in **pure Dart** (matrix multiplication + trigonometry). This avoids the complexity of native `opencv_dart` FFI bindings. The existing `image` package handles all image preprocessing (decode, resize, color conversion).

## Phase 1: Setup and Infrastructure

### Step 1.1: Add `tflite_flutter` Dependency
Add to `pubspec.yaml`:
```yaml
dependencies:
  tflite_flutter: ^0.12.1
```
Run `flutter pub get`.

### Step 1.2: Download and Bundle the Model
1. Download `deepdarts_models.zip` from [Google Drive](https://drive.google.com/file/d/1ss_VXRuRSeuLgP8-dXdVDYpAaIMbY2tN/view?usp=sharing)
2. Extract `deepdarts_d2.tflite` (~22.5 MB)
3. Place at `assets/models/deepdarts_d2.tflite`
4. Add to `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/models/deepdarts_d2.tflite
```

### Step 1.3: Android/iOS Native Setup
`tflite_flutter` requires minimal native setup:
- **Android**: No changes needed (dynamic libraries auto-downloaded for API 26+)
- **iOS**: No changes needed (auto-downloaded)
- **GPU Delegates**: Optional — configure in Dart code at runtime (not native build)

### Step 1.4: Create Worker Isolate
The TFLite inference + post-processing must NOT run on the main isolate.
- Use `IsolateInterpreter.create(address: interpreter.address)` from `tflite_flutter`
- Or use Dart's `compute()` function (already used in `03_detection_screen.dart`)

## Phase 2: TFLite Inference Pipeline (The "What")

### Step 2.1: Model Specification
```
Model:      deepdarts_d2.tflite (YOLOv4-tiny)
Input:      [1, 800, 800, 3]  — float32, range 0.0–1.0, RGB
Output 1:   [1, 50, 50, 30]   — stride 16 (large objects)
Output 2:   [1, 25, 25, 30]   — stride 32 (small objects)
```

Each output grid cell has 3 anchors × 10 values:
```
[tx, ty]   → x,y center in cell    (apply sigmoid)
[tw, th]   → box width/height      (apply exp × anchor)
[obj]      → objectness confidence  (apply sigmoid)
[cls 0–4]  → class scores × obj    (apply sigmoid)
              cls 0 = dart tip
              cls 1 = calibration point 1 (corner of 20 segment)
              cls 2 = calibration point 2 (corner of 6 segment)
              cls 3 = calibration point 3 (corner of 3 segment)
              cls 4 = calibration point 4 (corner of 11 segment)
```

**Anchors (in pixels):**
```
Stride 16: [[81,82], [135,169], [344,319]]
Stride 32: [[23,27], [37,58],   [81,82]]
```

### Step 2.2: Create `lib/core/vision/ml_engine.dart`
New file — the core ML inference engine.

```dart
class MLEngine {
  static Interpreter? _interpreter;
  
  // Load model (call once at app start or on first detection)
  static Future<void> loadModel() async {
    _interpreter = await Interpreter.fromAsset(
      'assets/models/deepdarts_d2.tflite',
    );
  }
  
  // Run inference on a single image
  static Future<MLResult> detect(Uint8List imageBytes) async {
    // 1. Decode image using `image` package
    // 2. Resize to 800x800
    // 3. Normalize to 0-1 (divide by 255)
    // 4. Convert to [1, 800, 800, 3] float32 tensor
    // 5. Run interpreter.invoke()
    // 6. Get output tensors [1,50,50,30] and [1,25,25,30]
    // 7. Decode predictions (see Step 2.3)
    // 8. Return MLResult with dart positions + calibration points
  }
}
```

### Step 2.3: Port YOLOv4-tiny Decoding to Dart
Port the `decode_predictions()` function from Python to Dart. The logic is:

```dart
List<YoloBox> decodePredictions(
  List<List<List<List<double>>>> rawOutput,  // [1, H, W, 30]
  int stride,
  List<List<int>> anchors,
  double confThreshold,
) {
  final boxes = [];
  final gh = rawOutput[0].length;
  final gw = rawOutput[0][0].length;
  
  for (int a = 0; a < 3; a++) {        // 3 anchors
    for (int gy = 0; gy < gh; gy++) {   // grid height
      for (int gx = 0; gx < gw; gx++) { // grid width
        final cell = rawOutput[0][gy][gx];
        final offset = a * 10;
        
        final tx = sigmoid(cell[offset + 0]);
        final ty = sigmoid(cell[offset + 1]);
        final tw = cell[offset + 2];
        final th = cell[offset + 3];
        final obj = sigmoid(cell[offset + 4]);
        
        // Class scores
        final classScores = <double>[];
        for (int c = 0; c < 5; c++) {
          classScores.add(sigmoid(cell[offset + 5 + c]) * obj);
        }
        
        final classId = argMax(classScores);
        final score = classScores[classId];
        
        if (score < confThreshold) continue;
        
        // Decode box
        final bx = (gx + tx) / gw;
        final by = (gy + ty) / gh;
        final bw = anchors[a][0] * exp(tw) / 800;
        final bh = anchors[a][1] * exp(th) / 800;
        
        boxes.add(YoloBox(bx, by, bw, bh, score, classId));
      }
    }
  }
  return boxes;
}
```

### Step 2.4: Implement NMS in Dart
Port the `nms()` function. Run NMS per class, keeping boxes with IoU < 0.45.

### Step 2.5: Extract Keypoints
Port `bboxes_to_xy()` — group detections by class, take up to 3 dart tips, 1 per calibration point.

## Phase 3: Perspective Transform & Scoring (The "Where")

### Step 3.1: Create `lib/core/vision/dartboard_scorer.dart`
New file — pure Dart scoring engine (no OpenCV needed).

### Step 3.2: Compute Perspective Transform
The 4 calibration points map to known positions on the standardized dartboard:
- Calibration point 1: Upper-left corner of double-20 segment
- Calibration point 2: Upper-left corner of double-6 segment
- Calibration point 3: Upper-left corner of double-3 segment
- Calibration point 4: Upper-left corner of double-11 segment

Compute a 3×3 homography matrix using the DLT (Direct Linear Transform) algorithm:
1. Compute center of 4 calibration points
2. Compute the reference positions on the standardized board plane
3. Solve for the 3×3 matrix M using SVD or Gaussian elimination
4. Apply M to each dart tip coordinate: `dart_board = M × dart_image`

This is pure linear algebra — no OpenCV needed.

### Step 3.3: Score Using Polar Coordinates
After perspective correction:
1. Compute distance from board center: `d = sqrt(dx² + dy²)`
2. Compute angle: `θ = atan2(-dy, dx)` (note: y is flipped)
3. Map angle to board number: `number = BOARD_DICT[floor(θ / 18)]`
4. Check ring:
   - `d <= innerBullRadius` → Double Bull (50)
   - `d <= outerBullRadius` → Single Bull (25)
   - `d in [trebleInner, trebleOuter]` → Triple (number × 3)
   - `d in [doubleInner, doubleOuter]` → Double (number × 2)
   - Otherwise → Single (number)
   - `d > boardRadius` → Miss (0)

### Step 3.4: Board Constants (Standard BDO)
```dart
const double boardRadius = 170.0;        // mm
const double trebleInnerRadius = 99.0;   // mm (107.4 - 8.4 wire)
const double trebleOuterRadius = 107.4;  // mm
const double doubleInnerRadius = 162.0;  // mm (170.0 - 8.0 wire)
const double doubleOuterRadius = 170.0;  // mm
const double innerBullRadius = 6.35;     // mm
const double outerBullRadius = 15.9;     // mm
const double wireWidth = 1.0;            // mm

// Standard dartboard numbers (clockwise from top)
const List<String> boardNumbers = [
  '20', '1', '18', '4', '13', '6', '10', '15',
  '2', '17', '3', '19', '7', '16', '8', '11',
  '14', '9', '12', '5'
];
```

## Phase 4: Detection Screen Rewrite

### Step 4.1: Rewrite `lib/presentation/screens/03_detection_screen.dart`
Replace the entire pixel-diffing pipeline with:

```
1. Load image bytes from disk
2. Call MLEngine.detect(imageBytes) on background isolate
3. If < 4 calibration points detected → show "Board not fully visible" error
4. If 0 dart tips detected → show "No darts detected" with manual fallback
5. If darts detected → run DartboardScorer.scoreDarts() → show score badges
```

### Step 4.2: Remove Old Code
- Delete `lib/core/vision/cv_engine.dart` (pixel-diffing engine)
- Delete `lib/core/vision/scoring_geometry.dart` (replaced by dartboard_scorer.dart)
- Remove the `_processDartDetection()` top-level function from detection_screen.dart
- Remove the `_processImagesPure()` web-path duplicate code
- Remove `image` package from dependencies (no longer needed for CV, only for camera screen)

### Step 4.3: Simplify Camera Screen
The `camera_screen.dart` can remain mostly as-is. The board guide overlay helps users frame the board, which is important for the calibration point detection.

## Phase 5: Error Handling and UX

### Step 5.1: Detection Failure States
- **"Board not detected"** (< 4 calibration points): Show overlay with guidance to include the full board
- **"No darts detected"** (0 dart tips): Show "Enter Manually" fallback
- **"Partial detection"** (1-2 darts): Show detected darts, allow manual add
- **"Model loading"**: Show loading spinner on first use

### Step 5.2: Confidence Thresholds
- Calibration points: confidence > 0.5 (must be reliable for homography)
- Dart tips: confidence > 0.25 (more lenient, allow manual correction)

### Step 5.3: Performance Targets
- Model load: < 1 second (first time), cached after that
- Inference: < 200ms on mid-range Android (with GPU delegate)
- Post-processing: < 50ms (pure Dart math)
- Total pipeline: < 500ms end-to-end

## Implementation Order
1. Download model, add `tflite_flutter`, verify it loads on device
2. Port YOLOv4-tiny decoding to Dart (`ml_engine.dart`)
3. Port NMS to Dart
4. Implement keypoint extraction
5. Implement perspective transform (pure Dart linear algebra)
6. Implement polar coordinate scoring (`dartboard_scorer.dart`)
7. Rewrite `03_detection_screen.dart` to use new pipeline
8. Remove old CV code
9. Test with sample images
10. Test with live camera on device

## Verification Steps
- [ ] `tflite_flutter` loads `deepdarts_d2.tflite` on Android device
- [ ] Model inference runs in < 200ms
- [ ] YOLOv4-tiny decoding produces correct bounding boxes
- [ ] NMS filters overlapping detections correctly
- [ ] Calibration points are detected on sample dartboard images
- [ ] Perspective transform corrects for camera angle
- [ ] Scoring matches expected results for sample images
- [ ] Detection screen shows scores with edit/manual fallback
- [ ] "No darts detected" state works correctly
- [ ] "Board not detected" state works correctly
- [ ] End-to-end: camera capture → detection → score confirm → recordTurn()
