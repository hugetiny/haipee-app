# 2. 纯粹 Cardigann 引擎重构与动态索引器标识解耦 (Pure Cardigann Engine & Dynamic Indexer Architecture)

* 状态: 已接受 (Accepted)
* 日期: 2026-10-05

## 背景 (Context)

在 ADR 0001 实现了初步的 Cardigann YAML 解析引擎后，系统仍处于新旧双轨混合状态：
1. 存在硬编码单站 Dart 爬虫类（`NyaaSource`, `DmhySource`, `MikanSource`, `PirateBaySource`, `TorrentsCsvSource`），与预置的 Cardigann YAML 规则产生逻辑重复与维护双重负担。
2. `TorrentSourceType` 是固定枚举，硬编码了各内置站点名称，导致所有外部或用户导入的 Cardigann YAML 只能被笼统归为 `indexerPlugin`，无法在 UI 层面进行细粒度筛选和溯源。
3. 现有的 DOM 执行器仅支持 HTML 响应解析，而部分现代化 Tracker / 索引站（如 Torrents.csv 及现代私有 PT 站）返回 JSON 响应。

为了让 Kazumi 成为真正 100% 围绕 Cardigann YAML 和 Prowlarr/Torznab 体系运转的纯粹、开放的资源搜索平台，需要消除双轨制并完成架构闭环。

## 决策 (Decision)

1. **废止硬编码 Dart 爬虫，全面转向纯 Cardigann 引擎驱动**：
   - 彻底废除并移除所有单站 Dart 抓取代码；
   - 所有内置站点统一以声明式 `assets/indexers/*.yml` 的形式打包预置（补齐 `dmhy.yml` 与 `torrentscsv.yml` 等），应用初始化时自动载入执行，消除代码冗余。

2. **动态 Indexer 标识体系与解耦**：
   - 废除将具体站点名称硬编码在枚举中的旧模式；
   - 抽象为动态的 `indexerId` 与 `indexerName`，所有站点（无论是系统预置还是用户导入）均作为 `CardigannIndexer` 实例存在；
   - 远程 Prowlarr/Torznab 聚合实例保留作为独立的 Torznab Client 网关，与本地 Cardigann 引擎并列调度，并在结果中标记各站索引名。

3. **内置索引器生命周期受保护机制**：
   - 预置索引器标记为 `isBuiltIn: true`，在 UI 中受保护不可物理删除，但允许用户灵活启停、修改配置（如备用镜像站域名）和一键恢复默认。

4. **Cardigann 双模载荷解析（HTML DOM + JSON API）**：
   - 扩展 `CardigannQueryExecutor`，支持检测和解析 JSON 载荷（基于轻量 JSONPath / 点路径选择器），共享同一套 Filter Pipeline 进行字段过滤与时间/大小换算。

5. **轻量静态凭据配置流**：
   - 私有 PT 站通过 Cardigann 的 `settings` 块提供静态凭据（Cookie / Passkey / ApiKey）输入，安全保存在本地，发起请求时自动注入，不引入脆弱的自动化登录表单状态机。

## 后果 (Consequences)

### 正面收益 (Positive)
- **单一真实来源 (Single Source of Truth)**：任何站点的修正、更新、替换只需改动对应 `.yml` 文本即可热更新，无需重新编译 Dart 代码。
- **纯粹的开放架构**：内置站点与第三方社区插件完全平等，统一通过相同的解析管线运行。
- **扩展性翻倍**：原生支持 JSON API 站后，Cardigann 规则生态兼容率从 ~75% 提升至接近 100%。

### 代价与对策 (Trade-offs & Mitigations)
- **旧代码清理与回归测试**：废弃旧 Source 类需要对 `TorrentSearchService`、`ResourceSearchContent` 和相关单元测试进行彻底的重构与回归验证。
