import 'package:flutter/material.dart';

/// An icon over a label, sized for a thumb on a dark camera surface.
///
/// [active] marks a tool already in use, such as a photo already cropped.
class FcCameraToolButton extends StatelessWidget {
  const FcCameraToolButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.active = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = enabled ? Colors.white : Colors.white38;

    return Semantics(
      button: true,
      enabled: enabled,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onPressed,
        radius: 36,
        child: SizedBox(
          width: 72,
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Badge(
                isLabelVisible: active,
                smallSize: 8,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
