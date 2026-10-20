# 1. Cardigann 兼容的去中心化索引器插件架构 (Cardigann Indexer Plugin Architecture)

* 状态: 已接受 (Accepted)
* 日期: 2026-10-05

## 背景 (Context)

Kazumi 从番剧客户端演进为全品类资源搜索与下载客户端。在早期的资源搜索中，采用针对特定站点（如 Mikan、Nyaa、PirateBay 等）手写 Dart 类的硬编码方式，无法满足开放平台与第三方社区开发者自由扩充站点的诉求。

由于 Flutter 生产环境采用 AOT 原生编译，剥离了反射与动态代码执行能力，iOS App Store 审核准则（Guideline 2.5.2）亦禁止加载未经签名的外部机器码。因此，如何设计一套轻量、安全、跨平台、且拥有丰富现成站点生态的动态脚本规范成为核心架构挑战。

## 决策 (Decision)

我们决定**全面对齐 Prowlarr / Jackett 的 Cardigann 规范**，在 Kazumi 内部实现一套原生的声明式 Indexer 解析与执行引擎，并采用去中心化订阅模型，核心决策如下：

1. **引擎规范 1:1 兼容 Cardigann YAML**：
   - 索引器不采用图灵完备的动态脚本，而是使用纯文本声明式 Cardigann `.yml` 规则文件（定义 `search.paths`, `search.rows.selector`, `search.fields.*` 等）。
   - 彻底规避代码注入风险与应用商店审核风险，并直接复用 Jackett / Prowlarr 社区积累的 500+ 个现成站点规则。

2. **领域模型统一至 `Plugin` 体系**：
   - 泛化现有的 `Plugin` 领域模型，划分为 `VideoPlugin`（提取流媒体分集与播放直链）与 `IndexerPlugin`（索引资源与磁力链接）。
   - 两者共享统一的插件中心管理、仓库订阅更新、本地导入导出与存储生命周期。

3. **双模反爬与 Cloudflare 智能自愈**：
   - 默认通过轻量高速的 Dart 原生 HTTP 进行 DOM 选择器提取。
   - 遭遇 Cloudflare 5 秒盾（403/503 或 `cf-ray` 标识）时，自动唤起后台 Headless WebView 穿透验证，提取 `cf_clearance` Cookie 并反哺给 HTTP 请求池自动重试。同时支持规则内显式静态声明 `useWebview: true`。

4. **分类标准对齐 Torznab Category 规范**：
   - 严格采用工业标准的 Torznab 数字分类（1000 音频, 2000 电影, 3000 电子书, 4000 游戏, 5000 电视剧, 5070 动漫），并在 UI 统一过滤栏中建立映射。

5. **私有站（PT 站）凭据本地安全存储**：
   - 根据 Cardigann 规则中声明的 `settings` 自动渲染动态配置表单，支持用户配置 Cookie / Passkey / API Key。凭据仅加密保存在本地安全存储中，请求时动态注入 Header/Query。

6. **去中心化订阅仓库与渐进式流式响应**：
   - 采用轻量级清单 `index.json` 模式，支持用户订阅任意第三方 GitHub / Gitee / CDN 仓库，并支持本地单文件拖拽导入。
   - 检索时采用 6~8 并发滑动窗口调度池，支持流式逐步追加（Progressive Yielding）与单站超时容错。

## 后果 (Consequences)

### 正面收益 (Positive)
- **生态冷启动零门槛**：可直接导入现成的开源 Cardigann 规则，无需社区重新学习专用语言手写爬虫。
- **极致安全合规**：声明式规则不执行任何外部二进制或任意代码，保障跨平台稳定与安全合规。
- **用户体验极高**：流式追加让搜索首屏秒级呈现，即使存在个别慢速或被墙站点亦不会卡死主界面。

### 代价与局限 (Negative & Mitigations)
- **非标准加密站受限**：极少数需要复杂自定义 JS 动态时间戳签名的站点无法单纯通过 YAML 声明处理；引擎后续可通过扩展预置过滤器函数（如 `filters: [name: md5]`）予以补充。
- **DOM 解析引擎依赖**：需要维护稳健的 CSS/XPath 节点提取器及测试用例。
