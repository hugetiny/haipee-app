import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/bean/widget/app_context_menu.dart';
import 'package:haipee/modules/staff/staff_item.dart';
import 'package:haipee/utils/utils.dart';

class StaffCard extends StatelessWidget {
  const StaffCard({
    super.key,
    required this.staffFullItem,
  });

  final StaffFullItem staffFullItem;

  @override
  Widget build(BuildContext context) {
    final name = staffFullItem.staff.nameCN.isNotEmpty
        ? staffFullItem.staff.nameCN
        : staffFullItem.staff.name;

    final tile = ListTile(
      leading: CircleAvatar(
        backgroundImage: staffFullItem.staff.images?.grid == null
            ? const NetworkImage('https://bangumi.tv/img/info_only.png')
            : NetworkImage(staffFullItem.staff.images!.grid),
      ),
      title: Text(
        staffFullItem.staff.name,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
      subtitle: staffFullItem.staff.nameCN.isNotEmpty
          ? Text(staffFullItem.staff.nameCN)
          : null,
      trailing: Text(staffFullItem.positions.isNotEmpty
          ? (staffFullItem.positions[0].type.cn)
          : ''),
    );

    return AppContextMenu(
      itemsBuilder: (context) => [
        AppMenuAction(
          title: '复制演职员名称',
          icon: Icons.copy_rounded,
          onSelected: () async {
            await Clipboard.setData(ClipboardData(text: name));
            if (context.mounted) {
              HaipeeDialog.showToast(message: '已复制演职员名称', context: context);
            }
          },
        ),
        if (staffFullItem.staff.nameCN.isNotEmpty &&
            staffFullItem.staff.name != staffFullItem.staff.nameCN)
          AppMenuAction(
            title: '复制日文原名 (${staffFullItem.staff.name})',
            icon: Icons.translate_rounded,
            onSelected: () async {
              await Clipboard.setData(
                  ClipboardData(text: staffFullItem.staff.name));
              if (context.mounted) {
                HaipeeDialog.showToast(message: '已复制原名', context: context);
              }
            },
          ),
        AppMenuAction(
          title: '在浏览器中打开 Bangumi 页面',
          icon: Icons.open_in_browser_rounded,
          onSelected: () =>
              Utils.openUrl('https://bgm.tv/person/${staffFullItem.staff.id}'),
        ),
      ],
      child: tile,
    );
  }
}
