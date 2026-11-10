import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Global test harness configuration (auto-loaded by `flutter test`).
///
/// `testWidgets` ignores the CLI `--timeout` flag: [AutomatedTestWidgetsFlutterBinding]
/// enforces its own `defaultTestTimeout` (10 minutes by default). A single
/// deadlocked widget test (e.g. real file I/O awaited inside the fake-async zone)
/// could therefore stall CI for 10 minutes per test. Cap it at 90 seconds so a
/// hang fails fast with a stack trace instead of exhausting the CI job budget.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  if (binding is AutomatedTestWidgetsFlutterBinding) {
    binding.defaultTestTimeout = const Timeout(Duration(seconds: 90));
  }
  await testMain();
}
