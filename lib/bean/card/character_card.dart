import 'package:flutter/services.dart';
import 'package:kazumi/bean/dialog/dialog_helper.dart';
import 'package:kazumi/bean/widget/app_context_menu.dart';
import 'package:kazumi/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:kazumi/modules/characters/character_item.dart';
import 'package:kazumi/pages/info/character_page.dart';

class CharacterCard extends StatelessWidget {
  const CharacterCard({
    super.key,
    required this.characterItem,
  });

  final CharacterItem characterItem;

  void _openDetail(BuildContext context) {
    showModalBottomSheet(
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 3 / 4,
        maxWidth: (Utils.isDesktop() || Utils.isTablet())
            ? MediaQuery.of(context).size.width * 9 / 16
            : MediaQuery.of(context).size.width,
      ),
      clipBehavior: Clip.antiAlias,
      context: context,
      builder: (context) {
        return CharacterPage(characterID: characterItem.id);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tile = ListTile(
      leading: CircleAvatar(
        backgroundImage: characterItem.avator.grid.isEmpty
            ? const NetworkImage('https://bangumi.tv/img/info_only.png')
            : NetworkImage(characterItem.avator.grid),
      ),
      title: Text(
        characterItem.name,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      subtitle: characterItem.actorList.isNotEmpty
          ? Text(characterItem.actorList[0].name)
          : null,
      trailing: Text(characterItem.relation),
      onTap: () => _openDetail(context),
    );

    return AppContextMenu(
      itemsBuilder: (context) => [
        AppMenuAction(
          title: '查看角色详情',
          icon: Icons.person_search_rounded,
          onSelected: () => _openDetail(context),
        ),
        const AppMenuSeparator(),
        AppMenuAction(
          title: '复制角色名称',
          icon: Icons.copy_rounded,
          onSelected: () async {
            await Clipboard.setData(ClipboardData(text: characterItem.name));
            if (context.mounted) {
              KazumiDialog.showToast(message: '已复制角色名称', context: context);
            }
          },
        ),
        if (characterItem.actorList.isNotEmpty)
          AppMenuAction(
            title: '复制声优 (${characterItem.actorList[0].name})',
            icon: Icons.record_voice_over_rounded,
            onSelected: () async {
              await Clipboard.setData(
                  ClipboardData(text: characterItem.actorList[0].name));
              if (context.mounted) {
                KazumiDialog.showToast(message: '已复制声优名称', context: context);
              }
            },
          ),
        AppMenuAction(
          title: '在浏览器中打开 Bangumi 页面',
          icon: Icons.open_in_browser_rounded,
          onSelected: () =>
              Utils.openUrl('https://bgm.tv/character/${characterItem.id}'),
        ),
      ],
      child: tile,
    );
  }
}
