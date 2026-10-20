import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:kazumi/modules/torrent_search/models/torrent_item.dart';

/// 迅雷与现代 BT 风格的资源链接类型徽章（标清楚是磁力还是种子，还是两者都有）
class TorrentLinkBadge extends StatelessWidget {
  final TorrentLinkType type;
  final bool compact;
  final VoidCallback? onTap;

  const TorrentLinkBadge({
    super.key,
    required this.type,
    this.compact = false,
    this.onTap,
  });

  /// 便捷工厂方法：直接从 [TorrentItem] 构造
  factory TorrentLinkBadge.fromItem(
    TorrentItem item, {
    Key? key,
    bool compact = false,
    VoidCallback? onTap,
  }) {
    return TorrentLinkBadge(
      key: key,
      type: item.linkType,
      compact: compact,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (type == TorrentLinkType.none) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (
      Color bg,
      Color border,
      Color fg,
      IconData icon,
      String text,
      String tooltip,
    ) = switch (type) {
      TorrentLinkType.dual => (
          isDark ? Colors.teal.shade900.withAlpha(90) : Colors.teal.shade50,
          isDark ? Colors.teal.shade700 : Colors.teal.shade300,
          isDark ? Colors.teal.shade200 : Colors.teal.shade800,
          Icons.all_inclusive,
          '种子+磁力',
          '双链资源：同时提供种子文件与磁力链接（默认优先使用种子秒级解析与下载）',
        ),
      TorrentLinkType.torrentOnly => (
          isDark ? Colors.green.shade900.withAlpha(90) : Colors.green.shade50,
          isDark ? Colors.green.shade700 : Colors.green.shade300,
          isDark ? Colors.green.shade200 : Colors.green.shade800,
          Icons.file_present_outlined,
          '种子',
          '种子资源：提供 .torrent 种子文件（支持 HTTP 秒级解析与下载）',
        ),
      TorrentLinkType.magnetOnly => (
          isDark ? Colors.indigo.shade900.withAlpha(90) : Colors.indigo.shade50,
          isDark ? Colors.indigo.shade700 : Colors.indigo.shade300,
          isDark ? Colors.indigo.shade200 : Colors.indigo.shade800,
          Icons.link,
          '磁力',
          '磁力资源：提供 magnet 磁力链接（通过 P2P DHT 网络解析）',
        ),
      TorrentLinkType.none => (
          Colors.transparent,
          Colors.transparent,
          Colors.transparent,
          Icons.link,
          '',
          '',
        ),
    };

    final content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 6,
        vertical: compact ? 1.5 : 2.5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: border, width: 0.6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: compact ? 11 : 12,
            color: fg,
          ),
          SizedBox(width: compact ? 2.5 : 4),
          Text(
            text,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.bold,
              color: fg,
              height: 1.1,
            ),
          ),
        ],
      ),
    );

    final wrapped = Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: content,
    );

    final badgeWidget = (onTap != null)
        ? InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: wrapped,
          )
        : wrapped;

    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest) {
      return badgeWidget;
    }

    return badgeWidget
        .animate()
        .fadeIn(duration: 180.ms)
        .scale(
          begin: const Offset(0.96, 0.96),
          end: const Offset(1, 1),
          curve: Curves.easeOutCubic,
        );
  }
}
