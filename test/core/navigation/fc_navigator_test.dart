import 'dart:async';

import 'package:fc_camera_kit/src/core/navigation/fc_navigator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late GlobalKey<NavigatorState> navigatorKey;
  late BuildContext pageContext;

  setUp(() => navigatorKey = GlobalKey<NavigatorState>());

  Future<void> pumpHost(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Text('host')),
    ),
  );

  Future<String?> pushPage(WidgetTester tester, {bool animate = true}) {
    final outcome = FcNavigator.push<String>(navigatorKey.currentContext!, (
      context,
    ) {
      pageContext = context;
      return const Scaffold(body: Text('kit page'));
    }, animate: animate);
    return outcome;
  }

  group('push', () {
    testWidgets('completes with the result the page closes with', (
      tester,
    ) async {
      await pumpHost(tester);
      final outcome = pushPage(tester);
      await tester.pumpAndSettle();

      FcNavigator.close(pageContext, 'done');
      await tester.pumpAndSettle();

      expect(await outcome, 'done');
      expect(find.text('host'), findsOneWidget);
    });

    testWidgets('completes with null when removed by pushAndRemoveUntil', (
      tester,
    ) async {
      await pumpHost(tester);
      final outcome = pushPage(tester);
      await tester.pumpAndSettle();

      unawaited(
        navigatorKey.currentState!.pushAndRemoveUntil<void>(
          MaterialPageRoute(builder: (_) => const Text('login')),
          (_) => false,
        ),
      );
      await tester.pumpAndSettle();

      expect(await outcome, isNull);
      expect(find.text('login'), findsOneWidget);
    });

    testWidgets('completes with null on a system back', (tester) async {
      await pumpHost(tester);
      final outcome = pushPage(tester);
      await tester.pumpAndSettle();

      await navigatorKey.currentState!.maybePop();
      await tester.pumpAndSettle();

      expect(await outcome, isNull);
    });

    testWidgets('shows the page on the next frame when not animated', (
      tester,
    ) async {
      await pumpHost(tester);
      unawaited(pushPage(tester, animate: false));
      await tester.pump();
      await tester.pump();

      expect(find.text('kit page'), findsOneWidget);
      expect(find.text('host'), findsNothing);
    });
  });

  group('close', () {
    testWidgets('removes its own route and leaves a dialog on top intact', (
      tester,
    ) async {
      await pumpHost(tester);
      final outcome = pushPage(tester);
      await tester.pumpAndSettle();
      unawaited(
        navigatorKey.currentState!.push<void>(
          DialogRoute(
            context: navigatorKey.currentContext!,
            builder: (_) => const Text('session dialog'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final closed = FcNavigator.close(pageContext, 'done');
      await tester.pumpAndSettle();

      expect(closed, isTrue);
      expect(await outcome, 'done');
      expect(find.text('session dialog'), findsOneWidget);
    });

    testWidgets('refuses to close the first route', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              pageContext = context;
              return const Text('root');
            },
          ),
        ),
      );

      expect(FcNavigator.close(pageContext), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('root'), findsOneWidget);
    });

    testWidgets('returns false once the route is already gone', (tester) async {
      await pumpHost(tester);
      unawaited(pushPage(tester));
      await tester.pumpAndSettle();
      final staleContext = pageContext;

      expect(FcNavigator.close(staleContext), isTrue);
      expect(FcNavigator.close(staleContext), isFalse);
      await tester.pumpAndSettle();
    });
  });

  group('showSheet and showDialog', () {
    void clearStack() => unawaited(
      navigatorKey.currentState!.pushAndRemoveUntil<void>(
        MaterialPageRoute(builder: (_) => const Text('login')),
        (_) => false,
      ),
    );

    testWidgets('a sheet completes with the value it closes with', (
      tester,
    ) async {
      await pumpHost(tester);
      final outcome = FcNavigator.showSheet<bool>(
        navigatorKey.currentContext!,
        (context) {
          pageContext = context;
          return const Text('sheet');
        },
      );
      await tester.pumpAndSettle();

      FcNavigator.close(pageContext, true);
      await tester.pumpAndSettle();

      expect(await outcome, isTrue);
      expect(find.text('sheet'), findsNothing);
    });

    testWidgets('a sheet completes with null when the host clears the stack', (
      tester,
    ) async {
      await pumpHost(tester);
      final outcome = FcNavigator.showSheet<bool>(
        navigatorKey.currentContext!,
        (_) => const Text('sheet'),
        isDismissible: false,
      );
      await tester.pumpAndSettle();

      clearStack();
      await tester.pumpAndSettle();

      expect(await outcome, isNull);
      expect(find.text('login'), findsOneWidget);
    });

    testWidgets('a dialog completes with the value it closes with', (
      tester,
    ) async {
      await pumpHost(tester);
      final outcome = FcNavigator.showDialog<bool>(
        navigatorKey.currentContext!,
        (context) {
          pageContext = context;
          return const Text('dialog');
        },
      );
      await tester.pumpAndSettle();

      FcNavigator.close(pageContext, false);
      await tester.pumpAndSettle();

      expect(await outcome, isFalse);
    });

    testWidgets('a dialog completes with null when the host clears the stack', (
      tester,
    ) async {
      await pumpHost(tester);
      final outcome = FcNavigator.showDialog<bool>(
        navigatorKey.currentContext!,
        (_) => const Text('dialog'),
        barrierDismissible: false,
      );
      await tester.pumpAndSettle();

      clearStack();
      await tester.pumpAndSettle();

      expect(await outcome, isNull);
    });
  });
}
