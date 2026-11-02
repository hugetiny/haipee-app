import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/card/episode_comments_card.dart';
import 'package:haipee/pages/video/providers.dart';
import 'package:haipee/l10n/generated/translations.g.dart';

class EpisodeCommentsSheet extends ConsumerStatefulWidget {
  const EpisodeCommentsSheet({super.key});

  @override
  ConsumerState<EpisodeCommentsSheet> createState() =>
      _EpisodeCommentsSheetState();
}

class _EpisodeCommentsSheetState extends ConsumerState<EpisodeCommentsSheet> {
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();

  /// Current episode from Riverpod provider (replaces EpisodeInfo InheritedWidget)
  int get currentEpisode => ref.read(currentEpisodeNumberProvider);

  /// Episode to query (manual selection or current)
  int get targetEpisode {
    final selectedEp = ref.read(selectedEpisodeProvider);
    return selectedEp ?? currentEpisode;
  }

  @override
  void initState() {
    super.initState();
  }

  Widget _buildEpisodeCommentsBody(List<dynamic> comments) {
    return CustomScrollView(
      scrollBehavior: const ScrollBehavior().copyWith(
        // Scrollbars' movement is not linear so hide it.
        scrollbars: false,
        // Enable mouse drag to refresh
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.trackpad
        },
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          sliver: comments.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Text(context.t.library.common.emptyState),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      // Fix scroll issue caused by height change of network images
                      // by keeping loaded cards alive.
                      return KeepAlive(
                        keepAlive: true,
                        child: IndexedSemantics(
                          index: index,
                          child: SelectionArea(
                            child: EpisodeCommentsCard(
                              commentItem: comments[index],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: comments.length,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: false,
                    addSemanticIndexes: false,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCommentsInfo(dynamic episodeInfo) {
    final t = context.t;
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(t.playback.comments.sectionTitle),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    '${episodeInfo.readType()}.${episodeInfo.episode} ${episodeInfo.name}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline)),
                Text(
                    (episodeInfo.nameCn != '')
                        ? '${episodeInfo.readType()}.${episodeInfo.episode} ${episodeInfo.nameCn}'
                        : '${episodeInfo.readType()}.${episodeInfo.episode} ${episodeInfo.name}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.outline)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 34,
            child: TextButton(
              style: ButtonStyle(
                padding: WidgetStateProperty.all(
                    const EdgeInsets.only(left: 4.0, right: 4.0)),
              ),
              onPressed: () {
                showEpisodeSelection();
              },
              child: Text(
                t.playback.comments.manualSwitch,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 选择要查看评论的集数
  void showEpisodeSelection() {
    final TextEditingController textController = TextEditingController();
    final t = context.t;
    HaipeeDialog.show(
      builder: (context) {
        return AlertDialog(
          title: Text(t.playback.comments.dialogTitle),
          content: TextField(
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly
            ],
            controller: textController,
          ),
          actions: [
            TextButton(
              onPressed: () => HaipeeDialog.dismiss(),
              child: Text(
                t.app.cancel,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () {
                if (textController.text.isEmpty) {
                  HaipeeDialog.showToast(
                    message: t.playback.comments.dialogEmpty,
                  );
                  return;
                }
                final newEp = int.tryParse(textController.text);
                if (newEp == null || newEp <= 0) {
                  return;
                }
                // ✅ Update selected episode via Riverpod provider
                ref.read(selectedEpisodeProvider.notifier).state = newEp;
                _refreshIndicatorKey.currentState?.show();
                HaipeeDialog.dismiss();
              },
              child: Text(t.playback.comments.dialogConfirm),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final videoState = ref.watch(videoProvider);
    final bangumiId = videoState.bangumiItem?.id;

    if (bangumiId == null) {
      return Scaffold(
        body: Center(
          child: Text(context.t.library.common.emptyState),
        ),
      );
    }

    // Watch async comments provider
    final commentsAsync =
        ref.watch(episodeCommentsProvider((bangumiId, targetEpisode)));

    return Scaffold(
      body: commentsAsync.when(
        data: (comments) {
          return RefreshIndicator(
            key: _refreshIndicatorKey,
            onRefresh: () async {
              ref.invalidate(
                  episodeCommentsProvider((bangumiId, targetEpisode)));
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // We need episode info, get it from video controller for now
                _buildCommentsInfo(videoState.episodeInfo),
                Expanded(child: _buildEpisodeCommentsBody(comments)),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => RefreshIndicator(
          key: _refreshIndicatorKey,
          onRefresh: () async {
            ref.invalidate(episodeCommentsProvider((bangumiId, targetEpisode)));
          },
          child: ListView(
            children: [
              SizedBox(
                height: 400,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        context.t.library.common.emptyState,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
