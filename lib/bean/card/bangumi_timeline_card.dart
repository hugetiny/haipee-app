import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/bean/widget/app_context_menu.dart';
import 'package:kazumi/bean/widget/bangumi_context_menu.dart';
import 'package:kazumi/router_constants.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';

/// 时间线番剧卡片
class BangumiTimelineCard extends ConsumerWidget {
  const BangumiTimelineCard({
    super.key,
    required this.bangumiItem,
    this.onTap,
    this.cardHeight = 120,
    this.cardWidth,
    this.enableHero = true,
  });

  final BangumiItem bangumiItem;
  final VoidCallback? onTap;
  final bool enableHero;
  final double cardHeight;
  final double? cardWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = Utils.isDesktop();
    final isTablet = Utils.isTablet();
    final theme = Theme.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final double imageWidth = cardHeight * 0.7;
    final double borderRadius = 18;

    final cardWidget = Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap ??
            () {
              context.push(Routes.info, extra: bangumiItem);
            },
        child: SizedBox(
          height: cardHeight,
          width: cardWidth,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              buildImage(context, bangumiItem.images['large'] ?? '', imageWidth,
                  cardHeight),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  child: buildInfo(context, textScaler, isDesktop, isTablet),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return AppContextMenu(
      itemsBuilder: (context) => BangumiContextMenuHelper.buildMenuItems(
        context: context,
        ref: ref,
        bangumiItem: bangumiItem,
      ),
      child: cardWidget,
    );
  }

  Widget buildImage(
      BuildContext context, String imageUrl, double width, double height) {
    final borderRadius = BorderRadius.circular(16);
    Widget img = NetworkImgLayer(
      src: imageUrl,
      width: width,
      height: height,
    );
    img = Stack(
      children: [
        Positioned.fill(child: img),
        Positioned(
          top: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 0.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 4.5,
                  height: 4.5,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF09199),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 3),
                Text(
                  'Bangumi',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                    height: 1.1,
                  ),
                  textScaler: MediaQuery.textScalerOf(context)
                      .clamp(maxScaleFactor: 1.1),
                ),
              ],
            ),
          ),
        ),
      ],
    );
    if (enableHero) {
      img = Hero(
        tag: bangumiItem.id,
        transitionOnUserGestures: true,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: img,
        ),
      );
    } else {
      img = ClipRRect(
        borderRadius: borderRadius,
        child: img,
      );
    }
    return SizedBox(
      width: width,
      height: height,
      child: img,
    );
  }

  Widget buildInfo(BuildContext context, TextScaler textScaler, bool isDesktop,
      bool isTablet) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final nameStyle =
        theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);
    final subStyle = theme.textTheme.bodySmall
        ?.copyWith(color: colorScheme.onSurfaceVariant);
    final infoStyle =
        theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500);
    final maxLines = isDesktop ? 2 : 1;
    final double spacing = isDesktop ? 8 : 4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Text(
          bangumiItem.nameCn.isNotEmpty ? bangumiItem.nameCn : bangumiItem.name,
          style: nameStyle,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textScaler: textScaler.clamp(maxScaleFactor: 1.1),
        ),
        SizedBox(height: spacing),
        // 简介
        if (bangumiItem.summary.isNotEmpty || bangumiItem.info.isNotEmpty)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer
                      .withAlpha((255 * 0.10).round()),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    bangumiItem.info.isNotEmpty
                        ? bangumiItem.info
                        : bangumiItem.summary,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textScaler: textScaler.clamp(maxScaleFactor: 1.0),
                  ),
                ),
              ),
            ),
          )
        else
        const SizedBox(height: 4),
        Row(
          children: [
            if (bangumiItem.ratingScore > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded,
                      size: 15, color: colorScheme.primary),
                  const SizedBox(width: 2),
                  Text(bangumiItem.ratingScore.toStringAsFixed(1),
                      style: infoStyle),
                ],
              ),
            if (bangumiItem.rank > 0)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.leaderboard,
                        size: 15, color: colorScheme.tertiary),
                    const SizedBox(width: 2),
                    Text('Rank ${bangumiItem.rank}', style: infoStyle),
                  ],
                ),
              ),
            const Spacer(),
            if (bangumiItem.votes > 0)
              Flexible(
                child: Text(
                  '${bangumiItem.votes}人',
                  style: subStyle,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
