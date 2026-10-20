import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kazumi/modules/search/search_history_provider.dart';

/// 全局通用的搜索历史下拉浮层组件
/// 基于现代 Flutter 的 [OverlayPortal.overlayChildLayoutBuilder] 构建，
/// 坚固可靠，杜绝 [CompositedTransformFollower] 与内部 [OverlayPortal]/[Tooltip] 的冲突。
class SearchHistoryDropdown extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSelectKeyword;
  final Widget child;
  final double maxOverlayHeight;
  final double verticalOffset;

  const SearchHistoryDropdown({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSelectKeyword,
    required this.child,
    this.maxOverlayHeight = 280.0,
    this.verticalOffset = 6.0,
  });

  @override
  ConsumerState<SearchHistoryDropdown> createState() =>
      _SearchHistoryDropdownState();
}

class _SearchHistoryDropdownState extends ConsumerState<SearchHistoryDropdown> {
  final OverlayPortalController _portalController = OverlayPortalController();

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChanged);
    widget.controller.addListener(_onTextChanged);
    if (widget.focusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.focusNode.hasFocus && !_portalController.isShowing) {
          _portalController.show();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant SearchHistoryDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      widget.focusNode.addListener(_onFocusChanged);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChanged);
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (widget.focusNode.hasFocus) {
      if (!_portalController.isShowing) {
        _portalController.show();
      }
    } else {
      if (_portalController.isShowing) {
        _portalController.hide();
      }
    }
  }

  void _onTextChanged() {
    if (widget.focusNode.hasFocus && !_portalController.isShowing) {
      _portalController.show();
    }
    if (mounted && _portalController.isShowing) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portalController,
      overlayChildBuilder: (context, layoutInfo) {
        if (layoutInfo.childSize.isEmpty) {
          return const SizedBox.shrink();
        }
        Rect childRect;
        try {
          childRect = MatrixUtils.transformRect(
            layoutInfo.childPaintTransform,
            Offset.zero & layoutInfo.childSize,
          );
        } catch (_) {
          return const SizedBox.shrink();
        }

        final screenHeight = layoutInfo.overlaySize.height;
        final screenWidth = layoutInfo.overlaySize.width;
        final availableBelow =
            screenHeight - childRect.bottom - widget.verticalOffset - 16;
        final availableAbove = childRect.top - widget.verticalOffset - 16;

        // Auto-flip upward if space below is cramped (< 140) and there is more space above
        final bool showAbove =
            availableBelow < 140 && availableAbove > availableBelow;

        final actualMaxHeight = (showAbove ? availableAbove : availableBelow)
            .clamp(120.0, widget.maxOverlayHeight);

        // Clamp horizontal bounds within screen boundaries with 8px margin
        final left = childRect.left.clamp(
          8.0,
          (screenWidth - childRect.width - 8.0).clamp(8.0, double.infinity),
        );
        final width = childRect.width.clamp(
          0.0,
          (screenWidth - 16.0).clamp(0.0, double.infinity),
        );

        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return Positioned(
          top: showAbove ? null : childRect.bottom + widget.verticalOffset,
          bottom: showAbove
              ? (screenHeight - childRect.top) + widget.verticalOffset
              : null,
          left: left,
          width: width,
          child: TextFieldTapRegion(
            child: ExcludeFocus(
              child: Material(
              elevation: 8,
              shadowColor: Colors.black38,
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Consumer(
                  builder: (context, ref, _) {
                    final allHistories = ref.watch(searchHistoryProvider);
                    final query = widget.controller.text.trim().toLowerCase();
                    final filtered = query.isEmpty
                        ? allHistories
                        : allHistories
                            .where((h) => h.keyword.toLowerCase().contains(query))
                            .toList();

                    if (filtered.isEmpty && allHistories.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 16),
                        child: Center(
                          child: Text(
                            '暂无搜索历史记录',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.outline,
                            ),
                          ),
                        ),
                      );
                    }

                    if (filtered.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 20, horizontal: 16),
                        child: Center(
                          child: Text(
                            '无匹配的搜索历史',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.outline,
                            ),
                          ),
                        ),
                      );
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 下拉菜单头部: 标题与一键清空
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 10, 8),
                          child: Row(
                            children: [
                              Icon(Icons.history,
                                  size: 16, color: colorScheme.outline),
                              const SizedBox(width: 8),
                              Text(
                                query.isEmpty ? '搜索历史' : '匹配的历史记录',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.outline,
                                ),
                              ),
                              const Spacer(),
                              if (allHistories.isNotEmpty)
                                Tooltip(
                                  message: '清空全部历史记录',
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(6),
                                    onTap: () {
                                      ref
                                          .read(searchHistoryProvider.notifier)
                                          .clearAll();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 3),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.delete_sweep_outlined,
                                            size: 15,
                                            color: colorScheme.outline,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '清空全部',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: colorScheme.outline,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          color: colorScheme.outlineVariant
                              .withValues(alpha: 0.25),
                        ),
                        // 历史条目列表
                        ConstrainedBox(
                          constraints:
                              BoxConstraints(maxHeight: actualMaxHeight),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              thickness: 0.5,
                              indent: 44,
                              color: colorScheme.outlineVariant
                                  .withValues(alpha: 0.15),
                            ),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              return ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 0),
                                leading: Icon(
                                  Icons.history_toggle_off_rounded,
                                  size: 16,
                                  color: colorScheme.outline,
                                ),
                                title: Text(
                                  item.keyword,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(fontSize: 13),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close, size: 16),
                                  tooltip: '删除此记录',
                                  visualDensity: VisualDensity.compact,
                                  color: colorScheme.outline,
                                  onPressed: () {
                                    ref
                                        .read(searchHistoryProvider.notifier)
                                        .deleteHistory(item);
                                  },
                                ),
                                onTap: () {
                                  final kw = item.keyword;
                                  widget.controller.text = kw;
                                  widget.focusNode.unfocus();
                                  _portalController.hide();
                                  widget.onSelectKeyword(kw);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          ),
        );
      },
      child: TextFieldTapRegion(
        onTapOutside: (_) {
          if (widget.focusNode.hasFocus) {
            widget.focusNode.unfocus();
          }
          if (_portalController.isShowing) {
            _portalController.hide();
          }
        },
        child: Focus(
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.escape) {
              if (_portalController.isShowing) {
                _portalController.hide();
              }
              widget.focusNode.unfocus();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: widget.child,
        ),
      ),
    );
  }
}
