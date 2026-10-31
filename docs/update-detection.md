# GitHub 更新检测

未配置 Sparkle EdDSA 公钥的构建使用 GitHub Releases 检测；配置后保留原 Sparkle 更新流程。

- 手动入口：菜单栏「检查更新…」、设置 → 关于。
- 后台策略：启动 5 秒后检查，默认开启；成功检查后 24 小时内不重复自动请求。失败不写入成功时间，不抢焦点。同一新版只自动提示一次。手动检查不受时间与提示去重限制。
- 版本通道：通过 `CruxShotReleaseVersion` 读取完整版本。预览构建接受后续预览及正式版，正式构建排除预览版；支持数字版本及预发布标识比较，忽略构建元数据。发布脚本会同时设置数字版本和完整发布版本。
- 数据源：匿名请求公开仓库 `/repos/qDonl/crux-shotter/releases?per_page=100`，从最近 100 个发布中选择版本最高的有效候选，不依赖返回顺序。GitHub 的列表接口可匿名访问公开发布，`latest` 不适用于当前预发布通道：[GitHub Releases 文档](https://docs.github.com/en/rest/releases/releases)。
- 安装包：只接受已上传且大小非零的 `CruxShotter-<版本>.dmg`，跳过草稿和异常版本；页面 / 下载链接限制在当前 GitHub 仓库的 HTTPS 路径。找不到有效候选时报告无法找到安装包，不声称已是最新。
- 安装方式：用户确认后打开 DMG 下载地址或发布说明，不自动替换正在运行的 App。
- 错误与并发：请求超时 20 秒；区分 HTTP 错误、限流、无效响应和网络失败。同一时刻只有一个检查请求，检查期间入口显示状态。

验证命令：

```sh
swift test --package-path CruxShotKit
# 包含无凭据访问真实公开仓库的网络集成测试
CRUXSHOT_LIVE_UPDATE_TEST=1 swift test --package-path CruxShotKit
```

2026-10-31 验证：183 项测试通过（包含匿名网络集成测试及真实屏幕捕获）；Debug App 构建通过。未使用界面自动化。

测试覆盖版本先后、预览与正式通道、当前 / 较新本地版本、乱序列表、草稿、缺失与异常安装包、恶意下载域名、限流、服务错误、无效响应、重复请求、后台间隔、跨启动通知去重和设置持久化。
