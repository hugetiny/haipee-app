import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/bean/widget/error_widget.dart';
import 'package:haipee/modules/cardigann/models/cardigann_definition.dart';
import 'package:haipee/modules/cardigann/engine/cardigann_query_executor.dart';
import 'package:haipee/modules/cardigann/indexer_plugin_manager.dart';
import 'package:haipee/modules/search/search_history_dropdown.dart';
import 'package:haipee/modules/torrent_search/torrent_search_service.dart';
import 'package:haipee/request/core/dio_logger_interceptor.dart';
import 'package:haipee/services/logging/app_log.dart';
import 'package:haipee/utils/storage.dart';

import 'package:haipee/modules/torrent_search/models/torrent_item.dart';
import 'package:haipee/modules/torrent_search/sources/torrent_source.dart';

class _Fake521Adapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '<!DOCTYPE html><html><head><title>Web server is down (521)</title></head></html>',
      521,
      headers: {
        Headers.contentTypeHeader: [Headers.textPlainContentType],
      },
      statusMessage: 'Web server is down',
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeHandshakeExceptionAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.unknown,
      error: const HandshakeException('Connection terminated during handshake'),
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MockIndexerPluginsNotifier extends IndexerPluginsNotifier {
  @override
  IndexerPluginState build() => const IndexerPluginState();
}

class _CountingFakeSource implements TorrentSource {
  int callCount = 0;

  @override
  String get name => 'FakeSource';

  @override
  TorrentSourceType get type => TorrentSourceType.mikan;

  @override
  bool get enabled => true;

  @override
  Future<List<TorrentItem>> search(String keyword) async {
    callCount++;
    await Future.delayed(const Duration(milliseconds: 30));
    return [
      TorrentItem(
        title: 'Fake Title $keyword',
        magnetUrl: 'magnet:?xt=urn:btih:fake_$keyword',
        source: TorrentSourceType.mikan,
      ),
    ];
  }
}

class _PaintErrorWidget extends LeafRenderObjectWidget {
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPaintError();
}

class _RenderPaintError extends RenderBox {
  bool _hasRecorded = false;

  @override
  void performLayout() {
    size = constraints.constrain(const Size(100, 100));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!_hasRecorded) {
      _hasRecorded = true;
      AppLog.recordError();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  const sampleYaml = '''
---
id: thepiratebay_test
name: The Pirate Bay Test
language: en-US
type: public
links:
  - https://thepiratebay.org/

caps:
  categorymappings:
    - {id: 200, cat: 5000, desc: "Video"}

search:
  paths:
    - path: /search/{{ .Keywords }}/1/99/0
  rows:
    selector: tr
  fields:
    title:
      selector: td:nth-child(2)
    download:
      selector: a[href^="magnet:"]
      attribute: href
''';

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('six_log_errors_test');
    Hive.init(tempDir.path);
    GStorage.setting = await Hive.openBox('setting');
    GStorage.indexerPlugins = await Hive.openBox('indexerPlugins');
    GStorage.indexerRepos = await Hive.openBox('indexerRepos');
    GStorage.searchHistory = await Hive.openBox('searchHistory');
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('6 Log Errors Comprehensive Regression Tests', () {
    test('1. CardigannQueryExecutor: HTTP 521 (Cloudflare) is handled cleanly without bad response crash', () async {
      final dio = Dio(BaseOptions(validateStatus: (s) => s != null && s < 600));
      dio.httpClientAdapter = _Fake521Adapter();

      final executor = CardigannQueryExecutor(dio: dio);
      final def = CardigannParser.parseYaml(sampleYaml);

      AppLog.resetErrorCount();
      final initialErrorCount = AppLog.errorCount;

      final results = await executor.search(def, 'pianoglow', throwOnError: false);
      expect(results, isEmpty);

      // Verify no application fatal errors were recorded
      expect(AppLog.errorCount, equals(initialErrorCount));
    });

    test('2. CardigannQueryExecutor: HandshakeException (TLS Reset) logs as warning, not fatal error', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeHandshakeExceptionAdapter();

      final executor = CardigannQueryExecutor(dio: dio);
      final def = CardigannParser.parseYaml(sampleYaml);

      AppLog.resetErrorCount();
      final initialErrorCount = AppLog.errorCount;

      final results = await executor.search(def, '0magnet', throwOnError: false);
      expect(results, isEmpty);

      // Verify error count does not increase for standard network firewall resets
      expect(AppLog.errorCount, equals(initialErrorCount));
    });

    test('3. TorrentSearchNotifier: Prevents duplicate parallel searches for identical query', () async {
      final fakeSource = _CountingFakeSource();
      final testService = TorrentSearchService(sources: [fakeSource]);

      final container = ProviderContainer(
        overrides: [
          torrentSearchProvider.overrideWith(
            () => TorrentSearchNotifier(service: testService),
          ),
          indexerPluginsProvider.overrideWith(_MockIndexerPluginsNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(torrentSearchProvider.notifier);

      // Trigger first search
      final future1 = notifier.search('pianoglow');
      expect(container.read(torrentSearchProvider).isLoading, isTrue);

      // Immediate duplicate trigger while in flight
      final future2 = notifier.search('pianoglow');

      await Future.wait([future1, future2]);

      expect(container.read(torrentSearchProvider).isLoading, isFalse);
      expect(container.read(torrentSearchProvider).keyword, equals('pianoglow'));
      // Verifies only 1 search operation was dispatched to the underlying source
      expect(fakeSource.callCount, equals(1));
    });

    testWidgets('4. AppLog.recordError: Asynchronous safety prevents Build scheduled during frame when called in paint callback', (tester) async {
      AppLog.resetErrorCount();
      expect(AppLog.errorCount, equals(0));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: AppLog.listenable,
              builder: (context, _) {
                return _PaintErrorWidget();
              },
            ),
          ),
        ),
      );

      // Verify no 'Build scheduled during frame' exception was thrown
      expect(tester.takeException(), isNull);
      await tester.pumpAndSettle();
      expect(AppLog.errorCount, equals(1));
    });

    test('5. DioLoggerInterceptor: Network failures logged as warnings, never as fatal app error', () async {
      AppLog.resetErrorCount();
      final dio = Dio();
      dio.interceptors.add(DioLoggerInterceptor());
      dio.httpClientAdapter = _FakeHandshakeExceptionAdapter();

      try {
        await dio.get('https://dm.xifanacg.com/search.html?wd=fx');
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 50));
      expect(AppLog.errorCount, equals(0));
    });

    testWidgets('6. GeneralErrorWidget: Zero RenderFlex overflow even with small container & high font scale', (tester) async {
      tester.view.physicalSize = const Size(280, 200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: const Scaffold(
            body: SizedBox(
              height: 180,
              width: 250,
              child: GeneralErrorWidget(
                errMsg: 'Very long diagnostic error message: HandshakeException Connection terminated during TLS handshake on remote indexer',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('复制报错信息'), findsOneWidget);
    });

    testWidgets('7. SearchHistoryDropdown: Renders reliably without debugNeedsLayout assert failure', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final textController = TextEditingController(text: 'test');
      final focusNode = FocusNode();
      addTearDown(textController.dispose);
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SearchHistoryDropdown(
                controller: textController,
                focusNode: focusNode,
                onSelectKeyword: (_) {},
                child: TextField(
                  controller: textController,
                  focusNode: focusNode,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      focusNode.requestFocus();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
