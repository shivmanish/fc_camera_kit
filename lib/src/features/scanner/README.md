# Feature: Document Scanner (`scanner`)

> Status: **v1 implemented** with the platform scanner (`cunning_document_scanner`). Decided
> 2026-10-01: **no in-app camera engine.** Sections 2.1, 4, 5 and the `inApp` rows describe that
> dropped option and are kept only as a record. See §13 for what v1 actually is.

Point the camera at a document (Aadhaar, PAN, driving licence, passport page, a stamped paper, a
book page or any photo) and the kit:

1. finds the document's **edges live** and draws its boundary,
2. coaches the user until the shot is good (closer, steadier, less glare...),
3. **auto-captures** once the boundary has been good and steady for **2 s** (configurable), or the
   user taps the shutter,
4. lets the user fine-tune the corners, then flattens the perspective, cleans it up with a filter
   and compresses it under a size budget,
5. returns the finished file(s), with the same `FcResult` contract as `capture()`.

Built for fintech and KYC field apps: ID-card presets, front/back capture, quality checks before
capture, live-capture-only mode, files kept out of the gallery, and who/when/where metadata.

---

## Contents

1. [Using it](#1-using-it)
2. [Screens (sketches)](#2-screens-sketches)
3. [Flow](#3-flow)
4. [Auto-capture](#4-auto-capture)
5. [Edge detection pipeline](#5-edge-detection-pipeline)
6. [Architecture](#6-architecture)
7. [State](#7-state)
8. [Fintech and KYC features](#8-fintech-and-kyc-features)
9. [From the reference implementation](#9-from-the-reference-implementation)
10. [Performance budget](#10-performance-budget)
11. [Edge cases handled](#11-edge-cases-handled)
12. [Engine and package decision](#12-engine-and-package-decision)
13. [Decisions](#13-decisions-resolved-2026-10-01)
14. [Delivery plan](#14-delivery-plan)

---

## 1. Using it

### Setup: the same `init()` as every feature

```dart
// main.dart, once
await FcCameraKit.instance.init(
  user: (id: 'EMP-2291', name: 'Asha Verma'),
  maxBytes: 1024 * 1024,                    // per page, shared with capture()
  scan: const FcScanOptions(
    maxPages: 2,                            // e.g. ID front + back
    source: FcScanSource.camera,            // camera | gallery | cameraAndGallery
    enhancement: FcScanEnhancement.full,    // basic | filters | full
    embedMetadata: true,                    // who / when / where in EXIF
  ),
);
```

`requireLocation` from `init()` applies too: the scanner asks for location before opening and
stamps it into EXIF.

### a) One call

```dart
final result = await FcCameraKit.instance.scan(context);   // or override: scan(context, maxPages: 1)

result.when(
  success: (scan) => upload(scan.pages),                    // List<FcScannedPage>
  failure: (failure) => switch (failure) {
    CancelledFailure() => null,
    PermissionFailure() => showSettingsHint(),
    _ => showError(),
  },
);
```

`scan()` never throws. It lives in `extension FcCameraKitScan on FcCameraKit`
(`fc_camera_kit_scan.dart`), so the core singleton never imports scanner code.

### b) As a screen in the host's own navigation

```dart
GoRoute(
  path: 'kyc/pan',
  builder: (context, state) => FcScannerPage(
    maxPages: 1,
    onCompleted: (scan) => context.read<KycCubit>().attachPan(scan),
    onCancelled: () => context.pop(),
    onFailed: (failure) => context.read<KycCubit>().scanFailed(failure),
  ),
);
```

- With callbacks, the host decides what happens next.
- Without callbacks, the page pops itself with the `FcScanResult` (or `null` on cancel), and shows
  errors itself with **Try again** / **Open settings**.

### What comes back

```dart
FcScanResult(pages)                 // in scan order; .first for single-page scans
FcScannedPage(
  file,                             // XFile, JPEG, app documents dir, under maxBytes
  sizeBytes, width, height,
  wasCompressed, quality,
  metadata,                         // FcPhotoMetadata when embedMetadata is on
)
```

The scanner's own temp copies are deleted after processing, on cancel and on failure. If page 2
fails, page 1's file is deleted too.

---

## 2. Screens (sketches)

Camera surfaces are intentionally dark (true colour of the document matters). Accent colour, type
and button shapes come from the host theme through `FcTheme`.

### 2.1 Scan (live)

> `inApp` engine. With the default `native` engine this step is Google's / Apple's scanner screen,
> and the kit's own screens start at Crop & filter (optional) and processing.

```
┌─────────────────────────────────────┐
│  ✕          Scan PAN card        ⚡ │  close · title from preset · torch
│                                     │
│     ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐     │  guide frame: preset aspect (ID-1 = 1.586)
│        ╔═══════════════════╗        │
│     │  ║  ▒▒▒▒   ▒▒▒▒▒▒▒   ║  │     │  live boundary: accent, follows the card,
│        ║  ▒▒▒▒   ▒▒▒▒      ║        │  smoothed so it never jitters
│     │  ║          ▒▒▒▒▒▒▒  ║  │     │
│        ╚═══════════════════╝        │
│     └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘     │
│                                     │
│         ╭───────────────────╮       │  one hint at a time, highest priority wins
│         │  Hold steady · 3  │       │  (Move closer / Too much glare / ...)
│         ╰───────────────────╯       │
│                                     │
│    ▣            ◯            AUTO   │  gallery · shutter with hold ring · auto toggle
│  Gallery     ╭─────╮          ●     │  ring fills 0 → 100 % over `hold`
│              │  ◉  │                │
│              ╰─────╯                │
│          Front side · 1 of 2        │  step indicator (front/back, page n)
└─────────────────────────────────────┘
```

Boundary colour tells the story without reading:
`no document` → no boundary · `found, not good yet` → neutral outline ·
`good, holding` → accent + ring filling · `captured` → flash + haptic.

### 2.2 Crop & filter

```
┌─────────────────────────────────────┐
│  ←         Crop & filter      ⟲ 90° │  back = retake · rotate
│                                     │
│    ●━━━━━━━━━━━━▬━━━━━━━━━━━━●      │  ● corner handle (48 dp hit area)
│    ┃                         ┃      │  ▬ edge handle moves both corners
│    ┃      ▒▒▒▒▒   ▒▒▒▒▒▒     ┃      │
│    ▮      ▒▒▒▒▒   ▒▒▒        ▮      │  outside the quad is dimmed
│    ┃              ▒▒▒▒▒▒     ┃      │
│    ●━━━━━━━━━━━━▬━━━━━━━━━━━━●      │
│              ╭───────╮              │  loupe while dragging: 2x zoom
│              │   ┼   │              │  under the finger, so the corner
│              ╰───────╯              │  is visible, not hidden by it
│        Reset to detected  ·  Full   │
│ ┌──────┐┌──────┐┌──────┐┌──────┐    │  filter strip: live thumbnails,
│ │ Orig ││ Auto ││ Gray ││ B&W  │    │  same maths as the exported file
│ └──────┘└──────┘└──────┘└──────┘    │
│   ( Retake )        [  Use scan  ]  │  one primary action
└─────────────────────────────────────┘
```

The handles start on the **detected** corners. Full frame is only the fallback when nothing was found.

**Crop**
- Drag a corner, or an edge handle to move both corners of that edge.
- The loupe shows 2x zoom under the finger while dragging.
- A move that would make the shape concave or crossed is refused, so the crop can never be a
  twisted shape.
- *Reset to detected* and *Full image* undo in one tap; ⟲ rotates 90°.
- The crop is a 4-point **perspective** crop: a card shot at an angle comes out as a flat rectangle.
  With `documentType` set, the output is locked to that shape (ID card 1.586).

**Filter**

| Filter | What it does | Good for |
|---|---|---|
| Original | colour as shot | photos, stamps, coloured documents |
| Auto (default) | contrast stretch, background cleaned towards white, text kept dark | most documents, OCR |
| Grayscale | luminance only | smaller files, printed text |
| B&W | adaptive threshold (handles shadows across the page) | faded text, receipts, book pages |
| Colour boost | saturation and contrast up | stamps, signatures in ink, ID card photos |

Each filter is **one Dart function**. Thumbnails and the large preview run it on a downscaled copy
in the isolate (cached per filter), and the export runs the same function on the full image. What
the user picks is exactly what gets saved.

### 2.3 Pages tray (front/back and multi-page)

```
┌─────────────────────────────────────┐
│  ✕            Scan Aadhaar          │
│                                     │
│   ┌─────────┐  ┌─────────┐          │
│   │ ▒▒▒ ▒▒▒ │  │         │          │
│   │ ▒▒▒     │  │   + │   │          │  next slot pulses
│   └─────────┘  └─────────┘          │
│     Front ✓      Back               │
│                                     │
│   ( Retake front )  [ Scan back → ] │  becomes [ Done ] when complete
└─────────────────────────────────────┘
```

### 2.4 Processing and done

```
┌─────────────────────────────────────┐
│                                     │
│              ╭─────╮                │  determinate where possible:
│              │ ◔   │                │  Flattening → Enhancing → Compressing
│              ╰─────╯                │
│          Enhancing page 1/2         │
│                                     │
└─────────────────────────────────────┘
```

Error screens always offer a way forward: **Try again**, **Open settings**, or **Crop manually**.

---

## 3. Flow

```
 host:  scan() / FcScannerPage            editDocument(image) / FcScannerPage(image:)
          │                                         │
          ▼                                         │
   FcPermissionGate.ensure({camera})                │   (existing, reused)
          │  denied ──▶ PermissionFailure           │
          ▼                                         │
 ┌─────────────── FcScannerPage: one route, steps switch inside ───────────────┐
 │                                                  │                          │
 │   ┌──────────┐  auto / tap   ┌──────────────┐◀───┘ detect on still          │
 │   │  Camera  │──────────────▶│    Crop &    │                               │
 │   │  (live)  │◀── retake ────│    filter    │                               │
 │   └────┬─────┘               └──────┬───────┘                               │
 │        │ gallery              ▲     │ use scan                              │
 │        └─▶ picker ─▶ detect ──┘     │                                       │
 │                                     ▼                                       │
 │                              ┌────────────┐   more pages?                   │
 │                              │ Processing │──── yes ──▶ Camera              │
 │                              └─────┬──────┘                                 │
 │                                    │ no                                     │
 └────────────────────────────────────┼────────────────────────────────────────┘
                                      ▼
            FcResult<FcScanResult>  /  onCompleted(FcScanResult)
```

With the `native` engine, the Camera box is the platform scanner (opened from the page, returns
pages); everything after it is identical.

Steps are a sealed state rendered with an `AnimatedSwitcher` inside `FcScannerPage`. Nothing is
pushed, so the scanner works the same under go_router, auto_route or plain `Navigator`, and
**the package takes no go_router dependency for this feature.**

---

## 4. Auto-capture

> Applies to the `inApp` engine. The `native` engine uses the platform's own auto-capture, whose
> timing can't be configured (see §12).

```
                   no quad / quality hint / moved
        ┌────────────────────────────────────────────┐
        ▼                                            │
  ┌───────────┐  good quad   ┌───────────┐  stable for `hold`  ┌───────────┐
  │ Searching │─────────────▶│  Holding  │────────────────────▶│ Capturing │──▶ Crop
  └───────────┘              └───────────┘                     └───────────┘
        ▲                      ring 0→100 %
        │   lost > 300 ms        │
        └────────────────────────┘
```

**Good quad** = all of:

| Check | Rule (defaults, all tunable) | Hint shown when failing |
|---|---|---|
| Found | detection confidence ≥ 0.6 | *Point at a document* |
| Size | quad area ≥ 25 % of frame | *Move closer* |
| Inside | no corner within 2 % of frame edge | *Fit the whole document in* |
| Shape | aspect within ±15 % of preset (not for `any`) | *Align the card with the frame* |
| Light | mean luma inside quad ≥ 60 | *Too dark, turn on the torch* (with torch shortcut) |
| Glare | < 2 % of quad pixels clipped (≥ 250) | *Too much glare, tilt slightly* |
| Sharp | Laplacian variance ≥ threshold | *Hold still, focusing* |
| Level | device tilt ≤ 15° (accelerometer, if present) | *Hold the phone flat* |

**Stable** = smoothed corners move < 1.5 % of the frame diagonal between detections **and** the
gyroscope reports little motion. A single missed frame (≤ 300 ms) doesn't reset the timer, so one
dropped detection doesn't make the user start over.

The ring is a widget-side `AnimationController` started from `holdStartedAt`. The cubit emits only
when the phase changes, never 60 times a second.

Hold defaults to **2 s** and is set per call: `FcAutoCapture(hold: Duration(seconds: 3))`.
The user can switch auto-capture off on the screen (**AUTO** toggle), and the choice is respected for
the rest of the session.

---

## 5. Edge detection pipeline

> `inApp` engine only. The `native` engine uses Google's / Apple's detector.

Pure Dart, running in **one long-lived background isolate**, on a small grayscale copy of the frame.
No OpenCV and no extra native code. It sits behind an interface, so a stronger engine can be plugged
in later without touching the UI.

```
 CameraImage (YUV420 / NV12)
   │  take Y plane only (already grayscale, no conversion)
   ▼
 downscale to ~256 px long side, rotate to preview orientation
   ▼
 Gaussian blur 5×5 ──▶ Sobel gradient ──▶ Otsu threshold on magnitude ──▶ dilate 1 px
   ▼
 contour tracing ──▶ keep largest N by enclosed area
   ▼
 Douglas–Peucker (ε = 2 % perimeter) ──▶ convex 4-gons
   │   (no clean 4-gon → convex hull → 4 extreme points)
   ▼
 score = area × rectangularity (angles ≈ 90°) × aspect match to preset
   ▼
 best quad, corners ordered TL TR BR BL, normalised 0..1, + confidence
   ▼
 EMA smoothing (α ≈ 0.5) on the UI side ──▶ overlay
```

- **Backpressure:** at most one frame in flight; frames arriving while the isolate is busy are
  dropped. Target 8–12 detections/s, and the preview always stays at 60 fps.
- **Transfer:** `TransferableTypedData` for the Y plane (no copy on the receiving side).
- **Still image:** the same detector runs once on the captured photo (higher resolution) to place
  the Crop & filter handles precisely, and on gallery imports.
- **Plug-in point:** `FcDocumentDetector` (abstract). Ships `FcEdgeDocumentDetector` (above) and
  `FcMockDocumentDetector` (tests, example). An ML or OpenCV engine is a new implementation, not a
  rewrite.

Perspective flattening and filters run in a background isolate on the full-resolution still (decode
→ bake EXIF orientation → warp → filter → encode), then go through the existing `FcImageCompressor`
and `FcExifWriter`.

---

## 6. Architecture

Only the layers this feature needs. Shared pieces are reused from `core/` (permissions, compressor,
EXIF, `FcResult`, failures).

```
lib/src/features/scanner/
├── fc_camera_kit_scan.dart                  # extension FcCameraKitScan on FcCameraKit { scan(), editDocument() }
├── domain/
│   ├── entities/
│   │   ├── fc_quad.dart                     # 4 normalised corners + geometry helpers (area, convex, aspect)
│   │   ├── fc_document_type.dart            # presets: any, idCard, passport, a4, letter, book, photo, custom
│   │   ├── fc_scan_config.dart              # FcScanConfig, FcScanMode, FcAutoCapture, FcScanStrings
│   │   ├── fc_scan_filter.dart              # original, auto, grayscale, blackWhite, colorBoost (+ matrices)
│   │   ├── fc_frame_analysis.dart           # quad + confidence + luma/glare/sharpness stats
│   │   ├── fc_scan_hint.dart                # what to tell the user, by priority
│   │   └── fc_scan_result.dart              # FcScanResult, FcScannedPage, FcPageSide, FcCaptureOrigin
│   ├── repositories/
│   │   ├── fc_document_detector.dart        # abstract: analyse(frame), analyseStill(path)
│   │   └── fc_scan_repository.dart          # abstract: processPage(still, quad, filter, config)
│   └── usecases/
│       └── fc_evaluate_frame.dart           # quality rules + stability → hint / ready (pure, unit-tested)
├── data/
│   ├── datasources/
│   │   ├── fc_scan_engine_data_source.dart  # abstract: scan(config) → raw pages
│   │   ├── fc_native_scan_engine.dart       # cunning_document_scanner (ML Kit / VisionKit)
│   │   ├── fc_scan_camera_data_source.dart  # abstract: init, frames, takePicture, torch, focus, zoom, dispose (inApp)
│   │   ├── fc_plugin_scan_camera_data_source.dart   # `camera` plugin
│   │   ├── fc_edge_document_detector.dart   # isolate pipeline from §5 (implements FcDocumentDetector)
│   │   ├── fc_mock_document_detector.dart
│   │   ├── fc_motion_data_source.dart       # abstract + sensors_plus impl; absent sensor = "always stable"
│   │   └── fc_page_processor.dart           # isolate: orient → warp → filter → encode
│   ├── models/
│   │   ├── fc_luma_frame_model.dart         # CameraImage → Y plane + rotation (parsing lives here)
│   │   └── fc_frame_analysis_model.dart     # isolate message ⇄ entity
│   └── repositories/
│       └── fc_scan_repository_impl.dart     # processor → compressor → EXIF; exceptions → failures
└── presentation/
    ├── cubits/
    │   ├── fc_scan_session/                 # step machine: camera → crop & filter → processing → done; pages
    │   ├── fc_scan_camera/                  # camera lifecycle + live analysis + auto-capture phase
    │   └── fc_scan_crop/                    # corners, active handle, rotation, filter
    ├── pages/
    │   └── fc_scanner_page.dart             # providers + AnimatedSwitcher over session steps
    └── widgets/
        ├── fc_scan_viewfinder.dart          # preview, RepaintBoundary, pinch zoom, tap to focus
        ├── fc_quad_overlay.dart             # boundary painter fed by a ValueListenable
        ├── fc_guide_frame.dart              # preset-aspect dashed frame
        ├── fc_scan_hint_pill.dart
        ├── fc_shutter_button.dart           # with hold ring
        ├── fc_scan_controls.dart            # gallery · shutter · auto toggle · step label
        ├── fc_corner_editor.dart            # handles, loupe, convexity guard
        ├── fc_filter_strip.dart
        ├── fc_pages_tray.dart
        └── fc_scan_processing_view.dart
```

Shared UI it introduces: `lib/src/presentation/theme/fc_theme.dart` (`ThemeExtension`, host first,
fallback from `ColorScheme`). Scanner widgets stay inside the feature until a second feature needs
them (e.g. the shutter button would move to `atoms/` when `capture` gets a custom camera).

No new `FcCameraFailure` variants: the scanner reports through `CameraFailure`,
`ImageProcessingFailure`, `PermissionFailure`, `StorageFailure` and `CancelledFailure`, so host apps'
exhaustive `switch`es keep compiling.

---

## 7. State

All sealed, Equatable, one folder per cubit.

```dart
// fc_scan_session
sealed class FcScanSessionState            // which step the page shows
  FcScanSessionCapturing(pages, side)      //   camera step for `side`
  FcScanSessionCropping(pages, still)      //   Crop & filter step on the captured still
  FcScanSessionProcessing(pages, stage)    //   flatten → enhance → compress
  FcScanSessionReviewing(pages)            //   tray, for front/back and multi-page
  FcScanSessionCompleted(result)
  FcScanSessionFailed(failure)

// fc_scan_camera
sealed class FcScanCameraState
  FcScanCameraStarting()
  FcScanCameraLive(torchOn, autoEnabled, phase: searching | holding(startedAt) , hint)
  FcScanCameraCapturing()
  FcScanCameraPaused()                     //   app backgrounded, camera released
  FcScanCameraError(failure)

// fc_scan_crop
sealed class FcScanCropState
  FcScanCropLoading()                      //   decoding still + detecting
  FcScanCropEditing(quad, detectedQuad, rotation, filter, activeHandle)
```

The live quad (8–12 updates/s) goes to the overlay through a `ValueListenable<FcQuad?>` owned by the
camera cubit, so only the painter repaints. Cubit states change only when the phase or hint changes.

---

## 8. Fintech and KYC features

| Need | How |
|---|---|
| Aadhaar / PAN / DL / bank card | `FcDocumentType.idCard` (ID-1, 85.6 × 54 mm, 1.586): guide frame, aspect check, output locked to card ratio |
| Passport page | `FcDocumentType.passport` (ID-3, 125 × 88 mm) |
| Front and back | `FcScanMode.frontAndBack`, labelled pages, tray with per-side retake |
| Readable for OCR / manual review | sharpness and glare gates before capture; `minOutputLongSide`; `auto` filter tuned for text |
| Live capture only (anti-fraud) | `allowGallery: false`; `origin` on every page; detection `confidence` |
| Upload size limits | `maxBytes` per page through the existing compressor |
| Audit trail | who/when/where in EXIF through the existing pipeline; no visible stamp on documents by default |
| Privacy | files in app-private temp dir, never the gallery; intermediates deleted after processing or cancel |
| Masking / OCR hooks | `FcScanConfig.postProcessor`: async hook per page, so the host can mask the Aadhaar number or run OCR before the result is returned |
| Bad light in the field | torch toggle, plus a "too dark" hint with a one-tap torch shortcut |
| Accessibility | hints announced to screen readers, haptic on lock and capture, 48 dp targets, works at 2× text |

Not in scope (host responsibility, documented): `FLAG_SECURE` / screenshot blocking, OCR itself,
liveness and face match.

---

## 9. From the reference implementation

Reference: `sarvagram_dev/lib/src/presentation/organisms/document_scanner`, read in full.

**Kept (good ideas):**
- custom camera with document border hint, torch, pinch zoom, level indicator from the accelerometer
- corner **and** edge-midpoint handles on the crop screen
- perspective warp off the UI isolate
- filter set (original, grayscale, enhanced, B&W, magic) with live thumbnails
- the strategy/fallback idea → becomes the `FcDocumentDetector` / data source abstractions

**Improved or fixed:**

| Reference behaviour | Problem | Scanner design |
|---|---|---|
| No edge detection; crop starts at full image | user drags 4 corners every time | live detection + handles start on the detected quad |
| No auto-capture | — | stability-gated auto-capture, configurable hold |
| Filter preview uses `ColorFilter` matrices; export uses different `img.contrast` calls (`enhanced` preview is plain grayscale) | saved image ≠ what the user picked | one function per filter, run on a downscaled copy for preview and on the full image for export |
| `img.decodeImage(bytes)!` | crash on a corrupt or unsupported file | decode failure → `ImageProcessingFailure` with Retake |
| EXIF orientation not baked before warp | rotated or sideways output on some devices | `bakeOrientation` first, then warp |
| Output path via `replaceAll('.jpg', ...)` | misses `.JPG`/`.HEIC`; PNG data written as `.png` but JPEG-encoded | new file in app temp dir, always `.jpg` |
| Filter save has no error path | spinner forever on failure | sealed failed state with recovery |
| Accelerometer `setState` on the whole screen at UI rate | full-screen rebuilds ~60/s | `ValueListenable` drives only the level painter |
| Crop corners can cross | self-intersecting quad → garbage warp | convexity guard rejects the move; min-area check |
| Per-pixel `getPixel` warp on the full 12 MP image | slow (seconds) on low-end phones | warp straight to the output size (capped long side), bilinear, in an isolate |
| Hard-coded colours and strings | ignores host brand; not translatable | `FcTheme` + `FcScanStrings` |
| `flutter_doc_scanner` (native) as primary with in-app fallback | 0.0.x package; needed `file://` / `content://` path workarounds; open Android *File not found* crash (#64) | `cunning_document_scanner` (same Google/Apple engines, maintained, no such issues open) behind `FcScanEngine`; in-app engine opt-in, see §12 |
| Temp files never deleted | storage creep on field devices | intermediates cleaned on success, cancel and dispose |

---

## 10. Performance budget

| Item | Target |
|---|---|
| Preview | 60 fps; overlay in its own `RepaintBoundary` |
| Detection | ≤ 25 ms per frame on a mid-range 2021 Android, 8–12 per second, never on the UI isolate |
| Rebuilds during live scan | only the overlay painter and the ring animation; no page rebuilds |
| Capture → Crop & filter screen | < 600 ms (still detection on a downscaled copy) |
| Filter preview (all thumbnails) | < 300 ms, cached per filter |
| Process one page | < 1.5 s at 2400 px long side, including compression |
| Memory | full-resolution still decoded once, in the isolate; thumbnails via `cacheWidth` |

Measured in the example app with DevTools before the phase is closed.

---

## 11. Edge cases handled

- **App backgrounded / phone call:** camera released on `inactive`, re-initialised on `resume`
  (the `camera` plugin requires this; skipping it is the most common camera crash).
- **Permission revoked while backgrounded:** re-checked on resume → permission state, not a crash.
- **Camera busy or missing:** `CameraFailure` with *Try again*.
- **Detector isolate dies:** auto-capture switches off, manual capture keeps working, hint *Tap to
  capture*.
- **No document found on the still:** Crop & filter starts at an inset full-frame quad. Never blocks.
- **Degenerate quad** (tiny, concave, crossing): rejected in detection and in the editor.
- **Double tap / auto and manual at the same moment:** one capture in flight, the rest ignored.
- **Cancel during processing:** result discarded, files deleted, `CancelledFailure` returned.
- **No accelerometer/gyroscope:** treated as level and steady; image-based stability still applies.
- **Very large gallery images, HEIC, PNG:** decoded with downscale, always re-encoded to JPEG.
- **Torch left on:** turned off on capture, pause and dispose.
- **Widget disposed mid-await:** `safeEmit`, `context.mounted` checks, isolate and stream subscriptions
  closed in `close()`.

---

## 12. Engine and package decision

Researched on 2026-10-01 from pub.dev, the GitHub trackers and Google's ML Kit docs. Nothing below
is assumed.

### What each candidate actually is

| Package | Version | Android | iOS | Health | Verdict |
|---|---|---|---|---|---|
| `google_ml_kit` | 0.23.1 | umbrella of **all** ML Kit plugins | partial | its own README says don't use it in production: it "significantly increases the size of your app" | ❌ rejected |
| `google_mlkit_document_scanner` | 0.6.1 | ML Kit Document Scanner | **not available** | verified publisher, 70 likes | ❌ Android only |
| `flutter_doc_scanner` | 0.0.21 | ML Kit Document Scanner | VisionKit | 0.0.x, 18 open issues incl. Android *File not found* (#64), iOS auto-correction bug (#50) | ❌ less stable |
| `cunning_document_scanner` | 3.0.3 | ML Kit Document Scanner, **own fallback** when Play services are missing | VisionKit | 270 likes, 2 open issues (both minor iOS), active: recent fixes for duplicate files on disk, scans leaking into Android Auto Backup, large-image memory | ✅ **chosen** |
| `opencv_dart` (for a custom detector) | 2.2.2 | yes | yes | needs Dart 3.10 / Flutter 3.38 (we support 3.35), ships native OpenCV binaries | ❌ too heavy for one feature |
| `camera` (for the in-app engine) | 0.12.1 | yes | yes | flutter.dev, frame streaming on both | ✅ for `inApp` engine only |

### What the native scanners can't do

Checked against ML Kit's docs and the plugin APIs:

- The scanner is **Google's / Apple's own full-screen UI**. Configurable: page limit, gallery
  import on/off, scanner mode (base / filters / full), iOS default filter. Nothing else.
- **Auto-capture timing can't be set**, and the app gets no live frames.
- No ID-card guide frame, no aspect check, no quality hints, no host theme (iOS colours fixed).
- ML Kit needs Google Play services and **≥ 1.7 GB RAM** (else `UNSUPPORTED`). `cunning` falls back to
  its own manual-crop scanner in that case.
- Output is capped at 2048 px long side by `cunning` (enough for ID cards and A4 at KYC quality).

### Decision: two engines, shipped in order of risk

```
                         FcScanEngine (data source contract)
                    ┌───────────────────┴───────────────────┐
             native  (default, v1)                     inApp  (opt-in, after spike)
   cunning_document_scanner                      camera + pure-Dart detector (§5)
   ML Kit / VisionKit / fallback                 our UI: 2 s hold, guide frame, hints, theme
   proven detection, ~0 MB, few bugs             full control, our own code to maintain
                    └───────────────────┬───────────────────┘
                     same post-processing in our package
         Crop & filter (optional) → compress to maxBytes → EXIF → FcScanResult
```

1. **v1 ships the `native` engine.** Best edge detection available (Google's and Apple's models),
   near-zero size cost, the most stable package of the four. Our package adds permission handling,
   the size budget, EXIF metadata, cleanup, `FcResult` and `FcScanResult`, plus `editDocument()`
   with our own Crop & filter step.
2. **The `inApp` engine is built only after a spike passes.** It's the only way to get the
   configurable 2 s hold, the ID guide frame and quality hints. Spike exit criteria, measured on a
   low-end and a mid-range Android plus one iPhone:
   - quad found on ≥ 90 % of a fixture set, including white paper on a light table and ID cards on
     patterned cloth
   - ≤ 25 ms per detection on the low-end device, no dropped preview frames
   - a stable lock within 1 s of the document being held still
3. **If the spike fails, nothing is rolled back.** Nothing shipped depends on it: `native` stays the
   engine and the 2 s hold stays unavailable until a better detector exists.

That's the guard against the "assumed it would work, then had to roll back" trap: the proven engine
ships first, the risky one is gated by measured criteria.

### Platform impact

| Item | Impact |
|---|---|
| Android `minSdk` | **24** (required by both `cunning_document_scanner` 3.x and `camera` 0.12). The README currently says 23: a CHANGELOG-noted bump, matching Flutter's own default |
| Android permissions | ML Kit uses Play services' camera permission. The fallback scanner and `inApp` use `CAMERA`, which hosts already declare. `camera` merges `RECORD_AUDIO`: strip it (already documented) |
| iOS | 13+, `NSCameraUsageDescription` (already required) |
| App size | `native`: ML Kit models live in Play services, ~0 MB. `inApp`: `camera` + `image` + `sensors_plus`, no native CV libraries |
| AGP | `cunning` builds with AGP < 9 (checked in its Gradle file), compileSdk 34, Java 17; `camera` to be verified on AGP 8 in the 7a build before pinning |
| Runtime deps | `cunning_document_scanner` 3.x has no Dart dependencies besides Flutter, so no clash with our pinned `permission_handler` 12.x |

No go_router. No OpenCV. No native code in our package.

---

## 13. Decisions (resolved 2026-10-01)

| Question | Decision |
|---|---|
| Engine | **Platform scanner only**, via `cunning_document_scanner` ^3.0.3. No own camera or detector: proven code over new code to maintain |
| Auto-capture, crop, filters | Provided by ML Kit / VisionKit inside the scanner |
| Configurable hold, ID guide overlay, themed camera UI | Not possible: the scanner is a separate native screen that Flutter can't draw over. A tips sheet shown *before* the scanner is the possible follow-up |
| Setup | One `FcCameraKit.instance.init(scan: FcScanOptions(...))` for all features |
| Entry points | `FcCameraKit.instance.scan(context)` (extension `FcCameraKitScan`) and `FcScannerPage` with `onCompleted` / `onCancelled` / `onFailed` |
| `editDocument()` | Not built. Gallery import inside the scanner (`FcScanSource.gallery` / `cameraAndGallery`) covers existing images with the platform's own crop |
| Rejected packages | `google_ml_kit`, `google_mlkit_document_scanner`, `flutter_doc_scanner`, `opencv_dart`, `camera` (reasons in §12) |

---

## 14. Delivery plan

| Step | Scope | Status |
|---|---|---|
| 1 | `FcScanOptions` in `init()`, `scan()` extension, native engine, repository (compress → EXIF → app dir, cleanup), `FcScanCubit`, `FcScannerPage`, exports | ✅ done |
| 2 | Example app: **Scan** button, one call, scanned pages strip | ✅ done |
| 3 | Repository tests, iOS device check, README platform section (minSdk 24), CHANGELOG | next |

---

Sources: [cunning_document_scanner](https://pub.dev/packages/cunning_document_scanner) ·
[its changelog](https://pub.dev/packages/cunning_document_scanner/changelog) ·
[its issues](https://github.com/jachzen/cunning_document_scanner/issues) ·
[flutter_doc_scanner](https://pub.dev/packages/flutter_doc_scanner) ·
[its issues](https://github.com/shirsh94/flutter_doc_scanner/issues) ·
[google_mlkit_document_scanner](https://pub.dev/packages/google_mlkit_document_scanner) ·
[google_ml_kit](https://pub.dev/packages/google_ml_kit) ·
[ML Kit Document Scanner](https://developers.google.com/ml-kit/vision/doc-scanner) ·
[ML Kit on Android](https://developers.google.com/ml-kit/vision/doc-scanner/android) ·
[camera](https://pub.dev/packages/camera) · [opencv_dart](https://pub.dev/packages/opencv_dart)
