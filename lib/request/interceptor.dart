import 'package:dio/dio.dart';
import 'package:haipee/request/api.dart';
import 'package:hive_ce/hive.dart';
import 'package:haipee/utils/storage.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:haipee/utils/utils.dart';
import 'package:haipee/utils/constants.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/utils/logger.dart';
import 'package:logger/logger.dart' show Level;

class ApiInterceptor extends Interceptor {
  static Box setting = GStorage.setting;
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
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
    final dynamic customError = err.requestOptions.extra['customError'];
    final bool isSilent = err.requestOptions.extra['silent'] == true ||
        customError == '' ||
        customError == false;
    final bool showToast = err.requestOptions.extra['showToast'] == true;

    // Standardize error handling: silently record into unified logging architecture
    final respData = err.response?.data != null ? ' | Response: ${err.response?.data}' : '';
    HaipeeLogger().log(
      Level.warning,
      '网络请求失败 [${err.type}]: $url (${err.message ?? ""})$respData',
      error: err,
    );

    if (!url.contains('heartBeat') && !isSilent && showToast) {
      if (customError is String && customError.isNotEmpty) {
        HaipeeDialog.showToast(
          message: customError,
        );
      } else {
        HaipeeDialog.showToast(
          message: await dioError(err),
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
