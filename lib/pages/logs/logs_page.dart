import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/providers/riverpod_compat.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:kazumi/bean/appbar/sys_app_bar.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';

/// Provider for log file content
final logFileContentProvider = StateProvider.autoDispose<String>((ref) => '');

class LogsPage extends ConsumerStatefulWidget {
  const LogsPage({super.key});

  @override
  ConsumerState<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends ConsumerState<LogsPage> {
  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final file = await _getLogsFile();
    if (await file.exists()) {
      final content = await file.readAsString();
      if (!mounted) return;
      ref.read(logFileContentProvider.notifier).state = content;
    }
  }

  Future<File> _getLogsFile() async {
    final directory = await getApplicationSupportDirectory();
    final path = directory.path;
    return File('$path/logs/kazumi_logs.log');
  }

  Future<void> _clearLogs() async {
    try {
      final file = await _getLogsFile();
      await file.writeAsString('');
      if (!mounted) return;
      ref.read(logFileContentProvider.notifier).state = '';
      KazumiDialog.showToast(
        message: context.t.settings.about.logs.toast.cleared,
      );
    } catch (_) {
      if (!mounted) return;
      KazumiDialog.showToast(
        message: context.t.settings.about.logs.toast.clearFailed,
      );
    }
  }

  Future<void> _copyLogs() async {
    final fileContent = ref.read(logFileContentProvider);
    await Clipboard.setData(ClipboardData(text: fileContent));
    if (!mounted) return;
    KazumiDialog.showToast(
      message: context.t.playback.toast.clipboardCopied,
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileContent = ref.watch(logFileContentProvider);

    return SelectionArea(
        child: Scaffold(
      appBar: SysAppBar(
        title: Text(context.t.settings.about.logs.title),
      ),
      body: fileContent.isEmpty
          ? Center(
              child: Text(context.t.settings.about.logs.empty),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Text(fileContent),
            ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: null,
            onPressed: _clearLogs,
            child: const Icon(Icons.clear_all),
          ),
          const SizedBox(width: 15),
          FloatingActionButton(
            heroTag: null,
            onPressed: _copyLogs,
            child: const Icon(Icons.copy),
          ),
        ],
      ),
    ));
  }
}
