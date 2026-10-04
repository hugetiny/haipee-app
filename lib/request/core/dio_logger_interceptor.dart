import 'package:kazumi/services/logging/logger.dart';
import 'package:talker_dio_logger/talker_dio_logger.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// Dio HTTP logger interceptor powered by [TalkerDioLogger].
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
}
