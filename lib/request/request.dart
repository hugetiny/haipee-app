import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
// import 'package:hive/hive.dart';
// import 'package:kazumi/utils/storage.dart';
import 'package:kazumi/request/interceptor.dart';
import 'package:kazumi/utils/utils.dart';

class Request {
  static final Request _instance = Request._internal();
  static late final Dio dio;
  static late final CacheStore cacheStore;
  static late final CacheOptions cacheOptions;
  // Box setting = GStorage.setting;
  // static Box localCache = GStorage.localCache;
  // late bool enableSystemProxy;
  factory Request() => _instance;


  static Future<void> init() async {
    cacheStore = MemCacheStore();

    cacheOptions = CacheOptions(
      store: cacheStore,
      policy: CachePolicy.request, // 优先使用有效缓存（1小时内），过期或无缓存则请求网络
      maxStale: const Duration(minutes: 5), // 缓存有效期改为 5 分钟
      priority: CachePriority.normal,
      cipher: null,
      keyBuilder: CacheOptions.defaultCacheKeyBuilder,
      allowPostMethod: true,
    );

    dio.interceptors.add(DioCacheInterceptor(options: cacheOptions));
    await setCookie();
  }

  // 设置 Cookie (保留旧方法兼容)
  static Future<void> setCookie() async {
    setOptionsHeaders();
  }

  // 设置请求头
  static void setOptionsHeaders() {
    dio.options.headers['referer'] = '';
    dio.options.headers['user-agent'] = Utils.getRandomUA();
  }

  // 设置代理
  static void setProxy() {
    // var systemProxyHost =
    //     localCache.get(LocalCacheKey.systemProxyHost, defaultValue: '');
    // var systemProxyPort =
    //     localCache.get(LocalCacheKey.systemProxyPort, defaultValue: '');
    // dio.httpClientAdapter = IOHttpClientAdapter(
    //     createHttpClient: () {
    //       final HttpClient client = HttpClient();
    //       // Config the client.
    //       client.findProxy = (Uri uri) {
    //         // return 'PROXY host:port';
    //         return 'PROXY $systemProxyHost:$systemProxyPort';
    //       };
    //       client.badCertificateCallback =
    //           (X509Certificate cert, String host, int port) => true;
    //       return client;
    //     },
    //   );
    // debugPrint('代理设置更新成功');
  }

  // 禁用代理
  static void disableProxy() {
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final HttpClient client = HttpClient();
        return client;
      },
    );
    debugPrint('代理禁用');
  }

  Request._internal() {
    //BaseOptions、Options、RequestOptions 都可以配置参数，优先级别依次递增，且可以根据优先级别覆盖参数
    BaseOptions options = BaseOptions(
      //请求基地址,可以包含子路径
      baseUrl: '',
      //连接服务器超时时间，单位是毫秒.
      connectTimeout: const Duration(milliseconds: 12000),
      //响应流上前后两次接受到数据的间隔，单位为毫秒。
      receiveTimeout: const Duration(milliseconds: 12000),
      //Http请求头.
      headers: {},
    );

    // enableSystemProxy = setting.get(SettingBoxKey.enableSystemProxy,
    //     defaultValue: false) as bool;

    dio = Dio(options);
    // debugPrint('Dio 初始化完成');

    // if (enableSystemProxy) {
    //   setProxy();
    //   debugPrint('系统代理启用');
    // }

    // 拦截器
    dio.interceptors.add(ApiInterceptor());

    // 缓存拦截器初始化移至 init() 方法中，避免同步构造函数问题
    // dio.interceptors.add(DioCacheInterceptor(options: cacheOptions));

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
    // print('post-data: $data');
    Response response;
    try {
      response = await dio.post(
        url,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
      // print('post success: ${response.data}');
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
