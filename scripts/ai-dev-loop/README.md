# AI Development Loop

AI 自主测试修复开发闭环系统，可在 10 小时内持续自动运行测试、分析失败、生成修复并验证。

## 架构

```
测试层 (分层快速反馈)
├── Vitest 单元测试 (2分钟)
├── Vitest 集成测试 (3分钟)
└── Playwright E2E (15分钟，WebDriver)

失败处理
├── 解析错误信息
├── 分类失败类型
├── 调用对应 Agent 修复
└── 验证修复结果

状态管理
├── Checkpoint (每30分钟保存)
├── Git snapshot (启动时)
└── 日志记录
```

## 使用方式

```bash
# 启动 10 小时自主开发循环
bun run ai:dev

# 指定运行时长
bun run ai:dev --duration=5

# 干运行模式 (只分析不修复)
bun run ai:dev --dry-run

# 从 checkpoint 恢复
bun run ai:dev --resume-latest

# 只运行特定测试
bun run ai:dev --test=tests/e2e/openai.spec.ts

# 查看可用 checkpoints
bun run ai:dev:checkpoints
```

## 文件结构

```
scripts/ai-dev-loop/
├── index.ts           # CLI 入口
├── loop.ts            # 主循环
├── types.ts           # 类型定义
├── test-runner.ts     # 测试执行
├── failure-parser.ts  # 失败解析
├── fix-orchestrator.ts # 修复编排
├── checkpoint.ts      # 状态保存
└── logger.ts          # 日志

ai-loop-logs/          # 运行时数据
├── checkpoints/       # 保存的状态
├── logs/             # 执行日志
└── failures/         # 失败记录
```

## 修复策略

根据失败类型调用不同 Agent：

| 失败类型 | 使用的 Agent |
|---------|-------------|
| 编译错误 | build-error-resolver |
| 类型错误 | build-error-resolver |
| 运行时错误 | code-reviewer |
| 断言失败 | tdd-guide |
| 超时错误 | code-reviewer |
| Flaky 测试 | code-reviewer |

## 安全措施

- **最大尝试次数**: 每个失败最多修复 3 次
- **Git snapshot**: 启动时自动创建 stash
- **手动介入标记**: 超过尝试次数的失败标记为 manual-required
- **Checkpoint**: 每 30 分钟保存进度

## 状态流转

```
pending → fixing → fixed → 从 pending 列表移除
                    ↓
                  failed → rollback → pending (重试)
                    ↓
              超过3次 → manual-required
```
