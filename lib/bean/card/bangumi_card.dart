import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:haipee/router_constants.dart';
import 'package:haipee/bean/card/network_img_layer.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/widget/app_context_menu.dart';
import 'package:haipee/bean/widget/bangumi_context_menu.dart';
import 'package:haipee/modules/bangumi/bangumi_item.dart';
import 'package:haipee/utils/utils.dart';
import 'package:haipee/l10n/generated/translations.g.dart';

// 视频卡片 - 垂直布局
class BangumiCardV extends ConsumerWidget {
  const BangumiCardV({
    super.key,
    required this.bangumiItem,
    this.canTap = true,
    this.enableHero = true,
    this.source,
  });

  final BangumiItem bangumiItem;
  final bool canTap;
  final bool enableHero;
  final String? source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveSource = (source != null && source!.isNotEmpty)
        ? source!
        : (bangumiItem.source.isNotEmpty ? bangumiItem.source : 'Bangumi');

    final cardWidget = Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: GestureDetector(
        child: InkWell(
          onTap: () {
            if (!canTap) {
              HaipeeDialog.showToast(
                message: context.t.library.common.toast.editMode,
              );
              return;
            }
            context.push(Routes.info, extra: bangumiItem);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 0.65,
                child: LayoutBuilder(builder: (context, boxConstraints) {
                  final double maxWidth = boxConstraints.maxWidth;
                  final double maxHeight = boxConstraints.maxHeight;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      enableHero
                          ? Hero(
                              transitionOnUserGestures: true,
                              tag: bangumiItem.id,
                              child: NetworkImgLayer(
                                src: bangumiItem.images['large'] ?? '',
                                width: maxWidth,
                                height: maxHeight,
                              ),
                            )
                          : NetworkImgLayer(
                              src: bangumiItem.images['large'] ?? '',
                              width: maxWidth,
                              height: maxHeight,
                            ),
                      // 源站徽章 (Top-Left)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: _SourceBadge(source: effectiveSource),
                      ),
                      // 评分徽章 (Bottom-Right)
                      if (bangumiItem.ratingScore > 0)
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: _RatingBadge(score: bangumiItem.ratingScore),
                        ),
                    ],
                  );
                }),
              ),
              BangumiContent(bangumiItem: bangumiItem)
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
}

class _SourceBadge extends StatelessWidget {
  final String source;

  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBangumi = source.toLowerCase().contains('bangumi');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
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
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: isBangumi
                  ? const Color(0xFFF09199)
                  : theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 3.5),
          Flexible(
            child: Text(
              source,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.2,
                height: 1.1,
              ),
              textScaler:
                  MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  final double score;

  const _RatingBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.star_rounded,
            size: 11,
            color: Color(0xFFFFB300),
          ),
          const SizedBox(width: 2),
          Text(
            score.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              height: 1.1,
            ),
            textScaler:
                MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2),
          ),
        ],
      ),
    );
  }
}

class BangumiContent extends StatelessWidget {
  const BangumiContent({super.key, required this.bangumiItem});

  final BangumiItem bangumiItem;

  @override
  Widget build(BuildContext context) {
    final ts = MediaQuery.textScalerOf(context);
    final title =
        bangumiItem.nameCn.isNotEmpty ? bangumiItem.nameCn : bangumiItem.name;

    return Expanded(
      child: Padding(
        // 多列
        padding: const EdgeInsets.fromLTRB(5, 3, 5, 1),
        // 单列
        // padding: const EdgeInsets.fromLTRB(14, 10, 4, 8),
        child: Text(
          title,
          textAlign: TextAlign.start,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            letterSpacing: 0.3,
          ),
          textScaler: ts.clamp(maxScaleFactor: 1.1),
          maxLines: Utils.isDesktop() || Utils.isTablet() ? 3 : 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
