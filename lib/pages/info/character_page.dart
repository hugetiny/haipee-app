import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/bean/card/network_img_layer.dart';
import 'package:haipee/bean/card/character_comments_card.dart';
import 'package:haipee/bean/widget/error_widget.dart';
import 'package:haipee/pages/info/character_providers.dart';

class CharacterPage extends ConsumerWidget {
  const CharacterPage({super.key, required this.characterID});

  final int characterID;

  // ✅ Riverpod providers will handle data loading automatically

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            const PreferredSize(
              preferredSize: Size.fromHeight(kToolbarHeight),
              child: Material(
                child: TabBar(
                  tabs: [
                    Tab(text: '人物资料'),
                    Tab(text: '吐槽箱'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildCharacterInfoBody(context, ref),
                  _buildCharacterCommentsBody(context, ref),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterInfoBody(BuildContext context, WidgetRef ref) {
    // ✅ Use Riverpod provider for character detail
    final characterAsync = ref.watch(characterDetailProvider(characterID));

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: LayoutBuilder(builder: (context, constraints) {
        return Column(
          children: [
            Expanded(
              child: characterAsync.when(
                data: (characterFullItem) {
                  if (characterFullItem.id == 0) {
                    return GeneralErrorWidget(
                      errMsg: '什么都没有找到 (´;ω;`)',
                      actions: [
                        GeneralErrorButton(
                          onPressed: () {
                            ref.invalidate(
                                characterDetailProvider(characterID));
                          },
                          text: '点击重试',
                        ),
                      ],
                    );
                  }
                  return SizedBox(
                    width: double.infinity,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: constraints.maxWidth * 0.3,
                          height: constraints.maxHeight,
                          child: NetworkImgLayer(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            src: characterFullItem.image,
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    characterFullItem.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .tertiary,
                                        ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 2,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: 4.0, bottom: 12.0),
                                    child: Text(
                                      characterFullItem.nameCN,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: Colors.grey[700],
                                          ),
                                    ),
                                  ),
                                  const Divider(),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8.0),
                                    child: Text(
                                      '基本信息',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    characterFullItem.info,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                    textAlign: TextAlign.justify,
                                  ),
                                  const SizedBox(height: 16.0),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 8.0),
                                    child: Text(
                                      '角色简介',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    characterFullItem.summary,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                    textAlign: TextAlign.justify,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => GeneralErrorWidget(
                  errMsg: '什么都没有找到 (´;ω;`)',
                  actions: [
                    GeneralErrorButton(
                      onPressed: () {
                        ref.invalidate(characterDetailProvider(characterID));
                      },
                      text: '点击重试',
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildCharacterCommentsBody(BuildContext context, WidgetRef ref) {
    // ✅ Use Riverpod provider for character comments
    final commentsAsync = ref.watch(characterCommentsProvider(characterID));

    return CustomScrollView(
      scrollBehavior: const ScrollBehavior().copyWith(
        // Scrollbars' movement is not linear so hide it.
        scrollbars: false,
        // Enable mouse drag to refresh
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
        },
      ),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
          sliver: commentsAsync.when(
            data: (commentsList) {
              if (commentsList.isEmpty) {
                return SliverFillRemaining(
                  child: GeneralErrorWidget(
                    errMsg: '什么都没有找到 (´;ω;`)',
                    actions: [
                      GeneralErrorButton(
                        onPressed: () {
                          ref.invalidate(
                              characterCommentsProvider(characterID));
                        },
                        text: '点击重试',
                      ),
                    ],
                  ),
                );
              }
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    // Fix scroll issue caused by height change of network images
                    // by keeping loaded cards alive.
                    return KeepAlive(
                      keepAlive: true,
                      child: IndexedSemantics(
                        index: index,
                        child: SelectionArea(
                          child: CharacterCommentsCard(
                            commentItem: commentsList[index],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: commentsList.length,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: false,
                  addSemanticIndexes: false,
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stack) => SliverFillRemaining(
              child: GeneralErrorWidget(
                errMsg: '什么都没有找到 (´;ω;`)',
                actions: [
                  GeneralErrorButton(
                    onPressed: () {
                      ref.invalidate(characterCommentsProvider(characterID));
                    },
                    text: '点击重试',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
