/// One step of preparing a scanned page, in the order they run.
enum FcScanStage {
  stamping('Adding the stamp'),
  compressing('Compressing'),
  writingMetadata('Writing metadata');

  const FcScanStage(this.label);

  final String label;
}
