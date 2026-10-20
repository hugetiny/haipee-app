import 'package:dio/dio.dart';
import 'package:kazumi/services/logging/logger.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Dio HTTP logger interceptor powered by [TalkerDioLogger].
/// Safely logs HTTP traffic while treating external scraper/network failures as warnings
/// rather than fatal application errors.
class DioLoggerInterceptor extends TalkerDioLogger {
  DioLoggerInterceptor({Talker? talker})
      : super(
          talker: talker ?? KazumiLogger().talker,
          settings: const TalkerDioLoggerSettings(
            printRequestHeaders: false,
            printResponseHeaders: false,
            printResponseMessage: true,
            printRequestData: false,
            printResponseData: false,
          ),
        );

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err);
    if (!settings.enabled) return;
    try {
      final url = err.requestOptions.uri.toString();
      KazumiLogger().talker.warning(
        '[HTTP] $url (${err.type}): ${err.message ?? err.error}',
      );
    } catch (_) {}
  }
}
