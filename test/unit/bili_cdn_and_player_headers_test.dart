import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/bilibili/bilibili_service.dart';
import 'package:haipee/pages/player/player_controller.dart';

void main() {
  group('Bilibili CDN 节点优选与防 503 单元测试', () {
    test('优先从 backupUrl 中选择稳定的官方 UPOS 镜像节点，规避 mcdn 与 bcache 边缘节点', () {
      final dashVideoItem = <String, dynamic>{
        'id': 80,
        'baseUrl':
            'https://cn-zjhz-cm-01-08.bilivideo.com/upgcxcode/12/34/56.m4s?os=bcache& deadline=123',
        'backupUrl': [
          'https://xy123x45x67x89xy.mcdn.bilivideo.cn:4483/upgcxcode/12/34/56.m4s?os=mcdn',
          'https://upos-sz-mirrorcos.bilivideo.com/upgcxcode/12/34/56.m4s?os=cosbv',
        ],
      };

      final chosen = BilibiliService.selectBestCdnUrl(dashVideoItem);
      expect(
        chosen,
        equals(
          'https://upos-sz-mirrorcos.bilivideo.com/upgcxcode/12/34/56.m4s?os=cosbv',
        ),
      );
    });

    test('支持 snake_case 字段 (base_url / backup_url) 及 durl 单流字段', () {
      final snakeCaseItem = <String, dynamic>{
        'base_url':
            'https://xy111.mcdn.bilivideo.cn:8082/upgcxcode/aa/bb/cc.m4s?os=mcdn',
        'backup_url': [
          'https://upos-sz-mirrorhw.bilivideo.com/upgcxcode/aa/bb/cc.m4s?os=hwbv',
        ],
      };

      expect(
        BilibiliService.selectBestCdnUrl(snakeCaseItem),
        equals(
          'https://upos-sz-mirrorhw.bilivideo.com/upgcxcode/aa/bb/cc.m4s?os=hwbv',
        ),
      );
    });

    test('当仅存在边缘节点而无 UPOS 备份时，优雅兜底返回首个可用地址而不返回空', () {
      final onlyEdgeItem = <String, dynamic>{
        'baseUrl':
            'https://cn-zjhz-cm-01-08.bilivideo.com/upgcxcode/12/34/56.m4s?os=bcache',
      };

      expect(
        BilibiliService.selectBestCdnUrl(onlyEdgeItem),
        equals(
          'https://cn-zjhz-cm-01-08.bilivideo.com/upgcxcode/12/34/56.m4s?os=bcache',
        ),
      );
    });
  });

  group('PlayerController HTTP 请求头去重与 mpv 属性防重测试', () {
    test('buildNormalizedHttpHeaders 消除不同大小写的 User-Agent 与 Referer 冲突', () {
      final headers = PlayerController.buildNormalizedHttpHeaders(
        defaultUserAgent: 'DefaultUA/1.0',
        defaultReferer: 'https://default.example.com',
        overrideHeaders: {
          'user-agent': 'BiliCustomUA/2.0',
          'referer': 'https://www.bilibili.com',
          'Origin': 'https://www.bilibili.com',
          'origin': 'https://space.bilibili.com',
        },
      );

      // 确保不会同时存在 'user-agent' 和 'User-Agent'
      final uaKeys = headers.keys
          .where((k) => k.toLowerCase() == 'user-agent')
          .toList();
      final refKeys =
          headers.keys.where((k) => k.toLowerCase() == 'referer').toList();
      final originKeys =
          headers.keys.where((k) => k.toLowerCase() == 'origin').toList();

      expect(uaKeys, equals(['User-Agent']));
      expect(refKeys, equals(['Referer']));
      expect(originKeys.length, equals(1));
      expect(headers['User-Agent'], equals('BiliCustomUA/2.0'));
      expect(headers['Referer'], equals('https://www.bilibili.com'));
      expect(headers[originKeys.single], equals('https://space.bilibili.com'));
    });

    test('extractExtraMpvHeaders 剥离已由 mpv 原生属性承载的 User-Agent 与 Referer', () {
      final normalized = PlayerController.buildNormalizedHttpHeaders(
        defaultUserAgent: 'Mozilla/5.0',
        overrideHeaders: {
          'Referer': 'https://www.bilibili.com',
          'User-Agent': 'Mozilla/5.0 Bili',
        },
      );

      final extraForBili = PlayerController.extractExtraMpvHeaders(normalized);
      expect(
        extraForBili,
        isEmpty,
        reason:
            'B站 CDN 仅需 User-Agent 与 Referer（已通过 mpv user-agent/referrer 属性设置），extraMpvHeaders 必须为空以防 media_kit 重复注入 http-header-fields！',
      );

      final normalizedWithAuth = PlayerController.buildNormalizedHttpHeaders(
        defaultUserAgent: 'Mozilla/5.0',
        overrideHeaders: {
          'Referer': 'https://vod.example.com',
          'Authorization': 'Bearer token123',
          'X-Playback-Session': 'abc',
        },
      );
      final extraWithAuth =
          PlayerController.extractExtraMpvHeaders(normalizedWithAuth);
      expect(extraWithAuth, equals({
        'Authorization': 'Bearer token123',
        'X-Playback-Session': 'abc',
      }));
    });
  });
}
