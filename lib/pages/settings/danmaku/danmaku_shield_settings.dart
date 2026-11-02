import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/bean/appbar/sys_app_bar.dart';
import 'package:haipee/l10n/generated/translations.g.dart';
import 'package:haipee/pages/setting/setting_controller.dart';

class DanmakuShieldSettings extends ConsumerStatefulWidget {
  const DanmakuShieldSettings({super.key});

  @override
  ConsumerState<DanmakuShieldSettings> createState() =>
      _DanmakuShieldSettingsState();
}

class _DanmakuShieldSettingsState extends ConsumerState<DanmakuShieldSettings> {
  final TextEditingController textEditingController = TextEditingController();

  @override
  void dispose() {
    textEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shieldState = ref.watch(myControllerProvider);
    final controller = ref.read(myControllerProvider.notifier);
    final playerTexts = context.t.settings.player;
    final shieldDescription = playerTexts.danmakuShieldDescription;
    final shieldCount = playerTexts.danmakuShieldCount
        .replaceFirst('{count}', '${shieldState.shieldList.length}');

    void addKeyword() {
      controller.addShieldList(textEditingController.text);
    }

    return Scaffold(
      appBar: SysAppBar(
        title: Text(playerTexts.danmakuShield),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            controller: textEditingController,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: playerTexts.danmakuShieldInputHint,
              suffixIcon: TextButton.icon(
                onPressed: () {
                  addKeyword();
                },
                icon: const Icon(Icons.add),
                label: Text(playerTexts.add),
              ),
            ),
            onSubmitted: (_) {
              addKeyword();
            },
          ),
          const SizedBox(height: 12),
          Text(shieldDescription),
          const SizedBox(height: 12),
          Text(shieldCount),
          const SizedBox(height: 12),
          Wrap(
            runSpacing: 12,
            spacing: 12,
            children: shieldState.shieldList
                .map(
                  (item) => Chip(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    backgroundColor:
                        Theme.of(context).colorScheme.secondaryContainer,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    side: BorderSide.none,
                    label: Text(
                      item,
                      style: const TextStyle(fontSize: 14),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    deleteButtonTooltipMessage: '',
                    onDeleted: () {
                      controller.removeShieldList(item);
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
