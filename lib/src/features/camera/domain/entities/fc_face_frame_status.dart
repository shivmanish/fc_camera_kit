import 'package:equatable/equatable.dart';

enum FcFaceFrameTone {
  searching,

  /// Face valid and liveness passed.
  ready,
  working,
  done,
  failed,
}

enum FcFaceFrameAction { primary, secondary }

/// What the face frame shows; the host flow decides it, the camera renders it.
final class FcFaceFrameStatus extends Equatable {
  const FcFaceFrameStatus({
    required this.tone,
    required this.message,
    this.messageId = 0,
    this.detail,
    this.shutterEnabled = false,
    this.frozenImagePath,
    this.steps = const [],
    this.currentStep = 0,
    this.primaryAction,
    this.secondaryAction,
    this.countdown,
    this.frozenMirrored = false,
  });

  const FcFaceFrameStatus.starting()
    : this(tone: FcFaceFrameTone.searching, message: 'Starting camera');

  final FcFaceFrameTone tone;

  final String message;

  /// New id per message so a repeated message doesn't clash with its fade-out.
  final int messageId;
  final String? detail;
  final bool shutterEnabled;

  final String? frozenImagePath;

  final List<String> steps;
  final int currentStep;

  /// `null` hides the button.
  final String? primaryAction;
  final String? secondaryAction;

  /// Auto-capture time left; `null` when there is no auto-capture.
  final Duration? countdown;

  /// Frozen photo is already mirrored; don't flip it again.
  final bool frozenMirrored;

  FcFaceFrameStatus copyWith({String? message, int? messageId}) =>
      FcFaceFrameStatus(
        tone: tone,
        message: message ?? this.message,
        messageId: messageId ?? this.messageId,
        detail: detail,
        shutterEnabled: shutterEnabled,
        frozenImagePath: frozenImagePath,
        steps: steps,
        currentStep: currentStep,
        primaryAction: primaryAction,
        secondaryAction: secondaryAction,
        countdown: countdown,
        frozenMirrored: frozenMirrored,
      );

  bool get isLive =>
      tone == FcFaceFrameTone.searching || tone == FcFaceFrameTone.ready;

  bool get showsShutter => isLive && primaryAction == null;

  @override
  List<Object?> get props => [
    tone,
    message,
    messageId,
    detail,
    shutterEnabled,
    frozenImagePath,
    steps,
    currentStep,
    primaryAction,
    secondaryAction,
    countdown,
    frozenMirrored,
  ];
}
