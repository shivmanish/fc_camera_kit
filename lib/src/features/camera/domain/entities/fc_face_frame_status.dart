import 'package:equatable/equatable.dart';

/// What the face ring says at a glance.
enum FcFaceFrameTone {
  /// Looking for a valid face: red ring.
  searching,

  /// Valid face, liveness passed: green ring.
  ready,

  /// Something is running on the taken photo: progress arc.
  working,

  /// Finished: full green ring with a tick.
  done,

  /// Finished badly: red ring with a cross.
  failed,
}

/// The buttons the frame can offer once a flow has stopped.
enum FcFaceFrameAction { primary, secondary }

/// Everything the face-detection frame shows, as one value.
///
/// The camera feature renders it; whoever owns the flow decides it.
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

  /// The one line the user reads: a hint while live, a title otherwise.
  final String message;

  /// Changes whenever [message] does, so a message that returns gets a fresh
  /// identity in transitions instead of clashing with its fading-out self.
  final int messageId;
  final String? detail;
  final bool shutterEnabled;

  /// Shown instead of the live preview once a photo has been taken.
  final String? frozenImagePath;

  /// Steps listed under the ring while [tone] is working.
  final List<String> steps;
  final int currentStep;

  /// Labels for the buttons under the message; `null` hides a button.
  final String? primaryAction;
  final String? secondaryAction;

  /// While ready: time left before the photo takes itself; the ring fills
  /// over it. `null` when there is no auto-capture.
  final Duration? countdown;

  /// The frozen photo already matches the mirrored preview; show it as is.
  final bool frozenMirrored;

  /// The camera is being judged: red or green, frames flowing.
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

  /// The shutter is on screen only while live and no buttons are offered.
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
