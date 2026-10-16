/// Megabytes to bytes. 1 MB = 1024 × 1024 bytes, the same unit as `sizeMb`
/// on every result.
int fcBytesFromMb(double mb) => (mb * 1024 * 1024).round();
