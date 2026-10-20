import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/bean/card/network_img_layer.dart';
import 'package:kazumi/bean/widget/responsive/responsive.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/router_constants.dart';

/// 首页焦点推荐轮播组件 (Material 3 原生 CarouselView)
class PopularHeroCarousel extends StatelessWidget {
  const PopularHeroCarousel({
    super.key,
    required this.items,
  });

  final List<BangumiItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final heroList = items.take(8).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenType = AppBreakpoints.getScreenType(screenWidth);
        final double itemExtent = screenType.isDesktop
            ? 340.0
            : (screenType.isTablet ? 280.0 : 230.0);
        final double carouselHeight = screenType.isDesktop
            ? 200.0
            : (screenType.isTablet ? 180.0 : 160.0);

        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Row(
                spacing: 6,
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  Text(
                    '焦点趋势推荐',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: carouselHeight,
                child: ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: {
                      PointerDeviceKind.touch,
                      PointerDeviceKind.mouse,
                      PointerDeviceKind.trackpad,
                      PointerDeviceKind.stylus,
                    },
                  ),
                  child: CarouselView(
                    itemExtent: itemExtent,
                    shrinkExtent: 140.0,
                    itemSnapping: true,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onTap: (int index) {
                      if (index >= 0 && index < heroList.length) {
                        context.push(Routes.info, extra: heroList[index]);
                      }
                    },
                    children: heroList.map((item) {
                      return _CarouselItemContent(
                        item: item,
                        height: carouselHeight,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CarouselItemContent extends StatelessWidget {
  const _CarouselItemContent({
    required this.item,
    required this.height,
  });

  final BangumiItem item;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = item.nameCn.isNotEmpty ? item.nameCn : item.name;
    final coverUrl = item.images['large'] ?? item.images['common'] ?? '';

    return Stack(
      fit: StackFit.expand,
      children: [
        // 背景封面图
        NetworkImgLayer(
          src: coverUrl,
          width: double.infinity,
          height: height,
        ),

        // 阴影与渐变遮罩增强文字可读性
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.1),
                Colors.black.withValues(alpha: 0.4),
                Colors.black.withValues(alpha: 0.85),
              ],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),

        // 顶部评分徽标
        if (item.ratingScore > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 3,
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: 13,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  Text(
                    item.ratingScore.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // 底部标题与概要
        Positioned(
          left: 12,
          right: 12,
          bottom: 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: 2,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                  shadows: [
                    Shadow(
                      color: Colors.black,
                      blurRadius: 4,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
              if (item.airDate.isNotEmpty)
                Text(
                  item.airDate,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
