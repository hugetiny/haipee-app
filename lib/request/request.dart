import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/request/core/bangumi_transport.dart';
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
      headers: {},
    );

    dio = Dio(options);
    dio.httpClientAdapter = BangumiEchAdapter(
      fallback: dio.httpClientAdapter,
      config: NetworkConfig(),
    );

    // 拦截器
    dio.interceptors.add(BangumiAccelerationInterceptor());
    dio.interceptors.add(ApiInterceptor());

    // 日志拦截器 输出请求、响应内容
    dio.interceptors.add(LogInterceptor(
      request: false,
      requestHeader: false,
      responseHeader: false,
    ));

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
      resType = extra!['resType'] ?? ResponseType.json;
      if (extra['ua'] != null) {
        options.headers = {'user-agent': headerUa(type: extra['ua'])};
      }
      if (extra['customError'] != null) {
        options.extra = {'customError': extra['customError']};
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
