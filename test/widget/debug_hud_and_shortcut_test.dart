import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/services/logging/app_log.dart';
import 'package:kazumi/services/logging/debug_hud_overlay.dart';

void main() {
  group('DebugHudOverlay & Shortcut Tests', () {
    testWidgets('renders child content unconditionally', (tester) async {
      AppLog.setDebugMode(false);
      AppLog.setLogScreenVisible(false);

      await tester.pumpWidget(
        const MaterialApp(
          home: DebugHudOverlay(
            child: Scaffold(
              body: Text('Hello Kazumi'),
            ),
          ),
        ),
      );

      expect(find.text('Hello Kazumi'), findsOneWidget);
      expect(find.text('DevLog'), findsNothing);
    });

    testWidgets('shows floating DevLog chip when debug mode is enabled', (tester) async {
      AppLog.setDebugMode(true);
      AppLog.setLogScreenVisible(false);
      AppLog.resetErrorCount();

      await tester.pumpWidget(
        const MaterialApp(
          home: DebugHudOverlay(
            child: Scaffold(
              body: Text('Hello Kazumi'),
            ),
          ),
        ),
      );

      expect(find.text('DevLog'), findsOneWidget);
      expect(find.byIcon(Icons.terminal_rounded), findsOneWidget);
    });

    testWidgets('displays error count when errors have occurred', (tester) async {
      AppLog.setDebugMode(true);
      AppLog.setLogScreenVisible(false);
      AppLog.resetErrorCount();
      AppLog.recordError();
      AppLog.recordError();

      await tester.pumpWidget(
        const MaterialApp(
          home: DebugHudOverlay(
            child: Scaffold(
              body: Text('Hello Kazumi'),
            ),
          ),
        ),
      );

      expect(find.text('2'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    });

    testWidgets('hides floating HUD when log screen is already open', (tester) async {
      AppLog.setDebugMode(true);
      AppLog.setLogScreenVisible(true);

      await tester.pumpWidget(
        const MaterialApp(
          home: DebugHudOverlay(
            child: Scaffold(
              body: Text('Hello Kazumi'),
            ),
          ),
        ),
      );

      expect(find.text('DevLog'), findsNothing);
    });

    testWidgets('reactively updates error count badge when new errors occur', (tester) async {
      AppLog.setDebugMode(true);
      AppLog.setLogScreenVisible(false);
      AppLog.resetErrorCount();

      await tester.pumpWidget(
        const MaterialApp(
          home: DebugHudOverlay(
            child: Scaffold(
              body: Text('Reactive Test'),
            ),
          ),
        ),
      );

      expect(find.text('DevLog'), findsOneWidget);

      // Trigger error dynamically while widget is mounted
      AppLog.recordError();
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

      // Another error
      AppLog.recordError();
      await tester.pump();

      expect(find.text('2'), findsOneWidget);

      // Reset error count
      AppLog.resetErrorCount();
      await tester.pump();

      expect(find.text('DevLog'), findsOneWidget);
    });

    testWidgets('reactively updates visibility when debug mode is toggled', (tester) async {
      AppLog.setDebugMode(false);
      AppLog.setLogScreenVisible(false);

      await tester.pumpWidget(
        const MaterialApp(
          home: DebugHudOverlay(
            child: Scaffold(
              body: Text('Toggle Test'),
            ),
          ),
        ),
      );

      expect(find.text('DevLog'), findsNothing);

      // Enable debug mode dynamically
      AppLog.setDebugMode(true);
      await tester.pump();

      expect(find.text('DevLog'), findsOneWidget);

      // Disable debug mode dynamically
      AppLog.setDebugMode(false);
      await tester.pump();

      expect(find.text('DevLog'), findsNothing);
    });

    testWidgets('tapping HUD chip in MaterialApp.builder opens log screen without navigator errors', (tester) async {
      AppLog.setDebugMode(true);
      AppLog.setLogScreenVisible(false);
      AppLog.resetErrorCount();

      final navKey = GlobalKey<NavigatorState>();
      AppLog.rootNavigatorKey = navKey;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          builder: (context, child) => DebugHudOverlay(child: child ?? const SizedBox()),
          home: const Scaffold(
            body: Text('App Content'),
          ),
        ),
      );

      expect(find.text('DevLog'), findsOneWidget);

      // Tap the DevLog chip which is above Navigator in builder
      await tester.tap(find.text('DevLog'));
      await tester.pumpAndSettle();

      expect(AppLog.isLogScreenOpen, isTrue);

      // Tap again to toggle closed
      await tester.sendKeyEvent(LogicalKeyboardKey.f12);
      await tester.pumpAndSettle();

      expect(AppLog.isLogScreenOpen, isFalse);
    });

    testWidgets('F12 key event toggles log screen', (tester) async {
      AppLog.setDebugMode(true);
      AppLog.setLogScreenVisible(false);

      final navKey = GlobalKey<NavigatorState>();
      AppLog.rootNavigatorKey = navKey;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navKey,
          home: const DebugHudOverlay(
            child: Scaffold(
              body: Text('Main Page'),
            ),
          ),
        ),
      );

      // Simulate F12 key press
      await tester.sendKeyEvent(LogicalKeyboardKey.f12);
      await tester.pumpAndSettle();

      expect(AppLog.isLogScreenOpen, isTrue);

      // Press F12 again to toggle close
      await tester.sendKeyEvent(LogicalKeyboardKey.f12);
      await tester.pumpAndSettle();

      expect(AppLog.isLogScreenOpen, isFalse);
    });
  });
}
