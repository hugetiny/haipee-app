import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kazumi/bean/widget/error_widget.dart';
import 'package:kazumi/bean/card/comments_card.dart';
import 'package:kazumi/bean/card/character_card.dart';
import 'package:kazumi/bean/card/staff_card.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:kazumi/l10n/generated/translations.g.dart';
import 'package:kazumi/modules/bangumi/bangumi_item.dart';
import 'package:kazumi/modules/comments/comment_item.dart';
import 'package:kazumi/modules/metadata_sync/models/metadata_record.dart';
import 'package:kazumi/pages/info/providers.dart';

class InfoTabView extends ConsumerStatefulWidget {
  const InfoTabView({
    super.key,
    required this.tabController,
    required this.bangumiItem,
    required this.commentsList,
    required this.isLoading,
    required this.metadataRecord,
    required this.metadataLoading,
    this.onRefreshMetadata,
  });

  final TabController tabController;
  final BangumiItem bangumiItem;
  final List<CommentItem> commentsList;
  final bool isLoading;
  final MetadataRecord? metadataRecord;
  final bool metadataLoading;
  final VoidCallback? onRefreshMetadata;

  @override
  ConsumerState<InfoTabView> createState() => _InfoTabViewState();
}

class _InfoTabViewState extends ConsumerState<InfoTabView>
    with SingleTickerProviderStateMixin {
  double get maxWidth => double.infinity;
  // ✅ fullIntro, fullTag, showAllEpisodes moved to Riverpod StateProvider

  Widget get infoBody {
    final infoTexts = context.t.library.info;
    final List<Widget> children = <Widget>[
      _buildMetadataStatusCard(),
      const SizedBox(height: 16),
      Text(infoTexts.summary.title, style: const TextStyle(fontSize: 18)),
      const SizedBox(height: 8),
      _buildSummarySection(),
      const SizedBox(height: 16),
      Text(infoTexts.tags.title, style: const TextStyle(fontSize: 18)),
      const SizedBox(height: 8),
      _buildTagsSection(),
    ];

    final List<Widget> episodeWidgets = _buildEpisodesSection();
    if (episodeWidgets.isNotEmpty) {
      children
        ..add(const SizedBox(height: 16))
        ..addAll(episodeWidgets);
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width > maxWidth
              ? maxWidth
              : MediaQuery.sizeOf(context).width - 32,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ),
    );
  }

  Widget _buildSummarySection() {
    final summaryTexts = context.t.library.info.summary;
    // ✅ Watch fullIntro state from Riverpod provider
    final fullIntro = ref.watch(infoUIProvider.select((s) => s.fullIntro));

    return LayoutBuilder(builder: (context, constraints) {
      final TextSpan span = TextSpan(text: widget.bangumiItem.summary);
      final TextPainter painter =
          TextPainter(text: span, textDirection: TextDirection.ltr);
      painter.layout(maxWidth: constraints.maxWidth);
      final int lineCount = painter.computeLineMetrics().length;
      if (lineCount > 7) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(
              height: fullIntro ? null : 120,
              width: constraints.maxWidth,
              child: SelectableText(
                widget.bangumiItem.summary,
                textAlign: TextAlign.start,
                scrollBehavior: const ScrollBehavior().copyWith(
                  scrollbars: false,
                ),
                scrollPhysics: const NeverScrollableScrollPhysics(),
                selectionHeightStyle: ui.BoxHeightStyle.max,
              ),
            ),
            TextButton(
              onPressed: () {
                // ✅ Update state via Riverpod provider
                ref.read(infoUIProvider.notifier).toggleFullIntro();
              },
              child: Text(
                fullIntro ? summaryTexts.collapse : summaryTexts.expand,
              ),
            ),
          ],
        );
      }
      return SelectableText(
        widget.bangumiItem.summary,
        textAlign: TextAlign.start,
        scrollPhysics: const NeverScrollableScrollPhysics(),
        selectionHeightStyle: ui.BoxHeightStyle.max,
      );
    });
  }

  Widget _buildTagsSection() {
    final tagsTexts = context.t.library.info.tags;
    // ✅ Watch fullTag state from Riverpod provider
    final fullTag = ref.watch(infoUIProvider.select((s) => s.fullTag));

    return Wrap(
      spacing: 8.0,
      runSpacing: Utils.isDesktop() ? 8 : 0,
      children: List<Widget>.generate(
          fullTag || widget.bangumiItem.tags.length < 13
              ? widget.bangumiItem.tags.length
              : 13, (int index) {
        if (!fullTag && index == 12) {
          return ActionChip(
            label: Text(
              tagsTexts.more,
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            onPressed: () {
              // ✅ Update state via Riverpod provider
              ref.read(infoUIProvider.notifier).toggleFullTag();
            },
          );
        }
        return ActionChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${widget.bangumiItem.tags[index].name} '),
              Text(
                '${widget.bangumiItem.tags[index].count}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          onPressed: () {
            context.push(
              '/search',
              extra: widget.bangumiItem.tags[index].name,
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildMetadataStatusCard() {
    final metadataTexts = context.t.library.info.metadata;
    final MetadataRecord? record = widget.metadataRecord;
    final Widget? refreshButton = widget.onRefreshMetadata == null
        ? null
        : TextButton.icon(
            onPressed: widget.metadataLoading ? null : widget.onRefreshMetadata,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(metadataTexts.refresh),
          );

    if (widget.metadataLoading && record == null) {
      return Card(
        child: ListTile(
          leading: const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text(metadataTexts.syncingTitle),
          subtitle: Text(metadataTexts.syncingSubtitle),
          trailing: refreshButton,
        ),
      );
    }

    if (record == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.info_outline_rounded),
          title: Text(metadataTexts.emptyTitle),
          subtitle: Text(metadataTexts.emptySubtitle),
          trailing: refreshButton,
        ),
      );
    }

    final ThemeData theme = Theme.of(context);
    final String languageLabel = record.localeTag.isEmpty
        ? metadataTexts.languageSystem
        : record.localeTag;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                widget.metadataLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    metadataTexts.source(
                      source: _sourceDisplayName(record.activeSource),
                    ),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (refreshButton != null) refreshButton,
              ],
            ),
            const SizedBox(height: 8),
            Text(
              metadataTexts.updated(
                timestamp: _formatUpdatedAt(record.updatedAt),
                language: languageLabel,
              ),
              style: theme.textTheme.bodySmall,
            ),
            if (record.identifiers.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: record.identifiers.entries
                    .map(
                      (entry) => Chip(
                        label: Text(
                          '${entry.key.toUpperCase()}: ${entry.value}',
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildEpisodesSection() {
    final MetadataRecord? record = widget.metadataRecord;
    if (record == null || record.episodes.isEmpty) {
      return const <Widget>[];
    }

    final episodesTexts = context.t.library.info.episodes;
    final List<EpisodeMetadata> episodes = record.episodes;
    // ✅ Watch showAllEpisodes state from Riverpod provider
    final showAllEpisodes =
        ref.watch(infoUIProvider.select((s) => s.showAllEpisodes));
    final List<EpisodeMetadata> visibleEpisodes =
        showAllEpisodes ? episodes : episodes.take(10).toList(growable: false);

    return <Widget>[
      Row(
        children: [
          Text(episodesTexts.title, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          if (widget.metadataLoading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          const Spacer(),
          if (episodes.length > visibleEpisodes.length)
            TextButton(
              onPressed: () {
                // ✅ Update state via Riverpod provider
                ref.read(infoUIProvider.notifier).toggleShowAllEpisodes();
              },
              child: Text(
                showAllEpisodes
                    ? episodesTexts.collapse
                    : episodesTexts.expand(count: episodes.length),
              ),
            ),
        ],
      ),
      const SizedBox(height: 8),
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (BuildContext context, int index) {
          final EpisodeMetadata episode = visibleEpisodes[index];
          return _buildEpisodeTile(episode);
        },
        separatorBuilder: (_, __) => const Divider(height: 16),
        itemCount: visibleEpisodes.length,
      ),
    ];
  }

  Widget _buildEpisodeTile(EpisodeMetadata episode) {
    final ThemeData theme = Theme.of(context);
    final episodesTexts = context.t.library.info.episodes;
    final String title = (episode.title?.trim().isNotEmpty ?? false)
        ? episode.title!.trim()
        : episodesTexts.numberedEpisode(number: episode.number);
    final String metadataLine =
        '${_formatEpisodeDate(episode.airDate)} · ${_formatEpisodeRuntime(episode.runtimeMinutes)}';
    final String synopsis = (episode.synopsis ?? '').trim();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        child: Text(episode.number.toString()),
      ),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(metadataLine, style: theme.textTheme.bodySmall),
          if (synopsis.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                synopsis,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  String _formatUpdatedAt(DateTime time) {
    final DateTime local = time.toLocal();
    return '${local.year.toString()}-${_twoDigits(local.month)}-${_twoDigits(local.day)} '
        '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
  }

  String _formatEpisodeDate(DateTime? time) {
    final episodesTexts = context.t.library.info.episodes;
    if (time == null) {
      return episodesTexts.dateUnknown;
    }
    final DateTime local = time.toLocal();
    return '${local.year}-${_twoDigits(local.month)}-${_twoDigits(local.day)}';
  }

  String _formatEpisodeRuntime(int? minutes) {
    final episodesTexts = context.t.library.info.episodes;
    if (minutes == null || minutes <= 0) {
      return episodesTexts.runtimeUnknown;
    }
    return episodesTexts.runtimeMinutes(minutes: minutes);
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');

  String _sourceDisplayName(String? source) {
    final metadataTexts = context.t.library.info.metadata;
    switch (source) {
      case 'bangumi':
        return 'Bangumi';
      case 'tmdb':
        return 'TMDb';
      case null:
        return metadataTexts.multiSource;
      default:
        return source.toUpperCase();
    }
  }

  /// Bone for Skeleton Loader
  Widget get infoBodyBone {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width > maxWidth
              ? maxWidth
              : MediaQuery.sizeOf(context).width - 32,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Skeletonizer.zone(child: Bone.multiText(lines: 3)),
              const SizedBox(height: 16),
              Skeletonizer.zone(child: Bone.text(fontSize: 18, width: 50)),
              const SizedBox(height: 8),
              Skeletonizer.zone(child: Bone.multiText(lines: 7)),
              const SizedBox(height: 16),
              Skeletonizer.zone(child: Bone.text(fontSize: 18, width: 50)),
              const SizedBox(height: 8),
              if (widget.isLoading)
                Skeletonizer.zone(
                  child: Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: List.generate(
                        4, (_) => Bone.button(uniRadius: 8, height: 32)),
                  ),
                ),
              const SizedBox(height: 16),
              if (widget.isLoading) ...[
                Skeletonizer.zone(child: Bone.text(fontSize: 18, width: 60)),
                const SizedBox(height: 8),
                Skeletonizer.zone(child: Bone.multiText(lines: 2)),
                const SizedBox(height: 12),
                Skeletonizer.zone(child: Bone.multiText(lines: 2)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget get commentsListBody {
    return Builder(
      builder: (BuildContext context) {
        // TODO: 评论区分页加载需要使用不同的 provider 模式
        // 当前保留使用 info_controller 的 commentsList
        return CustomScrollView(
          scrollBehavior: const ScrollBehavior().copyWith(
            scrollbars: false,
          ),
          key: const PageStorageKey<String>('comments'),
          slivers: <Widget>[
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverLayoutBuilder(builder: (context, _) {
              if (widget.commentsList.isNotEmpty) {
                return SliverList.separated(
                  addAutomaticKeepAlives: false,
                  itemCount: widget.commentsList.length,
                  itemBuilder: (context, index) {
                    return SafeArea(
                      top: false,
                      bottom: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width > maxWidth
                                ? maxWidth
                                : MediaQuery.sizeOf(context).width - 32,
                            child: CommentsCard(
                              commentItem: widget.commentsList[index],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (BuildContext context, int index) {
                    return SafeArea(
                      top: false,
                      bottom: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width > maxWidth
                                ? maxWidth
                                : MediaQuery.sizeOf(context).width - 32,
                            child: Divider(
                                thickness: 0.5, indent: 10, endIndent: 10),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
              if (widget.isLoading) {
                return SliverList.builder(
                  itemCount: 4,
                  itemBuilder: (context, _) {
                    return SafeArea(
                      top: false,
                      bottom: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width > maxWidth
                                ? maxWidth
                                : MediaQuery.sizeOf(context).width - 32,
                            child: CommentsCard.bone(),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }
              return SliverFillRemaining(
                child: Center(
                  child: Text(context.t.library.common.emptyState),
                ),
              );
            })
          ],
        );
      },
    );
  }

  Widget get staffListBody {
    return Builder(
      builder: (BuildContext context) {
        final infoTexts = context.t.library.info;
        final errorsTexts = infoTexts.errors;
        final appTexts = context.t.app;

        // ✅ Use Riverpod provider for staff
        final staffAsync =
            ref.watch(bangumiStaffsProvider(widget.bangumiItem.id));

        return CustomScrollView(
          scrollBehavior: const ScrollBehavior().copyWith(
            scrollbars: false,
          ),
          key: const PageStorageKey<String>('staff'),
          slivers: <Widget>[
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverLayoutBuilder(builder: (context, _) {
              return staffAsync.when(
                data: (staffList) {
                  if (staffList.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Text(context.t.library.common.emptyState),
                      ),
                    );
                  }
                  return SliverList.builder(
                    itemCount: staffList.length,
                    itemBuilder: (context, index) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width > maxWidth
                                ? maxWidth
                                : MediaQuery.sizeOf(context).width - 32,
                            child: StaffCard(
                              staffFullItem: staffList[index],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => SliverList.builder(
                  itemCount: 8,
                  itemBuilder: (context, _) {
                    return Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: MediaQuery.sizeOf(context).width > maxWidth
                            ? maxWidth
                            : MediaQuery.sizeOf(context).width - 32,
                        child: Skeletonizer.zone(
                          child: ListTile(
                            leading: Bone.circle(size: 36),
                            title: Bone.text(width: 100),
                            subtitle: Bone.text(width: 80),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                error: (error, stack) => SliverFillRemaining(
                  child: GeneralErrorWidget(
                    errMsg: errorsTexts.fetchFailed,
                    actions: [
                      GeneralErrorButton(
                        onPressed: () {
                          ref.invalidate(
                              bangumiStaffsProvider(widget.bangumiItem.id));
                        },
                        text: appTexts.retry,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget get charactersListBody {
    return Builder(
      builder: (BuildContext context) {
        final infoTexts = context.t.library.info;
        final errorsTexts = infoTexts.errors;
        final appTexts = context.t.app;

        // ✅ Use Riverpod provider for characters
        final charactersAsync =
            ref.watch(bangumiCharactersProvider(widget.bangumiItem.id));

        return CustomScrollView(
          scrollBehavior: const ScrollBehavior().copyWith(
            scrollbars: false,
          ),
          key: const PageStorageKey<String>('characters'),
          slivers: <Widget>[
            SliverOverlapInjector(
              handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
            ),
            SliverLayoutBuilder(builder: (context, _) {
              return charactersAsync.when(
                data: (characters) {
                  if (characters.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Text(context.t.library.common.emptyState),
                      ),
                    );
                  }
                  return SliverList.builder(
                    itemCount: characters.length,
                    itemBuilder: (context, index) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: SizedBox(
                            width: MediaQuery.sizeOf(context).width > maxWidth
                                ? maxWidth
                                : MediaQuery.sizeOf(context).width - 32,
                            child: CharacterCard(
                              characterItem: characters[index],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => SliverList.builder(
                  itemCount: 4,
                  itemBuilder: (context, _) {
                    return Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: MediaQuery.sizeOf(context).width > maxWidth
                            ? maxWidth
                            : MediaQuery.sizeOf(context).width - 32,
                        child: Skeletonizer.zone(
                          child: ListTile(
                            leading: Bone.circle(size: 36),
                            title: Bone.text(width: 100),
                            subtitle: Bone.text(width: 80),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                error: (error, stack) => SliverFillRemaining(
                  child: GeneralErrorWidget(
                    errMsg: errorsTexts.fetchFailed,
                    actions: [
                      GeneralErrorButton(
                        onPressed: () {
                          ref.invalidate(
                              bangumiCharactersProvider(widget.bangumiItem.id));
                        },
                        text: appTexts.retry,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final infoTexts = context.t.library.info;
    return TabBarView(
      controller: widget.tabController,
      children: [
        Builder(
          // This Builder is needed to provide a BuildContext that is
          // "inside" the NestedScrollView, so that
          // sliverOverlapAbsorberHandleFor() can find the
          // NestedScrollView.
          builder: (BuildContext context) {
            return CustomScrollView(
              scrollBehavior: const ScrollBehavior().copyWith(
                scrollbars: false,
              ),
              // The PageStorageKey should be unique to this ScrollView;
              // it allows the list to remember its scroll position when
              // the tab view is not on the screen.
              key: const PageStorageKey<String>('overview'),
              slivers: <Widget>[
                SliverOverlapInjector(
                  handle:
                      NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                ),
                SliverToBoxAdapter(
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: widget.isLoading ? infoBodyBone : infoBody,
                  ),
                ),
              ],
            );
          },
        ),
        commentsListBody,
        charactersListBody,
        Builder(
          builder: (BuildContext context) {
            return CustomScrollView(
              scrollBehavior: const ScrollBehavior().copyWith(
                scrollbars: false,
              ),
              key: const PageStorageKey<String>('reviews'),
              slivers: <Widget>[
                SliverOverlapInjector(
                  handle:
                      NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                ),
                // TODO: 评论区
                SliverFillRemaining(
                  child: Center(child: Text(infoTexts.tabs.placeholder)),
                ),
              ],
            );
          },
        ),
        staffListBody,
      ],
    );
  }
}
