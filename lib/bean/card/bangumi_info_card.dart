import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/providers/riverpod_compat.dart';
import 'package:haipee/bean/widget/collect_button.dart';
import 'package:haipee/utils/constants.dart';
import 'package:haipee/modules/bangumi/bangumi_item.dart';
import 'package:haipee/bean/card/network_img_layer.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:haipee/bean/widget/app_context_menu.dart';
import 'package:haipee/bean/widget/bangumi_context_menu.dart';

/// Provider for chart touched index
final chartTouchedIndexProvider = StateProvider.autoDispose<int>((ref) => -1);

// 视频卡片 - 水平布局
class BangumiInfoCardV extends ConsumerStatefulWidget {
  const BangumiInfoCardV({
    super.key,
    required this.bangumiItem,
    required this.isLoading,
  });

  final BangumiItem bangumiItem;
  final bool isLoading;

  @override
  ConsumerState<BangumiInfoCardV> createState() => _BangumiInfoCardVState();
}

class _BangumiInfoCardVState extends ConsumerState<BangumiInfoCardV> {
  Widget get voteBarChart {
    final List<int> voteCounts = _normalizedVoteCounts();
    final int totalVotes = _resolveTotalVotes(voteCounts);
    final touchedIndex = ref.watch(chartTouchedIndexProvider);

    if (totalVotes == 0) {
      return const SizedBox.shrink();
    }
    return Flexible(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '  评分透视:',
          ),
          SizedBox(height: 16),
          Expanded(
            child: AspectRatio(
              aspectRatio: 2,
              child: BarChart(
              duration: Duration(milliseconds: 80),
              BarChartData(
                // alignment: BarChartAlignment.spaceEvenly,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                barTouchData: BarTouchData(
                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                    if (!event.isInterestedForInteractions ||
                        barTouchResponse == null ||
                        barTouchResponse.spot == null) {
                      ref.read(chartTouchedIndexProvider.notifier).state = -1;
                      return;
                    }
                    ref.read(chartTouchedIndexProvider.notifier).state =
                        barTouchResponse.spot!.touchedBarGroupIndex;
                  },
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) =>
                        Theme.of(context).colorScheme.inverseSurface,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final int safeIndex =
                          groupIndex.clamp(0, voteCounts.length - 1);
                      final double percentage =
                          (voteCounts[safeIndex] / totalVotes) * 100;
                      return BarTooltipItem(
                        '${percentage.toStringAsFixed(2)}% (${voteCounts[safeIndex]}人)',
                        TextStyle(
                            color:
                                Theme.of(context).colorScheme.onInverseSurface),
                      );
                    },
                  ),
                ),
                barGroups: List<BarChartGroupData>.generate(
                  voteCounts.length,
                  (i) {
                    final double value = voteCounts[i].toDouble();
                    return BarChartGroupData(
                      x: i + 1,
                      barRods: [
                        BarChartRodData(
                          toY: value,
                          color: touchedIndex == i
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).disabledColor,
                          width: 20,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(5)),
                        )
                      ],
                      // showingTooltipIndicators: [0],
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) => SideTitleWidget(
                        meta: meta,
                        space: 10,
                        child: Text(value.toInt().toString()),
                      ),
                    ),
                  ),
                  topTitles: const AxisTitles(),
                  leftTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                ),
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  List<int> _normalizedVoteCounts() {
    const int bucketSize = 10;
    final List<int> source = widget.bangumiItem.votesCount;
    if (source.isEmpty) {
      return List<int>.filled(bucketSize, 0);
    }
    final List<int> counts = List<int>.filled(bucketSize, 0);
    for (var i = 0; i < bucketSize && i < source.length; i++) {
      counts[i] = source[i];
    }
    return counts;
  }

  int _resolveTotalVotes(List<int> normalizedCounts) {
    final int totalFromItem = widget.bangumiItem.votes;
    if (totalFromItem > 0) {
      return totalFromItem;
    }
    return normalizedCounts.fold<int>(0, (sum, value) => sum + value);
  }

  @override
  Widget build(BuildContext context) {
    final cardWidget = SizedBox(
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.bangumiItem.nameCn == ''
                ? widget.bangumiItem.name
                : (widget.bangumiItem.nameCn),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: AspectRatio(
                    aspectRatio: 0.65,
                    child: LayoutBuilder(builder: (context, boxConstraints) {
                      final double maxWidth = boxConstraints.maxWidth;
                      final double maxHeight = boxConstraints.maxHeight;
                      return Hero(
                        transitionOnUserGestures: true,
                        tag: widget.bangumiItem.id,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            NetworkImgLayer(
                              src: widget.bangumiItem.images['large'] ?? '',
                              width: maxWidth,
                              height: maxHeight,
                              fadeInDuration: const Duration(milliseconds: 0),
                              fadeOutDuration: const Duration(milliseconds: 0),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5.5, vertical: 2.5),
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
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFF09199),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Bangumi',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.2,
                                        height: 1.1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
                SizedBox(width: 16),
                Flexible(
                  child: Skeletonizer(
                    enabled: widget.isLoading,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topLeft,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '放送开始:',
                              ),
                              Text(
                                widget.bangumiItem.airDate == ''
                                    ? '2000-11-11' // Skeleton Loader 占位符
                                    : widget.bangumiItem.airDate,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '${widget.bangumiItem.votes} 人评分:',
                              ),
                              if (widget.isLoading)
                                // Skeleton Loader 占位符
                                Text(
                                  '10.0 ********',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              if (!widget.isLoading)
                                Row(
                                  children: [
                                    Text(
                                      '${widget.bangumiItem.ratingScore}',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color:
                                            Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    RatingBarIndicator(
                                      itemCount: 5,
                                      rating: widget.bangumiItem.ratingScore
                                              .toDouble() /
                                          2,
                                      itemBuilder: (context, index) => Icon(
                                        Icons.star_rounded,
                                        color:
                                            Theme.of(context).colorScheme.primary,
                                      ),
                                      itemSize: 20.0,
                                    ),
                                  ],
                                ),
                              SizedBox(height: 8),
                              Text(
                                'Bangumi Ranked:',
                              ),
                              Text(
                                '#${widget.bangumiItem.rank}',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            width: 120,
                            height: 40,
                            child: CollectButton.extend(
                              bangumiItem: widget.bangumiItem,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (MediaQuery.sizeOf(context).width >=
                        LayoutBreakpoint.compact['width']! &&
                    !widget.isLoading)
                  voteBarChart,
              ],
            ),
          ),
        ],
      ),
    );

    return AppContextMenu(
      itemsBuilder: (context) => BangumiContextMenuHelper.buildMenuItems(
        context: context,
        ref: ref,
        bangumiItem: widget.bangumiItem,
      ),
      child: cardWidget,
    );
  }
}
