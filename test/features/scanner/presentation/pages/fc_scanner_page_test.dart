import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:fc_camera_kit/fc_camera_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRepository extends Mock implements FcScanRepository {}

void main() {
  late _MockRepository repository;
  late GlobalKey<NavigatorState> navigatorKey;

  final raw = XFile('/raw/a.jpg');
  final page = FcScannedPage(
    file: XFile('/out/a.jpg'),
    sizeBytes: 100,
    width: 10,
    height: 20,
    wasCompressed: false,
    quality: 90,
  );

  setUpAll(() {
    registerFallbackValue(const FcScanOptions());
    registerFallbackValue(XFile(''));
  });

  setUp(() async {
    FcCameraKit.reset();
    await FcCameraKit.instance.init();
    navigatorKey = GlobalKey<NavigatorState>();
    repository = _MockRepository();
    when(() => repository.clearCache()).thenAnswer((_) async {});
    when(
      () => repository.discard(pages: any(named: 'pages')),
    ).thenAnswer((_) async {});
  });

  tearDown(FcCameraKit.reset);

  void acquireReturns(FcResult<List<XFile>> Function() result) =>
      when(() => repository.acquire(any())).thenAnswer((_) async => result());

  void processSucceeds() => when(
    () => repository.process(
      any(),
      maxBytes: any(named: 'maxBytes'),
      metadata: any(named: 'metadata'),
      writeMetadata: any(named: 'writeMetadata'),
      stamp: any(named: 'stamp'),
      onStage: any(named: 'onStage'),
    ),
  ).thenAnswer((_) async => fcSuccess(page));

  // Spinners never settle, so advance time in fixed steps instead.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pumpHost(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('host')),
    ),
  );

  Future<Object?> open(WidgetTester tester, FcScannerPage scanner) {
    final popped = navigatorKey.currentState!.push<Object?>(
      MaterialPageRoute(builder: (_) => scanner),
    );
    return popped;
  }

  group('FcScannerPage', () {
    testWidgets('closes itself on success even if onCompleted does nothing', (
      tester,
    ) async {
      acquireReturns(() => fcSuccess([raw]));
      processSucceeds();
      var completed = 0;

      await pumpHost(tester);
      final popped = open(
        tester,
        FcScannerPage(repository: repository, onCompleted: (_) => completed++),
      );
      await settle(tester);

      expect(completed, 1);
      expect(await popped, FcScanResult([page]));
      expect(find.text('host'), findsOneWidget);
    });

    testWidgets('removes only its own route when a host dialog is on top', (
      tester,
    ) async {
      final scanning = Completer<FcResult<List<XFile>>>();
      when(() => repository.acquire(any())).thenAnswer((_) => scanning.future);
      processSucceeds();

      await pumpHost(tester);
      final popped = open(tester, FcScannerPage(repository: repository));
      await settle(tester);

      unawaited(
        navigatorKey.currentState!.push<void>(
          DialogRoute(
            context: navigatorKey.currentContext!,
            builder: (_) => const Text('session dialog'),
          ),
        ),
      );
      await settle(tester);

      scanning.complete(fcSuccess([raw]));
      await settle(tester);

      expect(await popped, FcScanResult([page]));
      expect(find.text('session dialog'), findsOneWidget);
    });

    testWidgets('shows the scanned page behind the progress while preparing', (
      tester,
    ) async {
      final processing = Completer<FcResult<FcScannedPage>>();
      acquireReturns(() => fcSuccess([raw]));
      when(
        () => repository.process(
          any(),
          maxBytes: any(named: 'maxBytes'),
          metadata: any(named: 'metadata'),
          writeMetadata: any(named: 'writeMetadata'),
          stamp: any(named: 'stamp'),
          onStage: any(named: 'onStage'),
        ),
      ).thenAnswer((_) => processing.future);

      await pumpHost(tester);
      final popped = open(tester, FcScannerPage(repository: repository));
      await settle(tester);

      final pageImage = find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is ResizeImage &&
            ((widget.image as ResizeImage).imageProvider as FileImage)
                    .file
                    .path ==
                raw.path,
      );
      expect(pageImage, findsOneWidget);
      expect(find.text('Preparing scan'), findsOneWidget);
      expect(find.text('Keep the app open'), findsOneWidget);

      processing.complete(fcSuccess(page));
      await settle(tester);

      expect(await popped, FcScanResult([page]));
    });

    testWidgets('moving to the next page keeps the same screen and spinner', (
      tester,
    ) async {
      final rawB = XFile('/raw/b.jpg');
      final first = Completer<FcResult<FcScannedPage>>();
      final second = Completer<FcResult<FcScannedPage>>();
      acquireReturns(() => fcSuccess([raw, rawB]));
      when(
        () => repository.process(
          raw,
          maxBytes: any(named: 'maxBytes'),
          metadata: any(named: 'metadata'),
          writeMetadata: any(named: 'writeMetadata'),
          stamp: any(named: 'stamp'),
          onStage: any(named: 'onStage'),
        ),
      ).thenAnswer((_) => first.future);
      when(
        () => repository.process(
          rawB,
          maxBytes: any(named: 'maxBytes'),
          metadata: any(named: 'metadata'),
          writeMetadata: any(named: 'writeMetadata'),
          stamp: any(named: 'stamp'),
          onStage: any(named: 'onStage'),
        ),
      ).thenAnswer((_) => second.future);

      await pumpHost(tester);
      final popped = open(tester, FcScannerPage(repository: repository));
      await settle(tester);

      const surface = ValueKey('fc-scan-preparing');
      final surfaceOnPage1 = tester.element(find.byKey(surface));
      final mainSpinner = find.byWidgetPredicate(
        (widget) =>
            widget is CircularProgressIndicator && widget.strokeWidth == 3,
      );
      final spinnerOnPage1 = tester.element(mainSpinner);
      expect(find.text('Preparing page 1 of 2'), findsOneWidget);

      first.complete(fcSuccess(page));
      await settle(tester);

      expect(find.text('Preparing page 2 of 2'), findsOneWidget);
      expect(tester.element(find.byKey(surface)), same(surfaceOnPage1));
      expect(tester.element(mainSpinner), same(spinnerOnPage1));

      second.complete(fcSuccess(page));
      await settle(tester);
      expect(await popped, isA<FcScanResult>());
    });

    testWidgets('stamps with the init() placement and lists every step', (
      tester,
    ) async {
      FcCameraKit.reset();
      await FcCameraKit.instance.init(placement: StampPlacement.extend);
      final processing = Completer<FcResult<FcScannedPage>>();
      acquireReturns(() => fcSuccess([raw]));
      when(
        () => repository.process(
          any(),
          maxBytes: any(named: 'maxBytes'),
          metadata: any(named: 'metadata'),
          writeMetadata: any(named: 'writeMetadata'),
          stamp: any(named: 'stamp'),
          onStage: any(named: 'onStage'),
        ),
      ).thenAnswer((_) => processing.future);

      await pumpHost(tester);
      final popped = open(
        tester,
        FcScannerPage(repository: repository, stamp: true),
      );
      await settle(tester);

      final stamp = verify(
        () => repository.process(
          raw,
          maxBytes: any(named: 'maxBytes'),
          metadata: captureAny(named: 'metadata'),
          writeMetadata: any(named: 'writeMetadata'),
          stamp: captureAny(named: 'stamp'),
          onStage: any(named: 'onStage'),
        ),
      ).captured;
      expect(stamp[0], isA<FcPhotoMetadata>());
      expect(
        stamp[1],
        isA<FcScanStamp>().having(
          (s) => s.placement,
          'placement',
          StampPlacement.extend,
        ),
      );
      expect(find.text(FcScanStage.stamping.label), findsOneWidget);
      expect(find.text(FcScanStage.compressing.label), findsOneWidget);
      expect(find.text(FcScanStage.writingMetadata.label), findsOneWidget);

      processing.complete(fcSuccess(page));
      await settle(tester);
      expect(await popped, isA<FcScanResult>());
    });

    testWidgets('a per-call placement overrides init()', (tester) async {
      acquireReturns(() => fcSuccess([raw]));
      processSucceeds();

      await pumpHost(tester);
      final popped = open(
        tester,
        FcScannerPage(
          repository: repository,
          stamp: true,
          placement: StampPlacement.extend,
        ),
      );
      await settle(tester);
      await popped;

      final captured = verify(
        () => repository.process(
          raw,
          maxBytes: any(named: 'maxBytes'),
          metadata: any(named: 'metadata'),
          writeMetadata: any(named: 'writeMetadata'),
          stamp: captureAny(named: 'stamp'),
          onStage: any(named: 'onStage'),
        ),
      ).captured;
      expect((captured.single as FcScanStamp).placement, StampPlacement.extend);
    });

    testWidgets('does not stamp by default', (tester) async {
      final processing = Completer<FcResult<FcScannedPage>>();
      acquireReturns(() => fcSuccess([raw]));
      when(
        () => repository.process(
          any(),
          maxBytes: any(named: 'maxBytes'),
          metadata: any(named: 'metadata'),
          writeMetadata: any(named: 'writeMetadata'),
          stamp: any(named: 'stamp'),
          onStage: any(named: 'onStage'),
        ),
      ).thenAnswer((_) => processing.future);

      await pumpHost(tester);
      final popped = open(tester, FcScannerPage(repository: repository));
      await settle(tester);

      verify(
        () => repository.process(
          raw,
          maxBytes: any(named: 'maxBytes'),
          metadata: any(named: 'metadata'),
          writeMetadata: any(named: 'writeMetadata'),
          stamp: any(named: 'stamp', that: isNull),
          onStage: any(named: 'onStage'),
        ),
      ).called(1);
      expect(find.text(FcScanStage.stamping.label), findsNothing);
      expect(find.text(FcScanStage.compressing.label), findsOneWidget);

      processing.complete(fcSuccess(page));
      await settle(tester);
      await popped;
    });

    testWidgets('centres the spinner, text and steps as one group', (
      tester,
    ) async {
      final processing = Completer<FcResult<FcScannedPage>>();
      acquireReturns(() => fcSuccess([raw]));
      when(
        () => repository.process(
          any(),
          maxBytes: any(named: 'maxBytes'),
          metadata: any(named: 'metadata'),
          writeMetadata: any(named: 'writeMetadata'),
          stamp: any(named: 'stamp'),
          onStage: any(named: 'onStage'),
        ),
      ).thenAnswer((_) => processing.future);

      await pumpHost(tester);
      final popped = open(tester, FcScannerPage(repository: repository));
      await settle(tester);

      final top = tester
          .getTopLeft(
            find.byWidgetPredicate(
              (widget) =>
                  widget is CircularProgressIndicator &&
                  widget.strokeWidth == 3,
            ),
          )
          .dy;
      final bottom = tester
          .getBottomLeft(find.text(FcScanStage.writingMetadata.label))
          .dy;
      final screen = tester.getSize(find.byType(Scaffold).last).height;

      expect((top + bottom) / 2, closeTo(screen / 2, 24));

      processing.complete(fcSuccess(page));
      await settle(tester);
      await popped;
    });

    testWidgets('a cancel fires onCancelled once and closes', (tester) async {
      acquireReturns(() => fcFailure(const CancelledFailure()));
      var cancelled = 0;

      await pumpHost(tester);
      final popped = open(
        tester,
        FcScannerPage(repository: repository, onCancelled: () => cancelled++),
      );
      await settle(tester);

      expect(cancelled, 1);
      expect(await popped, isNull);
    });

    testWidgets('invalid maxPages fails cleanly instead of hanging', (
      tester,
    ) async {
      FcCameraFailure? failure;

      await pumpHost(tester);
      final popped = open(
        tester,
        FcScannerPage(
          repository: repository,
          maxPages: 0,
          onFailed: (error) => failure = error,
        ),
      );
      await settle(tester);

      expect(failure, isA<ConfigurationFailure>());
      expect(await popped, isNull);
      verifyNever(() => repository.acquire(any()));
    });

    testWidgets('without onFailed shows the error, and closing it reports a '
        'cancel', (tester) async {
      acquireReturns(() => fcFailure(const CameraFailure('busy')));
      var cancelled = 0;

      await pumpHost(tester);
      final popped = open(
        tester,
        FcScannerPage(repository: repository, onCancelled: () => cancelled++),
      );
      await settle(tester);

      expect(find.text('Scan failed'), findsOneWidget);

      await tester.tap(find.byType(FcCloseButton));
      await settle(tester);

      expect(cancelled, 1);
      expect(await popped, isNull);
    });

    testWidgets('retry after an error runs a fresh scan', (tester) async {
      var attempts = 0;
      when(() => repository.acquire(any())).thenAnswer((_) async {
        attempts++;
        return attempts == 1
            ? fcFailure(const CameraFailure('busy'))
            : fcSuccess([raw]);
      });
      processSucceeds();

      await pumpHost(tester);
      final popped = open(tester, FcScannerPage(repository: repository));
      await settle(tester);

      await tester.tap(find.text('Try again'));
      await settle(tester);

      expect(attempts, 2);
      expect(await popped, FcScanResult([page]));
    });

    testWidgets('system back reports a cancel exactly once', (tester) async {
      final scanning = Completer<FcResult<List<XFile>>>();
      when(() => repository.acquire(any())).thenAnswer((_) => scanning.future);
      var cancelled = 0;

      await pumpHost(tester);
      final popped = open(
        tester,
        FcScannerPage(repository: repository, onCancelled: () => cancelled++),
      );
      await settle(tester);

      await navigatorKey.currentState!.maybePop();
      await settle(tester);
      scanning.complete(fcFailure(const CancelledFailure()));
      await settle(tester);

      expect(cancelled, 1);
      expect(await popped, isNull);
    });

    testWidgets('reports a cancel once when the host clears the stack', (
      tester,
    ) async {
      when(
        () => repository.acquire(any()),
      ).thenAnswer((_) => Completer<FcResult<List<XFile>>>().future);
      var cancelled = 0;

      await pumpHost(tester);
      unawaited(
        open(
          tester,
          FcScannerPage(repository: repository, onCancelled: () => cancelled++),
        ),
      );
      await settle(tester);

      unawaited(
        navigatorKey.currentState!.pushAndRemoveUntil<void>(
          MaterialPageRoute(builder: (_) => const Text('login')),
          (_) => false,
        ),
      );
      await settle(tester);

      expect(cancelled, 1);
      expect(find.text('login'), findsOneWidget);
    });

    testWidgets('as the first route it shows a finished view, not a spinner', (
      tester,
    ) async {
      acquireReturns(() => fcSuccess([raw]));
      processSucceeds();

      await tester.pumpWidget(
        MaterialApp(home: FcScannerPage(repository: repository)),
      );
      await settle(tester);

      expect(find.text('Scan complete'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('FcCameraKit.scan', () {
    setUp(() => FcCameraKitScan.debugRepository = repository);
    tearDown(() => FcCameraKitScan.debugRepository = null);

    testWidgets('fails cleanly when init() was not called', (tester) async {
      FcCameraKit.reset();
      await pumpHost(tester);

      final result = await FcCameraKit.instance.scan(
        navigatorKey.currentContext!,
      );

      expect(result.failureOrNull, isA<ConfigurationFailure>());
    });

    testWidgets('returns the result and closes the scanner', (tester) async {
      acquireReturns(() => fcSuccess([raw]));
      processSucceeds();
      await pumpHost(tester);

      final pending = FcCameraKit.instance.scan(navigatorKey.currentContext!);
      await settle(tester);

      expect((await pending).valueOrNull, FcScanResult([page]));
      expect(find.text('host'), findsOneWidget);
    });

    testWidgets('a second call while scanning shares the first scan', (
      tester,
    ) async {
      final scanning = Completer<FcResult<List<XFile>>>();
      when(() => repository.acquire(any())).thenAnswer((_) => scanning.future);
      await pumpHost(tester);
      final context = navigatorKey.currentContext!;

      final first = FcCameraKit.instance.scan(context);
      final second = FcCameraKit.instance.scan(context);
      await settle(tester);

      expect(identical(first, second), isTrue);
      verify(() => repository.acquire(any())).called(1);

      scanning.complete(fcFailure(const CancelledFailure()));
      await settle(tester);

      expect((await first).failureOrNull, isA<CancelledFailure>());
      expect(find.text('host'), findsOneWidget);
    });

    testWidgets('returns and frees scan() when the host clears the stack', (
      tester,
    ) async {
      var attempts = 0;
      when(() => repository.acquire(any())).thenAnswer((_) {
        attempts++;
        // First scan never returns, like a scanner left open at logout.
        return attempts == 1
            ? Completer<FcResult<List<XFile>>>().future
            : Future.value(fcFailure(const CancelledFailure()));
      });
      await pumpHost(tester);

      final first = FcCameraKit.instance.scan(navigatorKey.currentContext!);
      await settle(tester);

      unawaited(
        navigatorKey.currentState!.pushAndRemoveUntil<void>(
          MaterialPageRoute(builder: (_) => const Text('login')),
          (_) => false,
        ),
      );
      await settle(tester);

      expect((await first).failureOrNull, isA<CancelledFailure>());

      final second = FcCameraKit.instance.scan(navigatorKey.currentContext!);
      await settle(tester);

      expect(identical(first, second), isFalse);
      expect((await second).failureOrNull, isA<CancelledFailure>());
      expect(attempts, 2);
    });

    testWidgets('a new scan can start once the previous one returned', (
      tester,
    ) async {
      acquireReturns(() => fcFailure(const CancelledFailure()));
      await pumpHost(tester);
      final context = navigatorKey.currentContext!;

      final first = FcCameraKit.instance.scan(context);
      await settle(tester);
      await first;

      final second = FcCameraKit.instance.scan(context);
      await settle(tester);
      await second;

      expect(identical(first, second), isFalse);
      verify(() => repository.acquire(any())).called(2);
    });
  });
}
