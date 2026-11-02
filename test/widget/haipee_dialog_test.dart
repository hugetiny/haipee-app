import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';

void main() {
  testWidgets('HaipeeDialog.showLoading updates message in-place without stacking routes',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [HaipeeDialog.observer],
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  HaipeeDialog.showLoading(context: context, msg: 'Initial message');
                },
                child: const Text('Show Loading'),
              );
            },
          ),
        ),
      ),
    );

    // Tap to open loading dialog
    await tester.tap(find.text('Show Loading'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Initial message'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Repeated calls to showLoading with new messages (simulating peer status loop)
    HaipeeDialog.showLoading(msg: 'Searching peers (2 peers)...');
    await tester.pump();
    expect(find.text('Searching peers (2 peers)...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    HaipeeDialog.showLoading(msg: 'Connected to 5 peers, receiving metadata...');
    await tester.pump();
    expect(find.text('Connected to 5 peers, receiving metadata...'), findsOneWidget);
    // Crucial: exactly ONE dialog card exists, no dialog stacking explosion!
    expect(find.byType(Card), findsOneWidget);

    // Calling dismiss closes the dialog
    HaipeeDialog.dismiss();
    await tester.pumpAndSettle();

    expect(find.byType(Card), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('HaipeeDialog.showLoading onCancel triggers callback and closes dialog',
      (tester) async {
    bool cancelled = false;

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [HaipeeDialog.observer],
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  HaipeeDialog.showLoading(
                    context: context,
                    msg: 'Connecting to peer nodes...',
                    onCancel: () {
                      cancelled = true;
                    },
                  );
                },
                child: const Text('Show Stream Dialog'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Stream Dialog'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Connecting to peer nodes...'), findsOneWidget);
    expect(find.text('取消等待'), findsOneWidget);

    // User taps cancel button
    await tester.tap(find.text('取消等待'));
    await tester.pumpAndSettle();

    expect(cancelled, isTrue);
    expect(find.byType(Card), findsNothing);
  });
}
