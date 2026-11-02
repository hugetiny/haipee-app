import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/modules/bangumi/bangumi_item.dart';
import 'package:haipee/pages/my/providers.dart';

class CollectButton extends ConsumerStatefulWidget {
  CollectButton({
    super.key,
    required this.bangumiItem,
    this.color = Colors.white,
    this.onOpen,
    this.onClose,
  }) {
    isExtended = false;
  }

  CollectButton.extend({
    super.key,
    required this.bangumiItem,
    this.color = Colors.white,
    this.onOpen,
    this.onClose,
  }) {
    isExtended = true;
  }

  final BangumiItem bangumiItem;
  final Color color;
  late final bool isExtended;
  final void Function()? onOpen;
  final void Function()? onClose;

  @override
  ConsumerState<CollectButton> createState() => _CollectButtonState();
}

class _CollectButtonState extends ConsumerState<CollectButton> {
  // 1. 在看
  // 2. 想看
  // 3. 搁置
  // 4. 看过
  // 5. 抛弃

  String getTypeStringByInt(int collectType) {
    switch (collectType) {
      case 0:
        return "未追";
      case 1:
        return "在看";
      case 2:
        return "想看";
      case 3:
        return "搁置";
      case 4:
        return "看过";
      case 5:
        return "抛弃";
      default:
        return "未追";
    }
  }

  IconData getIconByInt(int collectType) {
    switch (collectType) {
      case 0:
        return Icons.favorite_border;
      case 1:
        return Icons.favorite;
      case 2:
        return Icons.star_rounded;
      case 3:
        return Icons.pending_actions;
      case 4:
        return Icons.done;
      case 5:
        return Icons.heart_broken;
      default:
        return Icons.favorite_border;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(collectionsProvider);
    final collectController = ref.read(collectionsProvider.notifier);
    final collectType = collectController.getCollectType(widget.bangumiItem);
    return MenuAnchor(
      consumeOutsideTap: true,
      onClose: widget.onClose,
      onOpen: widget.onOpen,
      crossAxisUnconstrained: false,
      builder: (_, MenuController controller, __) {
        if (widget.isExtended) {
          return FilledButton.icon(
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            icon: Icon(getIconByInt(collectType)),
            label: Text(getTypeStringByInt(collectType)),
          );
        } else {
          return IconButton(
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            icon: Icon(
              getIconByInt(collectType),
              color: widget.color,
            ),
          );
        }
      },
      menuChildren: const [0, 1, 2, 4]
          .map(
            (type) => MenuItemButton(
              onPressed: () {
                if (type != collectType && mounted) {
                  collectController.addCollect(
                    widget.bangumiItem,
                    type: type,
                  );
                }
              },
              child: Container(
                height: 48,
                constraints: BoxConstraints(minWidth: 112),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        getIconByInt(type),
                        color: type == collectType
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      SizedBox(width: 4),
                      Text(
                        ' ${getTypeStringByInt(type)}',
                        style: TextStyle(
                          color: type == collectType
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
