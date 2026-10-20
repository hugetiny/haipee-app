import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/request/core/bangumi_transport.dart';
import 'package:kazumi/request/core/dio_logger_interceptor.dart';
import 'package:kazumi/request/core/git_proxy_interceptor.dart';
import 'package:kazumi/request/core/network_config.dart';
import 'package:kazumi/request/interceptor.dart';
import 'package:kazumi/utils/utils.dart';

class Request {
  static final Request _instance = Request._internal();
  static late final Dio dio;
  factory Request() => _instance;

  // 初始化 （一般只在应用启动时调用）
  static Future<void> setCookie() async {
    setOptionsHeaders();
  }

  // 设置请求头
  static void setOptionsHeaders() {
    dio.options.headers['referer'] = '';
    dio.options.headers['user-agent'] = Utils.getRandomUA();
  }

  // 禁用代理
  static void disableProxy() {
    dio.httpClientAdapter = BangumiEchAdapter(
      fallback: IOHttpClientAdapter(
        createHttpClient: () {
          final HttpClient client = HttpClient();
          return client;
        },
      ),
      config: NetworkConfig(),
    );
    debugPrint('代理禁用');
  }

  Request._internal() {
    BaseOptions options = BaseOptions(
      baseUrl: '',
      connectTimeout: const Duration(milliseconds: 12000),
      receiveTimeout: const Duration(milliseconds: 12000),
      headers: {
        'user-agent': Utils.getRandomUA(),
      },
    );

    final defaultAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final HttpClient client = HttpClient();
        client.badCertificateCallback = (cert, host, port) => true;
        client.findProxy = HttpClient.findProxyFromEnvironment;
        return client;
      },
    );

    dio = Dio(options);
    dio.httpClientAdapter = BangumiEchAdapter(
      fallback: defaultAdapter,
      config: NetworkConfig(),
    );

    // 拦截器
    dio.interceptors.add(GitProxyInterceptor());
    dio.interceptors.add(BangumiAccelerationInterceptor());
    dio.interceptors.add(ApiInterceptor());

    // 统一日志拦截器，直接对接 Talker / AppLog
    dio.interceptors.add(DioLoggerInterceptor());

    dio.transformer = BackgroundTransformer();
    dio.options.validateStatus = (int? status) {
      return status! >= 200 && status < 300;
    };
  }

  Future<Response> get(url,
      {data, options, cancelToken, extra, bool shouldRethrow = false}) async {
    Response response;
    ResponseType resType = ResponseType.json;
    options ??= Options();
    if (extra != null) {
      resType = extra['resType'] ?? ResponseType.json;
      if (extra['ua'] != null) {
        options.headers = {'user-agent': headerUa(type: extra['ua'])};
      }
      options.extra ??= <String, dynamic>{};
      if (extra is Map) {
        options.extra!.addAll(Map<String, dynamic>.from(extra));
      }
    }
    options.responseType = resType;
    try {
      response = await dio.get(
        url,
        queryParameters: data,
        options: options,
        cancelToken: cancelToken,
      );
      return response;
    } on DioException catch (e) {
      if (shouldRethrow) {
        rethrow;
      }
      Response errResponse = Response(
        data: {
          'message': await ApiInterceptor.dioError(e)
        }, // 将自定义 Map 数据赋值给 Response 的 data 属性
        statusCode: 200,
        requestOptions: RequestOptions(),
      );
      return errResponse;
    }
  }

  Future<Response> post(url,
      {data,
      queryParameters,
      options,
      cancelToken,
      extra,
      bool shouldRethrow = false}) async {
    Response response;
    options ??= Options();
    if (extra != null) {
      options.extra ??= <String, dynamic>{};
      if (extra is Map) {
        options.extra!.addAll(Map<String, dynamic>.from(extra));
      }
    }
    try {
      response = await dio.post(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      return response;
    } on DioException catch (e) {
      if (shouldRethrow) {
        rethrow;
      }
      Response errResponse = Response(
        data: {
          'message': await ApiInterceptor.dioError(e)
        }, // 将自定义 Map 数据赋值给 Response 的 data 属性
        statusCode: 200,
        requestOptions: RequestOptions(),
      );
      return errResponse;
    }
  }

  String headerUa({type = 'mob'}) {
    return Utils.getRandomUA();
  }
}
