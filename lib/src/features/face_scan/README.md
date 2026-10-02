# Feature: Face Scan (`face_scan`)

> Status: **Phase 1 (offline) implemented**, tests green, awaiting the device check (step F5).
> **Phase 2 (online verification)** is designed below and starts after Phase 1 passes on devices.
> Sections marked *(Phase 2)* describe what comes later; Phase 1 leaves room for them (§14).

Open the front camera, guide the user until one face is centred, confirm a live person with a
**blink**, then let them take the selfie. The circle around the face turns **red → green** and the
camera button enables only when green. Then:

- **Offline:** the photo and its data come straight back.
- **Online:** the same screen shows **Verifying… → Approved / Rejected / Error** while the host's
  API decides, then the photo, its data and the API's answer come back.

One call in, one result out, like `capture()` and `scan()`.

```dart
final result = await FcCameraKit.instance.scanFace(context);              // offline
final result = await FcCameraKit.instance.scanFace(context,
    verify: KycFaceVerifyRequest(userId: 'EMP-2291'));                   // online
```

---

## Contents

1. [Using it](#1-using-it)
2. [Screens (sketches)](#2-screens-sketches)
3. [Flow](#3-flow)
4. [Liveness: what green means](#4-liveness-what-green-means)
5. [Online verification](#5-online-verification)
6. [Architecture](#6-architecture)
7. [State](#7-state)
8. [Camera handling checklist](#8-camera-handling-checklist)
9. [Performance budget](#9-performance-budget)
10. [Edge cases handled](#10-edge-cases-handled)
11. [Security and privacy](#11-security-and-privacy)
12. [Dependencies and platform impact](#12-dependencies-and-platform-impact)
13. [Decisions](#13-decisions)
14. [Delivery plan](#14-delivery-plan)

---

## 1. Using it

### Setup: the same `init()` as every feature

```dart
await FcCameraKit.instance.init(
  user: (id: 'EMP-2291', name: 'Asha Verma'),
  maxBytes: 1024 * 1024,                    // shared with capture() and scan()
  placement: StampPlacement.extend,         // shared stamp settings, as for capture() and scan()
  faceScan: const FcFaceScanOptions(
    blinks: 1,                              // blinks needed before green
    embedMetadata: true,                    // who / when / where in EXIF
    stamp: false,                           // burn who / when / where onto the selfie; off by default
    verifyTimeout: Duration(seconds: 30),   // Phase 2
  ),
);
```

### Stamping (same as `scan()`)

Off by default, because a selfie for identity is usually kept clean. Turn it on in
`init(faceScan:)` or per call, with **the same parameters as `capture()` and `scan()`**:

```dart
FcCameraKit.instance.scanFace(
  context,
  stamp: true,
  placement: StampPlacement.overlay,        // null → init()
  dateFormat: 'dd MMM yyyy, hh:mm a',       // null → init()
  style: const FcStampStyle(),
);
```

- **Contents:** user, time, location and (if `includeDeviceInStamp`) device, from `init()`.
- **Location:** `requireLocation` applies, as in `scan()`. If the stamp or EXIF needs a location,
  the location permission is asked for before the camera opens, and the fix is fetched while the
  user is framing their face, so it's usually ready by capture.
- **Metadata independent of the stamp:** `embedMetadata: false` with `stamp: true` stamps the
  photo but writes no EXIF.
- **Steps on screen:** while processing, the same step list as the scanner is shown under the
  ring: *Adding the stamp* (only when stamping) → *Compressing* → *Writing metadata* (only when
  embedding). Phase 2 adds *Verifying*.

`scanFace()` lives in `extension FcCameraKitFaceScan on FcCameraKit`
(`features/face_scan/fc_camera_kit_face_scan.dart`), like `scan()`. Per-call arguments override `init()`.

### a) Offline: get the selfie and its data

```dart
final result = await FcCameraKit.instance.scanFace(context);

result.when(
  success: (face) => profile.saveSelfie(face.file),
  failure: (failure) => switch (failure) {
    CancelledFailure() => null,
    PermissionFailure() => showSettingsHint(),
    _ => showError(),
  },
);
```

### b) Online: the host describes the request, the kit sends it *(Phase 2)*

Modelled on the `APIRouter` pattern: one small class per endpoint holding `path`, query params,
headers and body.

```dart
final class KycFaceVerifyRequest extends FcFaceVerifyRequest {
  const KycFaceVerifyRequest({required this.userId});

  final String userId;

  @override
  String get baseUrl => Env.apiBaseUrl;

  @override
  String get path => '/kyc/$userId/face-verify/';

  @override
  Map<String, String> get headers => {'Authorization': 'Bearer ${Session.token}'};

  @override
  Map<String, String> get queryParams => {'source': 'mobile'};

  @override
  FcRequestBody body(FcFaceCapture capture) => FcMultipartBody(
    file: capture.file,
    fileField: 'selfie',
    fields: {'captured_at': capture.capturedAt.toIso8601String()},
  );

  @override
  FcFaceVerdict parse(FcHttpResponse response) => response.json['match'] == true
      ? FcFaceVerdict.approved(data: response.json)
      : FcFaceVerdict.rejected(message: response.json['reason'] as String?);
}

final result = await FcCameraKit.instance.scanFace(
  context,
  verify: const KycFaceVerifyRequest(userId: 'EMP-2291'),
);
// result.valueOrNull?.verdict → approved, with the API's data
```

### c) Online with the app's own HTTP client *(Phase 2)*

Fintech apps usually send every request through one Dio client (token refresh, interceptors,
certificate pinning). A request sent by the kit's own client would skip all of that, so those apps
implement the verifier themselves:

```dart
final class KycFaceVerifier implements FcFaceVerifier {
  KycFaceVerifier(this._api);
  final KycApi _api;

  @override
  Future<FcFaceVerdict> verify(FcFaceCapture capture) async {
    final response = await _api.verifyFace(capture.file);   // their Dio, their auth
    return response.match
        ? FcFaceVerdict.approved(data: response.toJson())
        : FcFaceVerdict.rejected(message: response.reason);
  }
}

FcCameraKit.instance.scanFace(context, verifier: KycFaceVerifier(api));
```

Pass `verify:` **or** `verifier:`, never both. Neither means offline.

### d) As a screen in the host's own navigation

```dart
GoRoute(
  path: 'kyc/selfie',
  builder: (context, state) => FcFaceScanPage(
    onCompleted: (face) => context.read<KycCubit>().attachSelfie(face),
    onCancelled: () => context.pop(),
  ),
);
```

*(Phase 2)* adds `verify:` / `verifier:` to `FcFaceScanPage`, the same as `scanFace()`.

Same contract as `FcScannerPage`: exactly one callback fires, and the page closes itself through
`FcNavigator`.

### What comes back

```dart
final class FcFaceResult extends Equatable {
  final XFile file;                    // the selfie: see "Which image" below
  final int width, height, sizeBytes;
  final DateTime capturedAt;
  final bool livenessPassed;           // the blink check passed for this capture
  final FcFaceBox face;                // normalised face box in the photo
  final FcHeadPose pose;               // yaw / pitch / roll when captured
  final FcPhotoMetadata? metadata;     // who / when / where, when embedMetadata is on
  final FcFaceVerdict? verdict;        // Phase 2, online only: approved + the API's data
  final bool stamped;                  // the stamp is burned into `file`
}
```

**Which image:**
- `file` is the selfie as the camera took it: front lens, **unmirrored** (as others see you, not as
  a mirror), upright, JPEG, compressed under `maxBytes`, in the app-private directory, never the
  gallery.
- With `stamp: true` the who / when / where stamp is burned in, and `stamped` is `true`.
- With `embedMetadata: true` the who / when / where (plus "Used by") is in its EXIF.
- *(Phase 2)* The API always receives the **clean** selfie, never the stamped one: a stamp could
  cover part of the face and spoil matching. When both `stamp` and `verify` are on, the clean
  selfie is verified first and the stamped copy is made after approval. That's the one case where
  the work is done twice.

---

## 2. Screens (sketches)

One screen for the whole flow. The camera stays visible behind every state, so verification reads
as work on *this* selfie, not a new screen.

### 2.1 Live: finding the face (red)

```
┌─────────────────────────────────────┐
│  ✕                                  │
│                                     │
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │  outside the circle dimmed
│ ░░░░░░░ ╭───────────────╮ ░░░░░░░░░ │
│ ░░░░░ ╱  ●●●   red ring  ╲ ░░░░░░░░ │  ring = state colour, animated 200 ms
│ ░░░░ │     ( camera )     │ ░░░░░░░ │
│ ░░░░ │      preview       │ ░░░░░░░ │  preview mirrored, like a mirror
│ ░░░░░ ╲                  ╱ ░░░░░░░░ │
│ ░░░░░░░ ╰───────────────╯ ░░░░░░░░░ │
│                                     │
│     Position your face in the circle│  one hint at a time
│                                     │
│               ( 📷 )                │  disabled: dimmed, not tappable
└─────────────────────────────────────┘
```

Hints, highest priority first: *Allow camera* → *Too dark* → *Only one face please* →
*Position your face in the circle* → *Move closer* / *Move back* → *Look straight at the camera* →
*Blink your eyes* → *Hold still, ready*.

### 2.2 Live: blink detected (green)

```
│ ░░░░░░░ ╭───────────────╮ ░░░░░░░░░ │
│ ░░░░░ ╱      green ring  ╲ ░░░░░░░░ │  ring fills green with a short sweep
│ ░░░░ │      ( face )      │ ░░░░░░░ │  + light haptic, + screen-reader
│ ░░░░░ ╲                  ╱ ░░░░░░░░ │    announcement "Ready"
│ ░░░░░░░ ╰───────────────╯ ░░░░░░░░░ │
│          Hold still, ready          │
│               ( 📷 )                │  enabled: full colour, 72 dp
```

Green lasts only while **the same face** stays valid. If the face leaves, moves out of the circle,
turns away, or a different face appears, the ring goes red and a new blink is needed.

### 2.3 Processing (after the shutter, same screen)

```
│ ░░░░░░░ ╭───────────────╮ ░░░░░░░░░ │
│ ░░░░░ ╱   ◜ progress arc   ╲ ░░░░░░ │  ring becomes a progress arc
│ ░░░░ │   frozen selfie    │ ░░░░░░░ │  the photo just taken
│ ░░░░░ ╲                  ╱ ░░░░░░░░ │
│        Preparing your photo         │
│          Keep the app open          │
│        ✓ Adding the stamp           │  only when stamp: true
│        ◌ Compressing                │
│        ○ Writing metadata           │  only when embedMetadata: true
```

Offline, it ends with a brief ✓ on the ring (~400 ms), then returns.

### 2.4 Verifying (online, same screen) *(Phase 2)*

```
│ ░░░░░░░ ╭───────────────╮ ░░░░░░░░░ │
│ ░░░░░ ╱   ◜ spinning arc  ╲ ░░░░░░░ │  ring becomes a progress arc
│ ░░░░ │   frozen selfie    │ ░░░░░░░ │  the captured photo, not the live feed
│ ░░░░░ ╲                  ╱ ░░░░░░░░ │
│          Verifying your face…       │
│          Keep the app open          │
```

### 2.5 Result (online) *(Phase 2)*

```
 Approved                     Rejected                       Error (network / server)
 ╭──────────╮                 ╭──────────╮                   ╭──────────╮
 │    ✓     │ green ring      │    ✕     │ red ring          │    !     │ amber ring
 ╰──────────╯                 ╰──────────╯                   ╰──────────╯
 Verified                     Face not matched               Couldn't reach the server
 (returns after ~700 ms)      <API message>                  [ Try again ]  (same selfie)
                              [ Retake ]  (back to live)      Close
                               Close
```

- **Rejected** offers **Retake**: a new selfie is the only thing that can change the answer.
- **Error** offers **Try again** with the **same** selfie: the user did nothing wrong, so they
  don't have to blink again.
- **Close** on either ends the flow (`onCancelled` / `CancelledFailure`, or `onFailed` with the
  failure when the host asked for it).

---

## 3. Flow

```
scanFace(context)  ── init() missing ───────────────────────────────▶ ConfigurationFailure
   │
   ▼
FcPermissionGate.ensure({camera})  ── denied ───────────────────────▶ PermissionFailure
   │
   ▼
FcFaceScanPage   (one route via FcNavigator; every step below is on this screen)
   │
   ├─ Starting ── camera busy / missing ──▶ error view [Try again] [Close]
   ▼
   Live (red) ⇄ Live (green)      ← face detection ~12/s, blink tracker
   │  tap 📷 (green only)
   ▼
   Capturing ─▶ Processing ([stamp] → compress → [EXIF]; steps shown under the ring)
   │
   ├─ offline ───────────────────────────────────────────────────────▶ FcFaceResult
   └─ online ─▶ Verifying ─┬─ approved ─▶ ✓ (700 ms) ────────────────▶ FcFaceResult + verdict
                           ├─ rejected ─▶ [Retake] → Live   [Close] ─▶ VerificationFailure
                           └─ error ────▶ [Try again] → Verifying
                                          [Close] ───────────────────▶ VerificationFailure
```

The host gets control back exactly once, at the end, or on `pushAndRemoveUntil` / back press as
`CancelledFailure`, the same guarantee `scan()` has through `FcNavigator`.

---

## 4. Liveness: what green means

**Green = exactly one face, centred, close enough, looking straight, that has blinked.**

| Check | Rule (defaults, tunable in `FcFaceScanOptions`) | Hint when failing |
|---|---|---|
| Light | mean luminance of a sampled frame ≥ 50 | *Too dark* |
| One face | exactly 1 face detected | *Only one face please* |
| Centred | face centre inside the middle 40 % of the circle | *Position your face in the circle* |
| Size | face height 35 %–80 % of the circle | *Move closer* / *Move back* |
| Straight | \|yaw\| ≤ 12°, \|roll\| ≤ 10°, \|pitch\| ≤ 15° | *Look straight at the camera* |
| Blink | eyes open (> 0.7) → closed (< 0.2) → open (> 0.7) within 1.2 s, same tracking id | *Blink your eyes* |

- **Blink tracker:** a small pure-Dart state machine keyed by ML Kit's tracking id. A different id
  (a photo swapped in, another person) resets it. One missed frame doesn't reset it, so a real
  blink isn't lost to a dropped frame.
- **`blinks`:** how many blinks are needed (default 1). Two makes a replayed short clip less likely
  to pass.

**What this does and doesn't prove:** it stops a printed photo, a still on a screen, and casual
misuse. It **does not** stop a replayed video of a blinking person or a deepfake. That needs
certified anti-spoofing (§13). For KYC the host backend makes the final decision; that's what the
online verification is for.

---

## 5. Online verification *(Phase 2)*

### The request contract

```dart
abstract class FcFaceVerifyRequest {
  const FcFaceVerifyRequest();

  String get baseUrl;
  String get path;
  FcHttpMethod get method => FcHttpMethod.post;
  Map<String, String> get headers => const {};
  Map<String, String> get queryParams => const {};
  Duration? get timeout => null;              // null → options.verifyTimeout

  FcRequestBody body(FcFaceCapture capture);
  FcFaceVerdict parse(FcHttpResponse response);
}

sealed class FcRequestBody {}
final class FcJsonBody extends FcRequestBody { ... }      // image as base64 under a field name
final class FcMultipartBody extends FcRequestBody { ... } // image as a file part + text fields
```

- `parse` sees every response, including 4xx, so the host decides what a 422 means. Anything it
  can't make sense of becomes a `VerificationFailure`.
- `FcFaceCapture` carries everything the request might send: file, capturedAt, pose, face box and
  metadata.

### Who sends it

| Passed | Sent by | When to use |
|---|---|---|
| `verify: FcFaceVerifyRequest` | `FcHttpFaceVerifier`, using the `http` package | Simple endpoints, quick integration |
| `verifier: FcFaceVerifier` | The host's own code | Apps with a Dio client, token refresh, interceptors or SSL pinning |

Both end in an `FcFaceVerdict`: `approved(data)` or `rejected(message, data)`.

### Errors

| Situation | Shown | Returned on Close |
|---|---|---|
| No network / timeout | *Couldn't reach the server* · **Try again** | `VerificationFailure(network)` |
| 5xx or unparseable | *Something went wrong on our side* · **Try again** | `VerificationFailure(server, statusCode)` |
| `rejected` verdict | *Face not matched* or the API's message · **Retake** | `VerificationFailure(rejected, data)` |

The request is cancelled if the page closes mid-flight, so no response arrives into a closed
screen.

---

## 6. Architecture

Two sibling features. The dependency runs **one way: `face_scan` → `camera`**.

```
lib/src/features/
├── camera/          live camera + the face-detection frame UI. Knows nothing about faces' rules.
├── face_scan/       face detection, blink liveness, verification, scanFace(). Decides the status.
└── scanner/         document scanner (unchanged)
```

- `camera` shows the camera, the face frame, the ring, the hint and the shutter. All of it is
  driven by one small value, `FcFaceFrameStatus` (ring tone, hint text, shutter enabled, frozen
  photo). It hands each camera frame to whoever is listening.
- `face_scan` listens to those frames, runs ML Kit and the blink rules, and turns its states into an
  `FcFaceFrameStatus`.
- The later full camera journey (photo, video, zoom, flash) grows inside `camera` and reuses the
  same live camera and widgets, without touching `face_scan`.

### `features/camera/`

```
camera/
├── domain/
│   └── entities/
│       ├── fc_camera_frame.dart           # bytes + size + rotation + format, plugin-free
│       └── fc_face_frame_status.dart      # what the face frame shows: tone, hint, shutter, frozen photo
├── data/
│   └── datasources/
│       ├── fc_live_camera.dart            # abstract: open(lens), frames, takePicture, pause, resume, close
│       └── fc_plugin_live_camera.dart     # on the `camera` plugin
└── presentation/
    ├── cubits/
    │   └── fc_camera/                     # open / ready / paused / error; app lifecycle; frame stream
    │       ├── fc_camera_cubit.dart
    │       └── fc_camera_state.dart
    ├── pages/
    │   └── fc_face_camera_page.dart       # the face-detection frame screen (not a general camera)
    └── widgets/
        ├── fc_camera_preview.dart         # cover-fit, mirrored for the front lens
        ├── fc_face_viewport.dart          # preview clipped to the circle + dimmed outside
        ├── fc_face_ring.dart              # ring painter: tone, sweep, progress arc
        ├── fc_face_hint_text.dart         # one hint, cross-faded
        └── fc_camera_shutter.dart         # 72 dp button, enabled from the status
```

`FcFaceCameraPage` takes:
- a `ValueListenable<FcFaceFrameStatus>` that drives the ring, hint, shutter and frozen photo
- `onFrame(FcCameraFrame)`, called for each analysis frame with one in flight at a time
- `onShutter(XFile)` and `onClose()`

### `features/face_scan/`

```
face_scan/
├── README.md                              # this file
├── fc_camera_kit_face_scan.dart           # extension FcCameraKitFaceScan on FcCameraKit { scanFace() }
├── domain/
│   ├── entities/
│   │   ├── fc_face_observation.dart       # one face in one frame: box, eyes, pose, tracking id
│   │   ├── fc_face_hint.dart              # what to tell the user, by priority
│   │   ├── fc_face_capture.dart           # the taken selfie + what was known at that moment
│   │   ├── fc_face_result.dart            # FcFaceResult, FcFaceBox, FcHeadPose
│   │   ├── fc_face_verdict.dart           # approved / rejected + data
│   │   └── fc_face_verify_request.dart    # public request contract, body types, http types
│   ├── repositories/
│   │   ├── fc_face_detector.dart          # abstract: detect(frame) → observations
│   │   └── fc_face_verifier.dart          # public abstract: verify(capture) → verdict
│   └── usecases/
│       ├── fc_evaluate_face.dart          # observations → hint / ready (pure, unit-tested)
│       └── fc_blink_tracker.dart          # open → closed → open per tracking id (pure)
├── data/
│   ├── datasources/
│   │   ├── fc_mlkit_face_detector.dart    # frame → InputImage → ML Kit; rotation lives here
│   │   └── fc_http_face_verifier.dart     # sends an FcFaceVerifyRequest with `http`
│   ├── models/
│   │   └── fc_face_observation_model.dart # ML Kit Face → entity (all parsing here)
│   └── repositories/
│       └── fc_face_repository_impl.dart   # compress + EXIF + save; verify; errors → failures
└── presentation/
    ├── cubits/
    │   ├── fc_face_detection/             # frames → hint / ready (red / green)
    │   └── fc_face_session/               # capture → process → verify → result
    └── pages/
        └── fc_face_scan_page.dart         # providers; maps both cubits to FcFaceFrameStatus;
                                           # renders FcFaceCameraPage; owns callbacks + closing
```

**Reused, not rewritten:**
- `FcPermissionGate` for the camera permission.
- `FcNavigator` for exactly-once return.
- The shared image pipeline in `core/image/` (stamp → compress → EXIF, with stage reporting),
  moved out of the scanner in step F0 so both features use the same code.
- `FcStepList` for the processing steps, as on the scanner's preparing screen.
- `FcCubit.safeEmit`, the exception-to-failure mapping, and `FcResult`.

**Rule note:** our skill says features don't import each other. `camera` is the agreed exception:
a shared feature that others build on, imported **one way only**. `camera` never imports
`face_scan`; a test checks that no `camera/` file imports `face_scan/`.

---

## 7. State

**Pages are stateless.** `FcFaceScanScreenCubit` owns the screen: settings, the permission
request, the camera, detection and session cubits (created after permission, closed with it), the
frame status, the ✓ timer, and the single outcome through `FcFlowReporter`. The page only renders,
shows the permission sheet when asked, plays the haptic, and closes its route when told. When the
page goes, the screen cubit reports first and then closes everything it owns.


Three cubits, so the 12-per-second detection never rebuilds the capture or verify UI, and the
reverse.

```dart
// camera: the device                     features/camera/presentation/cubits/fc_camera
sealed class FcCameraState
  FcCameraStarting()
  FcCameraReady()                         // preview live, frames flowing
  FcCameraPaused()                        // app in background, camera released
  FcCameraError(failure)                  // missing, busy, failed

// face_scan: what the camera sees        face_scan/presentation/cubits/fc_face_detection
sealed class FcFaceDetectionState
  FcFaceDetectionSearching(hint)          // red
  FcFaceDetectionReady()                  // green; emitted only when hint or ready changes

// face_scan: what happens to the selfie  face_scan/presentation/cubits/fc_face_session
sealed class FcFaceSessionState
  FcFaceSessionLive()                     // waiting for the shutter
  FcFaceSessionCapturing()
  FcFaceSessionProcessing(capture)        // compress + EXIF
  FcFaceSessionVerifying(capture)         // online only
  FcFaceSessionApproved(result)           // shown ~700 ms, then the page closes
  FcFaceSessionRejected(capture, verdict)
  FcFaceSessionVerifyError(capture, failure)
  FcFaceSessionCompleted(result)
  FcFaceSessionFailed(failure)
```

- `FcFaceScanPage` combines the detection and session states into one `FcFaceFrameStatus` (a
  `ValueNotifier`), so the camera page repaints only the ring, hint and shutter.
- The viewport (live camera or frozen selfie) and the ring are one stable widget across every
  state, like the scanner's preparing screen.

---

## 8. Camera handling checklist

Every row has a test with a fake `FcLiveCamera`, and the device matrix in §14 checks it on real
phones.

| Area | Typical bug | Handling |
|---|---|---|
| Lifecycle | Black preview or crash after a call or app switch | Release on `inactive`, reopen on `resumed` (AppLifecycleListener in `FcCameraCubit`) |
| Memory | Controller or stream alive after close; frames queueing | One `close()`: stop stream → dispose controller → close detector. One frame in flight, the rest dropped |
| Aspect ratio | Stretched or squashed preview | Cover-fit using the sensor's real ratio, flipped for portrait or landscape; the photo is shown cover-fit too, never stretched |
| Mirroring | Preview and photo disagree | Preview mirrored, photo unmirrored |
| Rotation | Faces not detected; preview sideways when the host allows landscape | Capture is locked to the **screen's** orientation (portrait, or whichever landscape side), so preview, photo and ML Kit rotation all match what the user sees |
| Face oval | A fixed circle that fits one phone | A face-shaped oval (1.3 tall : 1 wide) sized from the real screen: width-led in portrait (max half the height), beside the controls in landscape, capped on tablets. The same oval is mapped into the camera frame (cover-fit crop, front mirror) for the framing rules, so what's drawn is exactly what's judged |
| Format | Garbled or slow frames | NV21 on Android, BGRA8888 on iOS: what ML Kit reads directly, no conversion |
| Capture during stream | Fails on some Android phones | Pause the stream → take the photo → resume; a double tap captures once |
| Permission | Denied / permanently denied / revoked while away | `FcPermissionGate` before opening; re-check on resume |
| No camera / busy | Crash | `CameraFailure` with **Try again** |
| Torn down from outside | `scanFace()` never returns | `FcNavigator` + dispose-time `onCancelled`, as the scanner does |

---

## 9. Performance budget

| Item | Target | How |
|---|---|---|
| Preview | 60 fps on a 2021 mid-range Android | Native texture, never rebuilt; ring in its own `RepaintBoundary` |
| Detection | ~10–15 per second, never queued | `performanceMode: fast`, classification only, no landmarks or contours, one frame in flight |
| Red → green | < 150 ms after the blink completes | The tracker runs on each detection; the ring animates 200 ms |
| Rebuilds while live | Ring painter + hint text only | Live state emits only on hint / ready changes |
| Camera open | < 800 ms to first preview frame | Opened right after the permission gate, at `ResolutionPreset.high` |
| Capture → result (offline) | < 1 s | Compress once to `maxBytes`, EXIF after |

Measured with DevTools in the example app on the device matrix before each step is closed.

---

## 10. Edge cases handled

- No face, several faces, face half out of the circle: red with the matching hint, never green.
- Photo of a face held up: no blink, so it never goes green.
- Blink, then a different person steps in: a new tracking id resets the blink, so it goes red.
- Glasses, beards, low light: thresholds tunable; *Too dark* before anything else.
- Double tap on the shutter: one capture.
- App backgrounded mid-verify: the request continues; if the page is closed instead, the request is
  cancelled and the selfie deleted.
- Rejected → Retake: back to live with the tracker reset; the old selfie deleted.
- Network drop → Try again: same selfie resent, no new blink.
- Front camera missing (some tablets): `CameraFailure` with a clear message.
- Low-memory Android killing the app while open: documented. The flow can't return across a
  process death.

---

## 11. Security and privacy

A selfie is biometric data. The kit:

- Never saves to the gallery. The selfie goes to the app-private directory, and the host owns
  deleting it.
- Deletes intermediate files on cancel, rejection and failure.
- Never logs image bytes or request bodies, and puts no API data into failure messages beyond the
  status code.
- Doesn't enforce HTTPS: `FcHttpFaceVerifier` sends to whatever URL the host's request gives.
  The README will strongly recommend HTTPS-only for verification endpoints.
- Leaves Android Auto Backup exclusion for `app_flutter/fc_camera_kit/` to the host, as documented
  for scans.

---

## 12. Dependencies and platform impact

| Package | Why | Impact |
|---|---|---|
| `camera` | Live front-camera preview and frames | Android merges `CAMERA` and `RECORD_AUDIO` (strip the latter, as the example already does). iOS: `NSCameraUsageDescription` (already required) |
| `google_mlkit_face_detection` | Face box, eye-open probability, head pose, tracking | **iOS minimum becomes 15.5** (from 13), 64-bit only. Android minSdk 21 (we're at 24). Measure app-size impact in step F2 |
| `http` | `FcHttpFaceVerifier` | Pure Dart, no permissions |

All versions are checked for AGP 8 compatibility before pinning, and the reasons go in
`pubspec.yaml` comments, as for the existing dependencies.

---

## 13. Decisions

| Question | Decision |
|---|---|
| Camera | `camera` (flutter.dev). `camerawesome` rejected: 194 open issues, no release for 15 months, iOS crash reports |
| Face detection | `google_mlkit_face_detection`: on-device, offline, free |
| Liveness | Blink-based ("liveness lite"); the host backend makes the final call. A certified engine can replace the detector later behind `FcFaceDetector` / `FcFaceVerifier` |
| AWS Amplify | Not used: Amplify UI for Flutter has only the Authenticator component |
| Online request | Both: `FcFaceVerifyRequest` (sent by the kit) and `FcFaceVerifier` (host's own client) |
| Capture | Manual: the button enables on green. Auto-capture can be added later as an option |
| Stamp | Off by default; same parameters and steps as `scan()`; the API (Phase 2) always gets the clean selfie |
| Shared pipeline | Stamp → compress → EXIF moves from the scanner's repository to `core/image/` (F0); scanner's public names stay as aliases |
| Placement | `features/camera/` (live camera + face-frame UI) and `features/face_scan/` (face logic), siblings; `face_scan` → `camera` one way only |
| New failure | `VerificationFailure(kind: network / server / rejected, statusCode?, data?)`. This adds a variant to the sealed `FcCameraFailure`, which **breaks host exhaustive switches**; noted in the CHANGELOG (pre-1.0) |

---

## 14. Delivery plan

Two phases. Phase 2 starts only after Phase 1 is implemented, tested and checked on the device
matrix. Each step lands with tests, an example-app screen and a CHANGELOG entry; the full suite and
the example build stay green before the next step starts.

### Phase 1: offline

The user frames their face, blinks, takes the selfie, and gets back the photo with its data.

| Step | Scope | Tests |
|---|---|---|
| F0 | Move the stamp → compress → EXIF pipeline from `FcScanRepositoryImpl` into `core/image/` (with `FcStampRenderer` and `FcStampStyle`). Scanner switches to it. Public names stay (`FcScanStage` / `FcScanStamp` become aliases), so nothing breaks for host apps | Existing scanner tests unchanged and green; new pipeline tests for stage order and the stamp / EXIF on-off combinations |
| F1 | `features/camera`: `FcLiveCamera` + plugin impl, `FcCameraCubit`, preview widget; iOS 15.5, dependency pins | Lifecycle, close, pause/resume, one-frame-in-flight with a fake camera |
| F2 | `face_scan` detection: `FcFaceDetector` + ML Kit impl + model; `FcEvaluateFace` + `FcBlinkTracker` | Pure tests for every hint, blink timing, tracking-id reset; rotation table |
| F3 | Face frame UI in `camera` (`FcFaceCameraPage`, viewport, ring, hint, shutter) + `FcFaceDetectionCubit` | Cubit tests (red → green → red); shutter enabled only when green; repaint isolation; no `camera/` → `face_scan/` import |
| F4 | Session offline: capture → [stamp] → compress → [EXIF] with steps on screen → brief ✓ → `FcFaceResult`; stamp options and parameters; location fetched while framing; `scanFace()`; `FcFaceScanPage` callbacks; exports | Session cubit; stamp on/off and placement override (as the scanner tests); exactly-once return incl. stack cleared; double-tap capture |
| F5 | Example app (offline), README, CHANGELOG, **device matrix**: low-end Android, Samsung, Xiaomi/Redmi, one iPhone | Manual checklist from §8 on each device |

**Phase 1 public API:** `scanFace(context, {blinks, maxBytes, embedMetadata, stamp, placement, dateFormat, style})` and
`FcFaceScanPage(onCompleted, onCancelled, onFailed)`. No verification parameters yet.

### Phase 2: online verification

The same screen sends the selfie to the host's API and shows Verifying → Approved / Rejected /
Error before returning.

| Step | Scope | Tests |
|---|---|---|
| O1 | `FcFaceVerifyRequest` + body types + `FcHttpFaceVerifier` (`http`); `FcFaceVerdict`; `VerificationFailure` | Fake HTTP: 200 approved, 200 rejected, 4xx, 5xx, timeout, malformed body; JSON vs multipart |
| O2 | Verify step in the session: verifying / approved / rejected / error states; Retake vs Try again; cancel on close | Retry resends the same selfie; Retake resets the blink; closing mid-request cancels it and deletes the selfie |
| O3 | Outcome views on the same screen; `scanFace(verify:)` / `scanFace(verifier:)`; `FcFaceScanPage(verify:, verifier:)` | Both entry points; exactly-once return for every outcome |
| O4 | Example app (online, against a mock endpoint), README, CHANGELOG, device check | Manual: slow network, airplane mode mid-request, server error |

### Built in Phase 1 so Phase 2 only adds

Phase 2 must not rewrite Phase 1 code. These seams are what makes that true, and each is cheap
because Phase 1 uses it too:

| Seam | Built in Phase 1 as | Phase 2 adds |
|---|---|---|
| Session pipeline | An ordered list of steps (`capture → process → finish`), each returning `FcResult`; processing reports its stages to the step list | One `verify` step (clean selfie) inserted before `finish`, only when a verifier is given; with a stamp, stamping runs after approval. *Verifying* joins the step list |
| Verifier contract | `FcFaceVerifier` interface in `domain/repositories`, with no implementations | `FcHttpFaceVerifier` and the host's own implementations |
| Result | `FcFaceResult.verdict` is nullable from day one (always `null` offline) | Filled in when verified |
| Frame status | `FcFaceFrameStatus` tones: searching (red), ready (green), working (progress arc), done (✓), failed. Phase 1 already uses *working* for processing and *done* for the brief ✓ | No new tones; the outcome views read the same status |
| Outcome view | `fc_face_outcome_view` for done / failed with the action buttons as parameters | Rejected and network-error copy with Retake / Try again |
| Entry points | `scanFace()` and `FcFaceScanPage` take named parameters only | `verify:` and `verifier:` added as optional named parameters, so it's not a breaking change |
| Capture | `FcFaceCapture` carries everything a request could send: file, capturedAt, pose, face box, metadata | Nothing; requests read it as is |

The one breaking change in Phase 2 is the new `VerificationFailure` variant on the sealed
`FcCameraFailure` (host exhaustive switches must add a case). It's noted in the CHANGELOG, and
acceptable before 1.0.

**How Phase 1 stays clean while doing this:** every seam above is used in Phase 1 itself, apart
from the one `FcFaceVerifier` interface. Nothing is built "just in case" (DRY, no speculative
code), and the verify step follows open/closed: it's added, and existing steps don't change.
