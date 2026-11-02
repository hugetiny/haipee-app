import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:haipee/modules/torrent_search/models/torrent_file_entry.dart';

/// 种子元数据解析结果
class ParsedTorrent {
  final String name;
  final int totalBytes;
  final int pieceLength;
  final List<TorrentFileEntry> files;
  final String? announce;
  final String? comment;

  ParsedTorrent({
    required this.name,
    required this.totalBytes,
    required this.pieceLength,
    required this.files,
    this.announce,
    this.comment,
  });

  bool get isMultiFile => files.length > 1;
}

/// 纯 Dart 实现的轻量 Bencode 解析器与 .torrent 文件解码器
/// 无需依赖外部 C++ 库，0ms 秒级解析本地种子文件与拖入的 .torrent
class TorrentFileParser {
  /// 从文件解析
  static Future<ParsedTorrent> parseFile(File file) async {
    final bytes = await file.readAsBytes();
    return parseBytes(bytes);
  }

  /// 从字节流解析
  static ParsedTorrent parseBytes(Uint8List bytes) {
    final decoder = _BencodeDecoder(bytes);
    final dynamic root = decoder.decode();

    if (root is! Map<String, dynamic>) {
      throw const FormatException('无效的 Torrent 格式：根节点必须为 Bencode Dictionary');
    }

    final info = root['info'];
    if (info is! Map<String, dynamic>) {
      throw const FormatException('无效的 Torrent 格式：缺少 info 字典');
    }

    final String name = _extractString(info['name.utf-8']) ??
        _extractString(info['name']) ??
        '未知种子';

    final int pieceLength = (info['piece length'] as num?)?.toInt() ?? 0;
    final String? announce = _extractString(root['announce']);
    final String? comment = _extractString(root['comment.utf-8']) ??
        _extractString(root['comment']);

    final List<TorrentFileEntry> entries = [];
    int totalBytes = 0;

    if (info.containsKey('files')) {
      // 多文件种子 (Multi-file torrent)
      final rawFiles = info['files'] as List<dynamic>? ?? [];
      for (int i = 0; i < rawFiles.length; i++) {
        final f = rawFiles[i];
        if (f is! Map<String, dynamic>) continue;

        final int length = (f['length'] as num?)?.toInt() ?? 0;
        totalBytes += length;

        final pathList = (f['path.utf-8'] as List<dynamic>?) ??
            (f['path'] as List<dynamic>?) ??
            [];

        final segments = pathList
            .map((seg) => _extractString(seg))
            .where((s) => s != null && s.isNotEmpty)
            .cast<String>()
            .toList();

        final fileName = segments.isNotEmpty ? segments.last : '文件 ${i + 1}';
        final fullPath = segments.isNotEmpty ? segments.join('/') : fileName;

        entries.add(
          TorrentFileEntry(
            index: i + 1, // 1-based index
            path: fullPath,
            name: fileName,
            sizeBytes: length,
            pathSegments: segments.isNotEmpty ? segments : [fileName],
            isSelected: true,
          ),
        );
      }
    } else {
      // 单文件种子 (Single-file torrent)
      final int length = (info['length'] as num?)?.toInt() ?? 0;
      totalBytes = length;
      entries.add(
        TorrentFileEntry(
          index: 1,
          path: name,
          name: name,
          sizeBytes: length,
          pathSegments: [name],
          isSelected: true,
        ),
      );
    }

    return ParsedTorrent(
      name: name,
      totalBytes: totalBytes,
      pieceLength: pieceLength,
      files: entries,
      announce: announce,
      comment: comment,
    );
  }

  static String? _extractString(dynamic val) {
    if (val == null) return null;
    if (val is String) return val;
    if (val is List<int>) {
      try {
        return utf8.decode(val);
      } catch (_) {
        return latin1.decode(val);
      }
    }
    return val.toString();
  }
}

class _BencodeDecoder {
  final Uint8List _bytes;
  int _offset = 0;

  _BencodeDecoder(this._bytes);

  dynamic decode() {
    if (_offset >= _bytes.length) return null;
    final byte = _bytes[_offset];

    if (byte == 0x69) {
      // 'i' -> integer
      return _decodeInt();
    } else if (byte == 0x6C) {
      // 'l' -> list
      return _decodeList();
    } else if (byte == 0x64) {
      // 'd' -> dictionary
      return _decodeDict();
    } else if (byte >= 0x30 && byte <= 0x39) {
      // '0'..'9' -> byte string
      return _decodeStringOrBytes();
    } else {
      throw FormatException(
        'Bencode 解码错误：未知标记 0x${byte.toRadixString(16)} (偏移量: $_offset)',
      );
    }
  }

  int _decodeInt() {
    _offset++; // skip 'i'
    final start = _offset;
    while (_offset < _bytes.length && _bytes[_offset] != 0x65) {
      _offset++;
    }
    if (_offset >= _bytes.length) {
      throw const FormatException('Bencode 格式错误：整数未以 "e" 结尾');
    }
    final str = ascii.decode(_bytes.sublist(start, _offset));
    _offset++; // skip 'e'
    return int.parse(str);
  }

  dynamic _decodeStringOrBytes() {
    final colonIdx = _bytes.indexOf(0x3A, _offset); // ':'
    if (colonIdx == -1) {
      throw const FormatException('Bencode 格式错误：字符串长度后缺少冒号 ":"');
    }
    final lengthStr = ascii.decode(_bytes.sublist(_offset, colonIdx));
    final length = int.parse(lengthStr);

    final dataStart = colonIdx + 1;
    final dataEnd = dataStart + length;
    if (dataEnd > _bytes.length) {
      throw const FormatException('Bencode 格式错误：字符串长度超出数据流边界');
    }

    _offset = dataEnd;
    final sub = _bytes.sublist(dataStart, dataEnd);

    // 尝试转为 UTF-8 字符串；如果是纯二进制数据（如 pieces hashes）则保留 List<int>
    try {
      return utf8.decode(sub);
    } catch (_) {
      return sub;
    }
  }

  List<dynamic> _decodeList() {
    _offset++; // skip 'l'
    final list = <dynamic>[];
    while (_offset < _bytes.length && _bytes[_offset] != 0x65) {
      list.add(decode());
    }
    if (_offset >= _bytes.length) {
      throw const FormatException('Bencode 格式错误：列表未以 "e" 结尾');
    }
    _offset++; // skip 'e'
    return list;
  }

  Map<String, dynamic> _decodeDict() {
    _offset++; // skip 'd'
    final dict = <String, dynamic>{};
    while (_offset < _bytes.length && _bytes[_offset] != 0x65) {
      final key = decode();
      if (key is! String) {
        // 如果键是二进制，强制以 latin1 转为 String
        final keyStr = key is List<int> ? latin1.decode(key) : key.toString();
        dict[keyStr] = decode();
      } else {
        dict[key] = decode();
      }
    }
    if (_offset >= _bytes.length) {
      throw const FormatException('Bencode 格式错误：字典未以 "e" 结尾');
    }
    _offset++; // skip 'e'
    return dict;
  }
}
