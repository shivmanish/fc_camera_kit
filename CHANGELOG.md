# Changelog

## 1.0.0

Aligned with `fc_smart_camera` 1.0.0. Android and iOS only.

- In-app camera for `capture()`: flash, pinch zoom, lens switch; gallery picks kept.
- Photo review after the shutter: zoom, Retake, Crop or Use photo.
- Crop & rotate editor, applied once at stamp time.
- `FcApp` (name, version, environment) required in `init(app:)`; `package_info_plus` dropped.
- `FcUser` entity with required `branch` and optional `role`, shown in stamp and EXIF.
- Stamp shows app line, empty parts skipped, `(MOCKED)` on mock locations.
- Size limit in megabytes: `init(maxMb:)`, `capture(maxMb:)`.
- EXIF expanded: `Artist`, timestamps with offsets, GPS details, `ImageUniqueID`, device, `Software`.
- Stamp encode moved off the UI thread; review dispose crash fixed.
- `CaptureCubit` removed; capture runs through the camera flow.
- Wider dependency ranges for hosts: `camera`, `google_mlkit_face_detection`, `geolocator`, `geocoding`, `intl`.
- Example app updated for the new camera, review and identity flows.

## 0.1.0

Phase 1 — package scaffold. No capture pipeline yet.

- Feature-first clean architecture skeleton under `lib/src/`.
- Sealed `SgCameraException` (thrown by data sources) and `SgCameraFailure`
  (carried in state) hierarchies.
- `SgResult<T>` as a `typedef` over dartz `Either<SgCameraFailure, T>`, plus
  `when` (success-first), `thenFlatMap` and `thenMap` for async chaining.
- `Either` / `Left` / `Right` re-exported so host apps need not depend on dartz.
- Strict analyzer setup: `strict-casts`, `strict-inference`, `strict-raw-types`.
- Example app with Android and iOS permission config applied.
