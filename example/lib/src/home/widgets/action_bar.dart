import 'package:flutter/material.dart';

/// The three flows, one tap each, sized to fit a 360 dp phone.
class ActionBar extends StatelessWidget {
  const ActionBar({
    super.key,
    required this.enabled,
    required this.onCapture,
    required this.onScan,
    required this.onFace,
  });

  final bool enabled;
  final VoidCallback onCapture;
  final VoidCallback onScan;
  final VoidCallback onFace;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            _action(Icons.photo_camera_rounded, 'Photo', onCapture),
            const SizedBox(width: 10),
            _action(Icons.document_scanner_rounded, 'Scan', onScan),
            const SizedBox(width: 10),
            _action(Icons.face_retouching_natural_rounded, 'Face', onFace),
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onPressed) =>
      Expanded(
        child: FilledButton.tonalIcon(
          onPressed: enabled ? onPressed : null,
          icon: Icon(icon, size: 20),
          label: Text(label),
          style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
        ),
      );
}
