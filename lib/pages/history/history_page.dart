import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/providers/riverpod_compat.dart';
import 'package:haipee/bean/appbar/sys_app_bar.dart';
import 'package:haipee/bean/card/bangumi_history_card.dart';
import 'package:haipee/bean/dialog/dialog_helper.dart';
import 'package:haipee/pages/history/history_controller.dart';
import 'package:haipee/pages/history/providers.dart';
import 'package:haipee/utils/constants.dart';
import 'package:haipee/l10n/generated/translations.g.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

/// Provider for show delete button state
final historyShowDeleteProvider =
    StateProvider.autoDispose<bool>((ref) => false);

class _HistoryPageState extends ConsumerState<HistoryPage>
    with SingleTickerProviderStateMixin {
  late HistoryController historyController;

  @override
  void initState() {
    super.initState();
    historyController = ref.read(historyProvider.notifier);
  }

  void onBackPressed(BuildContext context) {
    if (HaipeeDialog.observer.hasHaipeeDialog) {
      HaipeeDialog.dismiss();
      return;
    }
  }

  void showHistoryClearDialog() {
    HaipeeDialog.show(
      builder: (context) {
        final t = context.t;
        return AlertDialog(
          title: Text(t.library.history.manage.title),
          content: Text(t.library.history.manage.confirmClear),
          actions: [
            TextButton(
              onPressed: () {
                HaipeeDialog.dismiss();
              },
              child: Text(
                t.library.history.manage.cancel,
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            ),
            TextButton(
              onPressed: () {
                HaipeeDialog.dismiss();
                try {
                  historyController.clearAll();
                } catch (_) {}
              },
              child: Text(t.library.history.manage.confirm),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(historyProvider);
    final showDelete = ref.watch(historyShowDeleteProvider);

    return Builder(builder: (context) {
      return PopScope(
        canPop: true,
        onPopInvokedWithResult: (bool didPop, Object? result) async {
          onBackPressed(context);
        },
        child: Scaffold(
          appBar: SysAppBar(
            title: Text(context.t.library.history.title),
            actions: [
              IconButton(
                  onPressed: () {
                    ref.read(historyShowDeleteProvider.notifier).state =
                        !showDelete;
                  },
                  icon: showDelete
                      ? const Icon(Icons.edit_outlined)
                      : const Icon(Icons.edit))
            ],
          ),
          body: SafeArea(bottom: false, child: renderBody(state, showDelete)),
          floatingActionButton: FloatingActionButton(
            tooltip: context.t.library.history.manage.title,
            child: const Icon(Icons.clear_all),
            onPressed: () {
              showHistoryClearDialog();
            },
          ),
        ),
      );
    });
  }

  Widget renderBody(HistoryState state, bool showDelete) {
    if (state.histories.isNotEmpty) {
      return contentGrid(state, showDelete);
    } else {
      return Center(
        child: Text(context.t.library.history.empty),
      );
    }
  }

  Widget contentGrid(HistoryState state, bool showDelete) {
    final double width = MediaQuery.sizeOf(context).width;
    int crossCount = 1;
    if (width > LayoutBreakpoint.compact['width']!) {
      crossCount = 2;
    }
    if (width > LayoutBreakpoint.medium['width']!) {
      crossCount = 3;
    }
    if (width > 1300) {
      crossCount = 4;
    }
    if (width > 1800) {
      crossCount = 5;
    }
    if (width > 2300) {
      crossCount = 6;
    }
    if (width > 2800) {
      crossCount = (width / 420.0).floor().clamp(6, 10);
    }
    double cardHeight = 120;

    return CustomScrollView(
      slivers: [
        SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            mainAxisSpacing: StyleString.cardSpace - 2,
            crossAxisSpacing: StyleString.cardSpace,
            crossAxisCount: crossCount,
            mainAxisExtent: cardHeight + 12,
          ),
          delegate: SliverChildBuilderDelegate(
            (BuildContext context, int index) {
              return state.histories.isNotEmpty
                  ? BangumiHistoryCardV(
                      showDelete: showDelete,
                      cardHeight: cardHeight,
                      historyItem: state.histories[index])
                  : null;
            },
            childCount:
                state.histories.isNotEmpty ? state.histories.length : 10,
          ),
        ),
      ],
    );
  }
}
