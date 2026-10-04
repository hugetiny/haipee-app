import 'package:dio/dio.dart';
import 'package:kazumi/request/api.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/utils/constants.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';

class ApiInterceptor extends Interceptor {
  static Box setting = GStorage.setting;
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Github mirror
    if (options.path.contains('github')) {
      bool enableGitProxy =
          setting.get(SettingBoxKey.enableGitProxy, defaultValue: false);
      if (enableGitProxy) {
        options.path = Api.gitMirror + options.path;
      }
    }
    if (options.path.contains(Api.dandanAPIDomain)) {
      var timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final String appId = GStorage.readDanDanAppId();
      options.headers = {
        'user-agent': Utils.getRandomUA(),
        'referer': '',
        'X-Auth': 1,
        'X-AppId': appId,
        'X-Timestamp': timestamp,
        'X-Signature': Utils.generateDandanSignature(
            Uri.parse(options.path).path, timestamp),
      };
    }
    if (options.path.contains(Api.bangumiAPIDomain) ||
        options.path.contains(Api.bangumiAPINextDomain)) {
      options.headers = bangumiHTTPHeader;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    String url = err.requestOptions.uri.toString();
    if (!url.contains('heartBeat') &&
        err.requestOptions.extra['customError'] != '') {
      if (err.requestOptions.extra['customError'] == null) {
        KazumiDialog.showToast(
          message: await dioError(err),
        );
      } else {
        KazumiDialog.showToast(
          message: err.requestOptions.extra['customError'],
        );
      }
    }
    super.onError(err, handler);
  }

  static Future<String> dioError(DioException error) async {
    final errorTexts = t.network.error;
    switch (error.type) {
      case DioExceptionType.badCertificate:
        return errorTexts.badCertificate;
      case DioExceptionType.badResponse:
        return errorTexts.badResponse;
      case DioExceptionType.cancel:
        return errorTexts.cancel;
      case DioExceptionType.connectionError:
        return errorTexts.connection;
      case DioExceptionType.connectionTimeout:
        return errorTexts.connectionTimeout;
      case DioExceptionType.receiveTimeout:
        return errorTexts.receiveTimeout;
      case DioExceptionType.sendTimeout:
        return errorTexts.sendTimeout;
      case DioExceptionType.transformTimeout:
        return errorTexts.sendTimeout;
      case DioExceptionType.unknown:
        final String res = await checkConnect();
        return errorTexts.unknown.replaceFirst('{status}', res);
    }
  }

  static Future<String> checkConnect() async {
    final statusTexts = t.network.status;
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.mobile)) {
      return statusTexts.mobile;
    }
    if (connectivityResult.contains(ConnectivityResult.wifi)) {
      return statusTexts.wifi;
    }
    if (connectivityResult.contains(ConnectivityResult.ethernet)) {
      return statusTexts.ethernet;
    }
    if (connectivityResult.contains(ConnectivityResult.vpn)) {
      return statusTexts.vpn;
    }
    if (connectivityResult.contains(ConnectivityResult.other)) {
      return statusTexts.other;
    }
    if (connectivityResult.contains(ConnectivityResult.none)) {
      return statusTexts.none;
    }
    return '';
  }
}
