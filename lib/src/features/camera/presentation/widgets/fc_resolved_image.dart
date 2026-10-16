import 'package:flutter/widgets.dart';

typedef FcImageStatus = ({Size? size, bool failed});

/// Size comes from the decoded frame, so it already honours EXIF orientation.
class FcResolvedImage extends StatefulWidget {
  const FcResolvedImage({
    required this.image,
    required this.builder,
    super.key,
  });

  final ImageProvider image;
  final Widget Function(BuildContext context, FcImageStatus status) builder;

  @override
  State<FcResolvedImage> createState() => _FcResolvedImageState();
}

class _FcResolvedImageState extends State<FcResolvedImage> {
  ImageStream? _stream;
  late final _listener = ImageStreamListener(_onImage, onError: _onError);
  Size? _size;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(FcResolvedImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _resolve();
  }

  void _resolve() {
    final stream = widget.image.resolve(createLocalImageConfiguration(context));
    if (stream.key == _stream?.key) return;
    _stream?.removeListener(_listener);
    _stream = stream..addListener(_listener);
  }

  void _onImage(ImageInfo info, bool _) {
    final size = Size(
      info.image.width.toDouble(),
      info.image.height.toDouble(),
    );
    // Only the size is needed; the Image widget keeps its own handle.
    info.dispose();
    if (mounted && size != _size) setState(() => _size = size);
  }

  void _onError(Object _, StackTrace? _) {
    if (mounted) setState(() => _failed = true);
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, (size: _size, failed: _failed));
}
