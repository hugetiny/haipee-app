import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:kazumi/request/api.dart';
import 'package:kazumi/request/core/dio_factory.dart';
import 'package:kazumi/request/core/git_proxy_interceptor.dart';
import 'package:kazumi/request/request.dart';
import 'package:kazumi/utils/storage.dart';

void main() {
  late Directory tempDir;
  late Box settingBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('git_proxy_test');
    Hive.init(tempDir.path);
    settingBox = await Hive.openBox('setting');
    GStorage.setting = settingBox;
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  setUp(() async {
    await settingBox.clear();
  });

  group('GitProxyInterceptor 核心重写与逻辑验证', () {
    test('默认状态下未启用代理，URL 保持原样不重写', () {
      expect(GitProxyInterceptor.isEnabled(), isFalse);

      const target = 'https://raw.githubusercontent.com/Predidit/KazumiRules/main/index.json';
      final result = GitProxyInterceptor.applyProxy(target);
      expect(result, equals(target));
    });

    test('启用代理后，GitHub 相关域名均被正确重写且前置生效代理地址', () async {
      await GitProxyInterceptor.setEnabled(true);
      expect(GitProxyInterceptor.isEnabled(), isTrue);
      expect(GitProxyInterceptor.getEffectiveProxyUrl(), equals('https://ghfast.top/'));

      // 1. Kazumi 视频规则 raw URL
      const kazumiRuleUrl = 'https://raw.githubusercontent.com/Predidit/KazumiRules/main/index.json';
      expect(
        GitProxyInterceptor.applyProxy(kazumiRuleUrl),
        equals('https://ghfast.top/https://raw.githubusercontent.com/Predidit/KazumiRules/main/index.json'),
      );

      // 2. Cardigann 种子规则 Prowlarr GitHub raw URL
      const cardigannUrl = 'https://raw.githubusercontent.com/Prowlarr/Indexers/master/definitions/v11/nyaasi.yml';
      expect(
        GitProxyInterceptor.applyProxy(cardigannUrl),
        equals('https://ghfast.top/https://raw.githubusercontent.com/Prowlarr/Indexers/master/definitions/v11/nyaasi.yml'),
      );

      // 3. GitHub API 接口
      const apiUrl = 'https://api.github.com/repos/Predidit/Kazumi/releases/latest';
      expect(
        GitProxyInterceptor.applyProxy(apiUrl),
        equals('https://ghfast.top/https://api.github.com/repos/Predidit/Kazumi/releases/latest'),
      );

      // 4. GitHub 主站与 github.io
      const repoUrl = 'https://github.com/Predidit/Kazumi';
      expect(
        GitProxyInterceptor.applyProxy(repoUrl),
        equals('https://ghfast.top/https://github.com/Predidit/Kazumi'),
      );
    });

    test('非 GitHub 域名无论是否开启代理均不被篡改', () async {
      await GitProxyInterceptor.setEnabled(true);

      const bangumiUrl = 'https://api.bgm.tv/v0/subjects/12345';
      expect(GitProxyInterceptor.applyProxy(bangumiUrl), equals(bangumiUrl));

      const dandanUrl = 'https://api.dandanplay.net/api/v2/comment/123';
      expect(GitProxyInterceptor.applyProxy(dandanUrl), equals(dandanUrl));

      const maccmsUrl = 'https://cj.vod.com/api.php/provide/vod/?ac=detail';
      expect(GitProxyInterceptor.applyProxy(maccmsUrl), equals(maccmsUrl));
    });

    test('防重复包装机制：已带有预置镜像或当前镜像的 URL 不会被二次叠加', () async {
      await GitProxyInterceptor.setEnabled(true);

      // 已经带有 ghfast.top 前缀
      const alreadyProxied = 'https://ghfast.top/https://raw.githubusercontent.com/Predidit/KazumiRules/main/index.json';
      expect(GitProxyInterceptor.applyProxy(alreadyProxied), equals(alreadyProxied));

      // 已经带有 ghproxy.net 前缀
      const alreadyProxiedNet = 'https://ghproxy.net/https://raw.githubusercontent.com/Prowlarr/Indexers/master/definitions/v11/nyaasi.yml';
      expect(GitProxyInterceptor.applyProxy(alreadyProxiedNet), equals(alreadyProxiedNet));
    });

    test('用户自定义 GitHub 代理地址持久化与动态生效', () async {
      await GitProxyInterceptor.setEnabled(true);
      await GitProxyInterceptor.setProxyUrl('https://my-custom-proxy.internal');

      // 验证末尾斜杠自动补全
      expect(GitProxyInterceptor.getEffectiveProxyUrl(), equals('https://my-custom-proxy.internal/'));

      // 验证动态应用
      const url = 'https://raw.githubusercontent.com/sample/repo/main/rule.json';
      expect(
        GitProxyInterceptor.applyProxy(url),
        equals('https://my-custom-proxy.internal/https://raw.githubusercontent.com/sample/repo/main/rule.json'),
      );

      // 验证 Api.gitMirror 动态跟随
      expect(Api.gitMirror, equals('https://my-custom-proxy.internal/'));

      // 设置为空时自动恢复默认
      await GitProxyInterceptor.setProxyUrl('');
      expect(GitProxyInterceptor.getEffectiveProxyUrl(), equals('https://ghfast.top/'));
    });

    test('Dio 请求拦截器在 onRequest 阶段正确重写 path 与 baseUrl', () async {
      await GitProxyInterceptor.setEnabled(true);
      await GitProxyInterceptor.setProxyUrl('https://ghfast.top/');

      final interceptor = GitProxyInterceptor();

      // Case 1: 绝对路径 options.path
      final options1 = RequestOptions(
        path: 'https://raw.githubusercontent.com/Predidit/KazumiRules/main/index.json',
      );
      interceptor.onRequest(options1, RequestInterceptorHandler());
      expect(
        options1.path,
        equals('https://ghfast.top/https://raw.githubusercontent.com/Predidit/KazumiRules/main/index.json'),
      );

      // Case 2: baseUrl 模式
      final options2 = RequestOptions(
        baseUrl: 'https://api.github.com',
        path: '/repos/Predidit/Kazumi/releases/latest',
      );
      interceptor.onRequest(options2, RequestInterceptorHandler());
      expect(
        options2.baseUrl,
        equals('https://ghfast.top/https://api.github.com'),
      );
      expect(options2.path, equals('/repos/Predidit/Kazumi/releases/latest'));

      // Case 3: 非 GitHub 请求
      final options3 = RequestOptions(
        path: 'https://api.bgm.tv/v0/subjects/100',
      );
      interceptor.onRequest(options3, RequestInterceptorHandler());
      expect(options3.path, equals('https://api.bgm.tv/v0/subjects/100'));
    });

    test('全局 Request 与 DioFactory 均挂载了 GitProxyInterceptor', () {
      Request(); // 确保单例初始化
      final hasGitProxyInRequest = Request.dio.interceptors.any((i) => i is GitProxyInterceptor);
      expect(hasGitProxyInRequest, isTrue, reason: 'Request.dio 必须挂载最底层 GitProxyInterceptor');

      final apiDio = DioFactory.apiDio;
      expect(apiDio.interceptors.any((i) => i is GitProxyInterceptor), isTrue);

      final rulesRepoDio = DioFactory.rulesRepoDio;
      expect(rulesRepoDio.interceptors.any((i) => i is GitProxyInterceptor), isTrue);
    });
  });
}
