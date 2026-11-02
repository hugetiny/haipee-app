import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:haipee/modules/torrent_search/models/torrent_file_entry.dart';
import 'package:haipee/modules/torrent_search/parser/torrent_file_parser.dart';

void main() {
  group('TorrentFileParser & Bencode Decoder Tests', () {
    test('正确解析单文件 Torrent 字典结构', () {
      // 构建一个简单的单文件 torrent bencode:
      // d4:infod4:name8:test.mkv6:lengthi1048576ee8:announce19:http://tracker/annoe
      final raw = 'd4:infod4:name8:test.mkv6:lengthi1048576ee8:announce19:http://tracker/annoe';
      final bytes = Uint8List.fromList(utf8.encode(raw));

      final parsed = TorrentFileParser.parseBytes(bytes);
      expect(parsed.name, equals('test.mkv'));
      expect(parsed.totalBytes, equals(1048576));
      expect(parsed.files.length, equals(1));
      expect(parsed.files.first.index, equals(1));
      expect(parsed.files.first.name, equals('test.mkv'));
      expect(parsed.files.first.isVideo, isTrue);
      expect(parsed.announce, equals('http://tracker/anno'));
    });

    test('正确解析多层级多文件 Torrent 结构与 UTF-8 路径', () {
      // 手动编码为标准 bencode 字节流
      final raw = 'd4:infod4:name14:Frieren_BD_BOX12:piece lengthi262144e5:filesl'
          'd6:lengthi1000000e4:pathl8:Season 18:EP01.mkvee'
          'd6:lengthi1200000e4:pathl8:Season 18:EP02.mkvee'
          'd6:lengthi30000e4:pathl3:OST7:OP.flacee'
          'd6:lengthi5000e4:pathl5:Scans9:cover.jpgeeeee';

      final bytes = Uint8List.fromList(utf8.encode(raw));
      final parsed = TorrentFileParser.parseBytes(bytes);

      expect(parsed.name, equals('Frieren_BD_BOX'));
      expect(parsed.totalBytes, equals(2235000));
      expect(parsed.files.length, equals(4));

      // 验证序号均为 1-based (用于下载任务 select-file)
      expect(parsed.files[0].index, equals(1));
      expect(parsed.files[0].path, equals('Season 1/EP01.mkv'));
      expect(parsed.files[0].name, equals('EP01.mkv'));
      expect(parsed.files[0].isVideo, isTrue);

      expect(parsed.files[1].index, equals(2));
      expect(parsed.files[2].index, equals(3));
      expect(parsed.files[2].name, equals('OP.flac'));
      expect(parsed.files[2].isAudio, isTrue);

      expect(parsed.files[3].index, equals(4));
      expect(parsed.files[3].name, equals('cover.jpg'));
      expect(parsed.files[3].isImage, isTrue);
    });
  });

  group('TorrentTreeNode 三联复选框与目录树逻辑测试', () {
    late List<TorrentFileEntry> testEntries;

    setUp(() {
      testEntries = [
        TorrentFileEntry(
          index: 1,
          path: 'Anime/S01/EP01.mkv',
          name: 'EP01.mkv',
          sizeBytes: 1000,
          pathSegments: ['Anime', 'S01', 'EP01.mkv'],
          isSelected: true,
        ),
        TorrentFileEntry(
          index: 2,
          path: 'Anime/S01/EP02.mkv',
          name: 'EP02.mkv',
          sizeBytes: 2000,
          pathSegments: ['Anime', 'S01', 'EP02.mkv'],
          isSelected: true,
        ),
        TorrentFileEntry(
          index: 3,
          path: 'Anime/Music/OP.flac',
          name: 'OP.flac',
          sizeBytes: 500,
          pathSegments: ['Anime', 'Music', 'OP.flac'],
          isSelected: true,
        ),
      ];
    });

    test('buildTree 正确构建层级树，并计算全选状态', () {
      final root = TorrentTreeNode.buildTree(testEntries);
      expect(root.children.length, equals(1)); // Anime

      final anime = root.children.first;
      expect(anime.name, equals('Anime'));
      expect(anime.isDirectory, isTrue);
      expect(anime.children.length, equals(2)); // Music, S01

      // 验证初始状态：全选
      expect(root.triStateValue, isTrue);
      expect(anime.triStateValue, isTrue);
      expect(root.totalSizeBytes, equals(3500));
      expect(root.selectedSizeBytes, equals(3500));
      expect(root.selectedFilesCount, equals(3));
    });

    test('部分取消勾选时，父级目录呈现半选 (Indeterminate / null) 状态', () {
      final root = TorrentTreeNode.buildTree(testEntries);
      final anime = root.children.first;
      final s01 = anime.children.firstWhere((c) => c.name == 'S01');

      // 取消 EP01
      final ep01Node = s01.children.firstWhere((c) => c.name == 'EP01.mkv');
      ep01Node.setSelected(false);

      // S01 内部 1 个选 1 个未选 -> 半选
      expect(s01.triStateValue, isNull);
      // Anime 目录下有选有未选 -> 半选
      expect(anime.triStateValue, isNull);
      // Root 也半选
      expect(root.triStateValue, isNull);

      // 统计数据相应更新
      expect(root.selectedFilesCount, equals(2));
      expect(root.selectedSizeBytes, equals(2500));
    });

    test('点击目录复选框可一键全选或一键反选该目录下所有子孙文件', () {
      final root = TorrentTreeNode.buildTree(testEntries);
      final anime = root.children.first;
      final s01 = anime.children.firstWhere((c) => c.name == 'S01');

      // 对 S01 执行取消全选
      s01.setSelected(false);
      expect(s01.triStateValue, isFalse);
      expect(testEntries[0].isSelected, isFalse); // EP01
      expect(testEntries[1].isSelected, isFalse); // EP02
      expect(testEntries[2].isSelected, isTrue); // Music/OP 未被影响

      // 对 S01 重新勾选
      s01.setSelected(true);
      expect(s01.triStateValue, isTrue);
      expect(testEntries[0].isSelected, isTrue);
      expect(testEntries[1].isSelected, isTrue);
    });
  });
}
