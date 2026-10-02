# Changelog

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
