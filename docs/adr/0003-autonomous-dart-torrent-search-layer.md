# 3. 自治 Dart 资源搜索层与零外置服务架构 (Autonomous Dart Torrent Search Layer & Zero-External-Daemon Architecture)

* 状态: 已接受 (Accepted)
* 日期: 2026-10-05

## 背景 (Context)

在评估 Prowlarr 深度整合方案的过程中，曾探索过将其 C# 服务端本体打包进 App 或采用外部常驻后台服务的方式。然而，经过对 Android、iOS、macOS、Windows 和 Linux 五大平台特性的深入分析与事实核查：
1. **移动端绝对屏障**：iOS 系统的严格沙盒机制严禁派生外部子进程（`fork`/`exec`）以及在后台长期常驻运行 Web 监听端口（切后台几秒内即被系统冻结）；Android 系统同样对后台守护进程实行激进的电池优化与 OOM 杀进程策略。
2. **运行时代价与应用形态倒挂**：Prowlarr 作为完整的 ASP.NET Core + .NET 8 栈，单个平台运行时体积达 80MB~120MB，常驻内存 150MB~300MB，将庞大的后端服务强行捆绑进轻量前端客户机违背了跨平台应用的工程常理。
3. **行业成功标杆的启示**：Android 领域的成熟开源项目 **TorrentSearch** 证明了“移动端多 Provider 并行搜索 + 外挂 Torznab 连接”的产品形态在移动端完全可行。核心价值在于**“高质量 Provider 的数量与可用性维护”**，而不是技术实现本身。

因此，必须确立明确的技术路线：**坚决不依赖任何外置后端服务，在 Kazumi 内部打造完全自治的“纯 Dart Torrent Search 层”**。

## 决策 (Decision)

1. **确立“单 App 闭环、零外置后端依赖”的最高原则**：
   - 彻底放弃将 Prowlarr 本体或任何外部守护进程打包进 App 安装包的想法；
   - 资源搜索全流程（关键词编码、并发请求、DOM/JSON 抽取、数据归一化、排序去重）100% 在 Flutter/Dart 主进程内原生自洽完成。

2. **核心驱动：声明式 Cardigann 引擎为第一公民**：
   - 以纯 Dart 实现的 `CardigannQueryExecutor` 作为底层执行器，直接解释执行兼容 Prowlarr/Jackett 规范的 Cardigann `.yml` 索引器规则；
   - 站点改版、修复或新增仅表现为几 KB 的纯文本 YAML 规则更新，完全免编译、免发版。

3. **破解“高质量 Provider 与站点可用性维护”难题**：
   - **预置高质量种子源**：系统开箱预置动漫花园、蜜柑计划、Nyaa、The Pirate Bay、1337x、Torrents.csv 等 6~8 个经过实测验证的国内外主流高质量站点；
   - **去中心化规则订阅（Rule Repository Subscription）**：引入类似 Mihon / Clash 的规则订阅源机制。客户端定期或手动拉取托管在 GitHub/CDN 上的 `index.json` 索引器仓库，一键热更新所有失效站点规则；
   - **备用域名与故障转移 (Mirror Fallback)**：允许在索引器配置中提供备用镜像站列表，主域名无法连接时自动无感切换。

4. **Prowlarr / Torznab 的精准定位**：
   - Prowlarr / Jackett 降级为**纯粹的外部客户端连接（Torznab Client，作为高级/实验性扩展源）**；
   - 针对拥有家庭 NAS / Docker 服务的专业 PT 用户，提供输入 Base URL + API Key 连接其自建实例的能力，作为本地搜索流的补充并发源，但绝不成为普通用户使用的前提条件。

## 后果 (Consequences)

### 正面收益 (Positive)
- **100% 跨 5 大平台平权**：在 iOS（完全合规 App Store / TestFlight）、Android、macOS、Windows 和 Linux 上行为绝对一致，没有系统级特权要求和后台被杀风险。
- **极致轻量**：没有沉重的 .NET 运行时或本地服务器端口冲突，内存开销近乎为零，应用冷启动毫秒级响应。
- **生态与维护解耦**：继承了 Prowlarr 社区最庞大的 Cardigann YAML 规则资产，同时通过规则订阅源彻底解除了客户端代码发版与站点改版之间的耦合。

### 代价与对策 (Trade-offs & Mitigations)
- **规则质量的持续维护**：需要维护一个社区公开的 Cardigann YAML 索引器订阅源，以便在公共 BT 站点改版时及时合并 PR 并自动推送给全体用户。
