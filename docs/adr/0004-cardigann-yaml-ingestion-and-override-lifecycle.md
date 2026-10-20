# 4. Cardigann YAML 规范原样保持、多渠道导入与覆盖重置生命周期 (Cardigann YAML Ingestion and Override Lifecycle)

* 状态: 已接受 (Accepted)
* 日期: 2026-10-05

## 背景 (Context)

在全网多品类资源搜索体系的演进中，我们面临两类主流开源参考设计的取舍：
1. **qBittorrent 生态**：采用 Python 脚本爬虫（`*.py`）。
2. **Prowlarr / Jackett 生态**：采用声明式 Cardigann 规则（`*.yml`）。

针对“是否应将 Python 爬虫转换为硬编码 Dart 内置源”以及“YAML 规则是否能原样保持并支持用户自行上传新站”，我们需要从代码维护性、多平台原生 AOT 编译限制、应用商店审核合规性及社区生态复用度等维度做出严格的架构定论。

## 决策 (Decision)

我们做出以下四项核心决策：

1. **坚决不编写任何硬编码 Dart 爬虫类，所有单站 100% 统一为 Cardigann YAML**：
   - 拒绝将 Python 插件重写为硬编码 Dart 类（违反领域模型中的 `_Avoid_: Hardcoded scraper, custom Dart source class`）。
   - 因为 Dart 编译为机器码，一旦单站前端改版，硬编码爬虫将全量失效且必须发版热更新或过审；而 Cardigann YAML 是纯声明式规则，不仅在逻辑上与 Python 爬虫完全等价，更具备极低维护成本与即时更新能力。
   - 所有所谓的“内置源”，统一作为 App 打包资产目录（`assets/indexers/*.yml`）中的标准 Cardigann YAML，由底层的纯 Dart Cardigann 引擎统一执行。

2. **100% 原样保持 Cardigann YAML 规范，严禁任何私有方言魔改**：
   - 解析引擎严格对齐 Prowlarr / Jackett 官方 v11 规范（`site`, `links`, `caps.categorymappings`, `search.paths`, `search.rows.selector`, `search.fields.*`, `settings`, `filters` 等）。
   - 用户与开发者可直接复制 Prowlarr 官方 577+ 仓库或社区第三方发布的任何原始 `.yml` 规则，无需任何二次转译或格式调整即可在 Kazumi 中直接运行。

3. **支持多渠道规则导入与保存前即时测试抓取（Dry-Run）**：
   - 导入对话框集成“本地文件选择（`.yml`/`.yaml`）+ 剪贴板文本粘贴 + 远程 URL 一键拉取（GitHub Raw / Gitee / CDN）”三合一能力。
   - 提供强制性测试抓取（Dry-Run）工具链：允许用户输入测试关键词（如 `1080p`），调用引擎发起真实请求并展示耗时、匹配条数及前 3 条样本数据卡片，让规则有效性在保存前所见即所得。

4. **确立“用户覆盖优先，支持一键重置为官方预置”的规则生命周期**：
   - 当用户上传或编辑的 YAML 与官方内置规则 ID 冲突时，系统允许覆写并在本地 Hive 中优先激活用户版本。
   - 界面清晰标注文档状态徽章（`官方内置`、`已覆写内置`、`用户自定义`）。
   - 对于已覆写的内置规则，提供“查看/编辑 YAML 源码”与“恢复官方预置版本”操作；对于纯自定义规则，提供安全删除操作。

## 后果 (Consequences)

### 正面收益 (Positive)
- **单一执行引擎**：全站索引器无论预置还是用户新增，均由 `CardigannParser` + `CardigannQueryExecutor` 统一处理，不存在硬编码爬虫与解释器双轨并存的异构债务。
- **生态零门槛**：全网现有 500+ Prowlarr Cardigann 规则即插即用，未来新站出现只需写 20 行 YAML 即可支持。
- **安全与合规**：纯文本声明式提取，无任意代码执行风险，完全符合各大应用商店（包括 iOS App Store Guideline 2.5.2）审核规范。
- **容错与回退**：即使修改乱了内置规则，随时一键重置回初始状态。

### 代价与局限 (Negative & Mitigations)
- **极少数动态混淆站**：对于极少数需要客户端生成非对称动态加密签名的站点，纯声明式 YAML 无法直接计算；后续可通过在过滤管线（`CardigannFilterPipeline`）中持续扩充标准算法（如 `md5`, `sha256`, `base64` 等）予以覆盖。
