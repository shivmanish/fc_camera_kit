# fc_camera_kit

Capture a photo, stamp **who / when / where** onto it, embed the same facts in
its EXIF, squeeze it under a size budget, and hand it back as an `XFile`.

Built feature-first (clean architecture), driven by Cubits, **Android and iOS
only**.

| | |
|---|---|
| Platforms | Android 6.0 (API 23)+, iOS 13+ |
| Dart / Flutter | Dart 3.9, Flutter 3.35+ |
| State management | `flutter_bloc` (Cubit) |
| Status | Phase 1 of 7 — scaffold complete |

---

## Table of contents

1. [What it does](#what-it-does)
2. [Roadmap](#roadmap)
3. [Install](#install)
4. [Platform setup](#platform-setup)
5. [Architecture](#architecture)
6. [Why `XFile` and not `File`](#why-xfile-and-not-file)
7. [Planned API](#planned-api)
8. [Development](#development)

---

## What it does

A field worker takes a photo. That photo has to carry proof of who took it,
when, and where — in a form that survives a WhatsApp forward (burned into the
pixels) *and* in a form a backend can parse (EXIF). It also has to be small
enough to upload over a weak connection.

`fc_camera_kit` is that whole pipeline behind one call:

```
capture ──▶ resolve context ──▶ stamp ──▶ write EXIF ──▶ compress to budget ──▶ XFile
           (user, time, GPS)   (pixels)   (metadata)     (≤ maxBytes)
```

Two stamp placements, selected by parameter:

| Mode | What it looks like | Trade-off |
|---|---|---|
| `StampPlacement.overlay` | Translucent footer drawn **on top of** the photo, bottom-aligned | Original aspect ratio preserved; covers part of the image |
| `StampPlacement.extend` | Canvas grown **below** the photo, text on a solid strip | Nothing is hidden; aspect ratio changes |

---

## Roadmap

The package is being built in reviewable slices. Each phase lands with tests,
docs and a working example screen before the next one starts.

| Phase | Scope | Status |
|---|---|---|
| **1** | **Package scaffold** — pubspec, strict lints, folder skeleton, error/result core, example app, native permission config | ✅ **Done** |
| 2 | **Core: config singleton** — `SgCameraKit.initialize()`, `SgUserContext`, defaults every feature reads from | ⏳ Next |
| 3 | **Core: permissions** — one gateway per permission behind a single facade | Planned |
| 4 | **Core: image pipeline** — compressor, size-cap policy, EXIF reader/writer | Planned |
| 5 | **Feature: capture** — camera and gallery sources, `CaptureCubit` | Planned |
| 6 | **Feature: stamping** — overlay / extend renderer, `StampingCubit` | Planned |
| 7 | **Feature: scanner** — live edge detection, auto-capture, perspective crop, filters, ID/KYC presets ([design](lib/src/features/scanner/README.md)) | Design |

Run the example app to see the same roadmap with live status.

---

## Install

```yaml
dependencies:
  fc_camera_kit:
    git:
      url: https://github.com/sarvagram/fc_camera_kit
      ref: v0.1.0
```

```dart
import 'package:fc_camera_kit/fc_camera_kit.dart';
```

Everything under `lib/src/` is private. If something you need is not exported
from `fc_camera_kit.dart`, open an issue rather than reaching into `src/` — it
moves without a major version bump.

---

## Platform setup

`fc_camera_kit` is a **pure Dart package**, not a plugin — it has no Android or
iOS module of its own, so it cannot contribute manifest entries or Info.plist
keys to your app. Platform setup is therefore yours. The [`example/`](example/)
app has all of it applied; copy from there if in doubt.

### What you get for free, and what you must add

| | Android | iOS |
|---|---|---|
| Camera | **Automatic** — `camera_android_camerax` merges `CAMERA` in | You must add `NSCameraUsageDescription` |
| Location | **You must add** `ACCESS_FINE_LOCATION` + `ACCESS_COARSE_LOCATION` — `geolocator_android` declares nothing | You must add `NSLocationWhenInUseUsageDescription` |
| Photo picker | **You must add** `READ_MEDIA_IMAGES` | You must add `NSPhotoLibraryUsageDescription` |

Two reasons this is not the kit's job to do for you:

- **iOS makes it impossible.** Usage descriptions must live in the application
  bundle's `Info.plist`. No pod or package can inject them, so host-app setup is
  unavoidable on that platform regardless.
- **Location is optional here.** `requireLocation` defaults to `false`, and
  `SgPermissionGate.ensure(required: {SgPermissionType.camera})` is supported. A
  package that force-merged `ACCESS_FINE_LOCATION` would put a location
  permission — and its Play Store policy burden — on every consumer, including
  the ones who never stamp a location. `geolocator` itself declines to do this
  for the same reason.

> **Strip `RECORD_AUDIO`.** `camera_android_camerax` merges it in because the
> same plugin also records video. This kit never records audio, so leaving it
> puts "Microphone" on your Play listing for no reason. The example manifest
> removes it with `tools:node="remove"` — see below.

### Android

`android/app/build.gradle.kts`

```kotlin
defaultConfig {
    minSdk = 23
}
```

`android/app/src/main/AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- only if you let users pick an existing photo -->
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />

<!-- keep camera-less tablets installable -->
<uses-feature android:name="android.hardware.camera" android:required="false" />
```

### iOS

`ios/Runner/Info.plist` — a missing usage description is a hard crash, not a
denied permission:

```xml
<key>NSCameraUsageDescription</key>
<string>Used to take the photos this app stamps and uploads.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Used to pick an existing photo to stamp.</string>
<key>NSLocationWhenInUseUsageDescription</key>
<string>Used to record where a photo was taken.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Required by the camera component; audio is never recorded.</string>
```

`ios/Podfile` — `permission_handler` compiles **every** permission in unless you
opt out, and App Review rejects binaries that link a permission with no matching
usage description. Enable only these three:

```ruby
platform :ios, '13.0'

post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'PERMISSION_CAMERA=1',
        'PERMISSION_PHOTOS=1',
        'PERMISSION_LOCATION=1',
        # everything else explicitly 0 — see example/ios/Podfile
      ]
    end
  end
end
```

---

## Architecture

Feature-first clean architecture. `core/` holds what more than one feature
needs; every feature owns its own three layers and depends on nothing in another
feature.

```
lib/
├── fc_camera_kit.dart              # the only public surface
└── src/
    ├── core/
    │   ├── config/                 # SgCameraKit singleton, SgCameraConfig      (P2)
    │   ├── permissions/            # one gateway per permission + facade        (P3)
    │   ├── image/
    │   │   ├── compressor/         # quality/resize loop against a byte budget  (P4)
    │   │   └── metadata/           # EXIF read + write                          (P4)
    │   ├── error/                  # SgCameraException, SgCameraFailure         ✅
    │   ├── utils/                  # SgResult and friends                       ✅
    │   └── di/                     # package-private service locator            (P2)
    └── features/
        ├── capture/                # take or pick a photo                       (P5)
        ├── stamping/               # watermark + metadata                       (P6)
        └── scanner/                # document scan                              (P7)
            ├── data/               # datasources · models · repositories
            ├── domain/             # entities · repositories (abstract) · usecases
            └── presentation/       # cubit · pages · widgets
```

### Layer rules

| Layer | May import | May **not** import |
|---|---|---|
| `domain` | `core/error`, `core/utils`, Dart | Flutter, plugins, `data`, `presentation` |
| `data` | `domain`, `core`, plugins | `presentation` |
| `presentation` | `domain`, `core` | `data` |

`domain` staying Flutter-free is what makes the use cases unit-testable without
a widget binding. Repository *interfaces* live in `domain`, implementations in
`data` — so swapping `camera` for something else touches one file.

### Errors

Data sources **throw** `SgCameraException`. Repositories catch and return
`SgResult<T>` — a `typedef` over dartz's `Either<SgCameraFailure, T>`, with the
failure on the **left**. Cubits never `try`/`catch`; they `fold`.

`SgCameraFailure` is `sealed`, so a `switch` over it is exhaustive at compile
time — adding a failure type breaks every incomplete handler instead of silently
falling through.

> ⚠️ **`fold` takes the failure branch first.** That is dartz's convention, not
> ours. Where the ordering is easy to misread, use the success-first
> `when(success:, failure:)` extension instead.

Because `SgResult` is an `Either`, the full combinator set comes for free —
`map`, `flatMap`, `getOrElse` — plus `thenFlatMap` for chaining fallible async
steps without a stair of early returns:

```dart
final result = await capture()
    .thenFlatMap(resolveContext)
    .thenFlatMap(stamp)
    .thenFlatMap(compress);   // short-circuits on the first failure
```

`Either`, `Left` and `Right` are re-exported from `fc_camera_kit.dart`, so host
apps do **not** need to add dartz to their own `pubspec.yaml`.

```dart
final message = switch (failure) {
  PermissionFailure(:final permanentlyDenied) when permanentlyDenied =>
    'Enable camera access in Settings',
  SizeLimitFailure(:final actualBytes, :final limitBytes) =>
    'Photo is ${actualBytes ~/ 1024}KB, limit is ${limitBytes ~/ 1024}KB',
  CancelledFailure() => null,
  _ => failure.message,
};
```

### Why Cubit, and why so few `StatefulWidget`s

Cubit over Bloc: these flows are imperative commands (`capture()`, `stamp()`),
not a stream of domain events. An event class per command would be ceremony
with no payoff.

Rebuild discipline the package holds itself to:

- Pages are `StatelessWidget`; state lives in the Cubit, not in `setState`.
- `BlocBuilder` wraps the **smallest** subtree that actually changes, with
  `buildWhen` guarding it.
- One-shot effects (snackbars, pops, permission dialogs) go through
  `BlocListener`, never through a builder.
- States are `Equatable`, so an identical state emits no rebuild at all.
- Anything that does not depend on state is a `const` widget hoisted out of
  `build`.

---

## Why `XFile` and not `File`

Short version: **the pipeline returns an `XFile`, and converting it to a `File`
is one line.** The reverse — committing to `File` — is the choice you cannot
cheaply undo.

| | `dart:io` `File` | `package:cross_file` `XFile` |
|---|---|---|
| What it is | A handle to a path on a real filesystem | An abstraction over "some readable blob" |
| Platforms | VM only (Android, iOS, desktop). Importing `dart:io` marks the whole library web-incompatible | Everywhere, including web |
| API | Sync **and** async; `exists`, `delete`, `rename`, `copy`, `writeAsBytes`, `lengthSync` | Async only; `path`, `name`, `mimeType`, `length()`, `readAsBytes()`, `openRead()`, `saveTo()` |
| On web | Does not exist | `path` is a `blob:` URL; bytes come from the browser |
| Ecosystem | What `Image.file` and `MultipartFile.fromFile` take | What `camera.takePicture()`, `ImagePicker.pickImage()` and `file_selector` **return** |

Why `XFile` wins here:

1. **No lossy round-trip.** Both capture sources already hand us an `XFile`.
   Unwrapping to `File` and re-wrapping at the boundary is work that buys
   nothing.
2. **It is the ecosystem's currency.** Returning `XFile` means callers can pass
   our output straight into anything that accepts media from `image_picker` or
   `camera`, with no adapter.
3. **Conversion is trivial, and only in one direction is it free.**
   `File(xfile.path)` works on every platform this package supports. Going the
   other way from a web `XFile` is impossible — so `File` in the signature would
   be a permanent ceiling.
4. **It costs nothing today.** We are Android/iOS-only, where `xfile.path` is
   always a real path. `XFile` is simply the option that stays open.

The caveat `File` genuinely wins on: `XFile` has no `delete()`, `exists()` or
sync reads. When the package needs those internally — cleaning up temp files
between pipeline stages — it uses `dart:io` directly. That is an implementation
detail, not the public contract.

### What you actually get back

Not a bare file. A result object, so size, dimensions and the resolved metadata
do not have to be re-derived by every caller:

```dart
final class SgCaptureResult {
  final XFile file;            // the stamped, compressed image
  final SgPhotoMetadata meta;  // who / when / where, as embedded
  final int sizeBytes;
  final Size dimensions;
  final bool wasCompressed;
}

// dart:io escape hatch, Android/iOS only
extension SgXFileIo on XFile {
  File toFile() => File(path);
}
```

> One practical note the type system will not tell you: on iOS the camera writes
> into a temp directory the OS may purge at any time. The pipeline copies its
> output into an app-owned directory before returning, so the `XFile` you get is
> safe to hold across an upload retry.

---

## Planned API

Target shape as of Phase 1 — it will be confirmed phase by phase.

```dart
// main.dart, once — Phase 2
await SgCameraKit.initialize(
  config: SgCameraConfig(
    maxBytes: 5 * 1024 * 1024,        // hard ceiling; compress until under it
    placement: StampPlacement.overlay,
    dateFormat: 'dd MMM yyyy, hh:mm a',
    requireLocation: true,
  ),
);

// whenever the signed-in user changes
SgCameraKit.instance.setUserContext(
  const SgUserContext(name: 'Asha Verma', id: 'EMP-2291'),
);

// at the call site — Phase 5+
final result = await SgCameraKit.instance.capture(
  source: CaptureSource.camera,
  placement: StampPlacement.extend,   // per-call override
);

result.fold(
  (failure) => showError(failure),   // left  = failure
  (capture) => upload(capture.file), // right = success
);
```

`initialize()` is called once; per-call parameters override the config for that
call only. Nothing is read from global state at stamp time — the resolved
metadata is passed down explicitly, which is what keeps the stamping use case
testable without a singleton.

---

## Development

```bash
flutter pub get
flutter analyze          # strict-casts / strict-inference, must be clean
flutter test

cd example && flutter run
```

House rules:

- `flutter analyze` clean is the merge bar.
- Every use case and every Cubit gets a test (`bloc_test` + `mocktail`).
- Doc comments explain *why* and non-obvious behaviour. Restating the signature
  in prose is noise — `public_member_api_docs` is deliberately off.
- Public API changes land with a `CHANGELOG.md` entry.

## Licence

MIT — see [LICENSE](LICENSE).
