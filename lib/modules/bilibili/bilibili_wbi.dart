import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

/// Bilibili WBI 签名逆向算法与混淆映射
class BiliWbiSigner {
  static const List<int> _mixinKeyEncTab = [
    46, 47, 18, 2, 53, 8, 23, 32, 15, 50, 10, 31, 58, 3, 45, 35, 27, 43, 5, 49,
    33, 9, 42, 19, 29, 28, 14, 39, 12, 38, 41, 13, 37, 48, 7, 16, 24, 55, 40,
    61, 26, 17, 0, 1, 60, 51, 30, 4, 22, 25, 54, 21, 56, 59, 6, 63, 57, 62, 11,
    36, 20, 34, 44, 52
  ];

  // 默认备用密钥 (当网络请求无法获取时保底)
  static const String defaultImgKey = '7cd0844827f3484483e71c8bad20a280';
  static const String defaultSubKey = '5113a535c3b045e4ac54a49fe05fa5f7';

  static String? _cachedImgKey;
  static String? _cachedSubKey;
  static DateTime? _keyCacheTime;

  /// 根据 mixinKeyEncTab 计算 32 位混淆后的密钥
  static String getMixinKey(String origKey) {
    final buffer = StringBuffer();
    for (int i = 0; i < 32; i++) {
      if (i < _mixinKeyEncTab.length && _mixinKeyEncTab[i] < origKey.length) {
        buffer.write(origKey[_mixinKeyEncTab[i]]);
      }
    }
    return buffer.toString();
  }

  /// 异步从 B站 /x/web-interface/nav 接口动态提取最新的 WBI 密钥对
  static Future<(String, String)> getWbiKeys({Dio? dio}) async {
    final now = DateTime.now();
    if (_cachedImgKey != null &&
        _cachedSubKey != null &&
        _keyCacheTime != null &&
        now.difference(_keyCacheTime!).inHours < 12) {
      return (_cachedImgKey!, _cachedSubKey!);
    }

    try {
      final client = dio ?? Dio();
      final response = await client.get<Map<String, dynamic>>(
        'https://api.bilibili.com/x/web-interface/nav',
        options: Options(
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': 'https://www.bilibili.com',
          },
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );

      final data = response.data?['data'];
      final wbiImg = data?['wbi_img'];
      if (wbiImg != null) {
        final imgUrl = wbiImg['img_url']?.toString() ?? '';
        final subUrl = wbiImg['sub_url']?.toString() ?? '';

        final imgKey = _extractKeyFromUrl(imgUrl);
        final subKey = _extractKeyFromUrl(subUrl);

        if (imgKey.isNotEmpty && subKey.isNotEmpty) {
          _cachedImgKey = imgKey;
          _cachedSubKey = subKey;
          _keyCacheTime = now;
          return (imgKey, subKey);
        }
      }
    } catch (_) {
      // 容错降级
    }

    return (defaultImgKey, defaultSubKey);
  }

  static String _extractKeyFromUrl(String url) {
    if (url.isEmpty) return '';
    final filename = url.split('/').last;
    final dotIdx = filename.lastIndexOf('.');
    return dotIdx != -1 ? filename.substring(0, dotIdx) : filename;
  }

  /// 为请求参数附加 wts 时间戳与 w_rid 签名
  static Map<String, dynamic> signParams(
    Map<String, dynamic> params, {
    String? imgKey,
    String? subKey,
  }) {
    final effectiveImgKey = imgKey ?? defaultImgKey;
    final effectiveSubKey = subKey ?? defaultSubKey;
    final mixinKey = getMixinKey(effectiveImgKey + effectiveSubKey);

    final signed = Map<String, dynamic>.from(params);
    final wts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    signed['wts'] = wts;

    // 按 key 升序排序
    final sortedKeys = signed.keys.toList()..sort();

    // 过滤保留字符: ! ' ( ) *
    String filterValue(String val) {
      return val.replaceAll(RegExp(r"[!'()*]"), '');
    }

    final queryList = <String>[];
    for (final key in sortedKeys) {
      final value = signed[key];
      if (value != null) {
        final filtered = filterValue(value.toString());
        queryList.add('${Uri.encodeQueryComponent(key)}=${Uri.encodeQueryComponent(filtered)}');
      }
    }

    final queryString = queryList.join('&');
    final wRid = md5.convert(utf8.encode(queryString + mixinKey)).toString();
    signed['w_rid'] = wRid;

    return signed;
  }
}
