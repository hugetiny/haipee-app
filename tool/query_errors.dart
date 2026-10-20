// ignore_for_file: avoid_print
import 'dart:io';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

void main() async {
  final regExp = RegExp(r'ws://127\.0\.0\.1:(\d+)/([a-zA-Z0-9_\-=]+)/ws');
  final httpRegExp = RegExp(r'http://127\.0\.0\.1:(\d+)/([a-zA-Z0-9_\-=]+)/');
  String? uriStr;

  final tasksDir = Directory('/Users/a12/.gemini/antigravity-cli/brain/f8aa996f-3e7a-43fd-a39e-24ad2cba58f0/.system_generated/tasks');
  if (await tasksDir.exists()) {
    final files = tasksDir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.log'))
        .toList()
      ..sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

    for (final file in files) {
      try {
        final lines = await file.readAsLines();
        for (final line in lines.reversed) {
          final match = regExp.firstMatch(line);
          if (match != null) {
            uriStr = match.group(0);
            break;
          }
          final httpMatch = httpRegExp.firstMatch(line);
          if (httpMatch != null) {
            uriStr = 'ws://127.0.0.1:${httpMatch.group(1)}/${httpMatch.group(2)}/ws';
            break;
          }
        }
        if (uriStr != null) break;
      } catch (_) {}
    }
  }

  uriStr ??= 'ws://127.0.0.1:54730/eKfHHGl0lbc=/ws';

  final client = await vmServiceConnectUri(uriStr);
  final vm = await client.getVM();
  print('Isolates: ${vm.isolates!.map((i) => "${i.id}: ${i.name}").toList()}');
  final isolateId = vm.isolates!.last.id!;
  final isolate = await client.getIsolate(isolateId);
  final libs = isolate.libraries!;
  final logLib = libs.firstWhere((l) => l.uri?.contains('app_log.dart') ?? false);

  final bool shouldReset = Platform.environment['RESET_ERRORS'] == '1';

  if (shouldReset) {
    await client.evaluate(isolateId, logLib.id!, 'AppLog.resetErrorCount()');
    await client.evaluate(isolateId, logLib.id!, 'AppLog.talker.cleanHistory()');
  }

  final errCountRes = await client.evaluate(isolateId, logLib.id!, 'AppLog.errorCount');
  print('AppLog.errorCount: ${(errCountRes as InstanceRef).valueAsString}');

  final histRes = await client.evaluate(isolateId, logLib.id!, 'AppLog.talker.history.length');
  print('Talker history length: ${(histRes as InstanceRef).valueAsString}');

  final errorsEval = await client.evaluate(isolateId, logLib.id!, 
    'AppLog.talker.history.where((e) => e is TalkerError || e is TalkerException || e.logLevel == LogLevel.error || e.logLevel == LogLevel.critical).map((e) => "\${e.logLevel?.name.toUpperCase()}: \${e.message}").toList()'
  );
  final allItemsEval = await client.evaluate(isolateId, logLib.id!,
    'AppLog.talker.history.map((e) => "[\${e.logLevel?.name.toUpperCase()}] \${e.message}").toList()'
  );
  if (allItemsEval is InstanceRef && allItemsEval.length != null) {
    print('All Talker items (${allItemsEval.length}):');
    final len = allItemsEval.length!;
    for (var i = 0; i < len; i++) {
      final itemRes = await client.evaluate(isolateId, allItemsEval.id!, 'this[$i]');
      if (itemRes is InstanceRef) {
        print('  [$i] ${itemRes.valueAsString?.replaceAll('\n', ' ')}');
      }
    }
  }

  if (errorsEval is InstanceRef && errorsEval.length != null) {
    print('Error items (${errorsEval.length}):');
    final len = errorsEval.length!;
    for (var i = 0; i < len; i++) {
      final itemRes = await client.evaluate(isolateId, errorsEval.id!, 'this[$i]');
      if (itemRes is InstanceRef) {
        print('[$i] ${itemRes.valueAsString?.replaceAll('\n', ' ')}');
      }
    }
  }

  client.dispose();
  exit(0);
}
