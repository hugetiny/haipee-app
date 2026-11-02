import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:haipee/modules/rule_speed_test/rule_speed_test_provider.dart';

/// 全局常驻后台规则测速进度条横幅
/// 无论切换到任何子页面，均在顶部清晰显示后台测速进度并支持随时取消
class RuleSpeedTestBanner extends ConsumerWidget {
  const RuleSpeedTestBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ruleSpeedTestProvider);
    if (!state.isTesting) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress =
        state.totalCount > 0 ? (state.testedCount / state.totalCount) : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withAlpha(220),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.primary.withAlpha(90),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '⚡ 后台全自动测速中 [${state.categoryLabel}] · 已测 ${state.testedCount}/${state.totalCount}'
                  ' (可用: ${state.passedCount}, 失败: ${state.failedCount})'
                  '${state.currentTestingItem.isNotEmpty ? " · ${state.currentTestingItem}" : ""}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () =>
                    ref.read(ruleSpeedTestProvider.notifier).cancel(),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('停止测速'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
            ),
          ),
        ],
      ),
    );
  }
}
