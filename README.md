# CruxShotter

CruxShotter 是一个 macOS 14+ 的菜单栏截图工具：区域/全屏截图、标注、贴图、文字识别（OCR）。使用 Swift 6、AppKit 与 SwiftUI 构建。

箭头标注支持经典实心、精细开口、渐粗聚焦、双向对照、虚线关联和手绘弧箭。选择箭头工具后，点击属性行的箭头样式按钮切换；手绘弧箭选中后可拖动中间控制点调整弯曲。截图和贴图编辑使用同一套样式，最近使用的样式会保留。

## 安装（0.0.4-alpha）

1. 从 GitHub Release 下载 `CruxShotter-0.0.4-alpha.dmg`：
   <https://github.com/qDonl/crux-shotter/releases>
2. 打开 DMG，把 CruxShotter 拖到「应用程序」。
3. 首次打开会被 Gatekeeper 拦截：alpha 版本是 ad-hoc 签名、未经公证。打开「系统设置 › 隐私与安全性」，
   在页面下方点「仍要打开」；或者在终端执行：

   ```bash
   xattr -dr com.apple.quarantine /Applications/CruxShotter.app
   ```

4. 按引导授予「屏幕录制」权限，然后重启 CruxShotter（引导窗口里的「重启并开始使用」或「已授权，重启应用」）。

注意事项：

- **每个新的 alpha 构建都需要重新授权**：ad-hoc 签名每次构建都不同，系统会把新版本当成另一个 App。
  升级后请在「系统设置 › 隐私与安全性 › 录屏与系统录音」里删除旧的 CruxShotter 条目，再重新添加（或重新授权）并重启。
- 第一次保存到「桌面」等目录时，系统可能会弹窗请求文件夹访问权限，允许即可。
- 贴图不会出现在截图里（截图时会排除 CruxShotter 自己的窗口）。

### Homebrew

将在第一个正式签名（Developer ID + 公证）版本发布后提供。Cask 已在仓库中（`Casks/crux-shotter.rb`），届时可以：

```bash
brew tap qDonl/crux-shotter https://github.com/qDonl/crux-shotter
brew install --cask crux-shotter
```

## 构建

```bash
# 运行核心库单元测试
swift test --package-path CruxShotKit

# 生成 Xcode 工程（需要 XcodeGen）并构建 App
xcodegen generate
xcodebuild -project CruxShot.xcodeproj -scheme CruxShot -configuration Debug build
```

## 发布

`scripts/build-release.sh <version> [--skip-sign]` 生成 `build/CruxShotter-<version>.dmg` 并打印其 sha256
（`--skip-sign` 生成 ad-hoc 签名、未公证的构建）。推送 `v*` tag 会运行 `.github/workflows/release.yml`，
签名、公证并发布 DMG 和 `appcast.xml`；缺少签名相关 secrets（`DEVELOPER_ID_CERT_P12`、`DEVELOPER_ID_CERT_PASSWORD`、
`APPLE_ID`、`APPLE_TEAM_ID`、`APPLE_APP_PASSWORD`）时只输出一条提示。发布后更新 `Casks/crux-shotter.rb` 中的
`version`（tag 去掉开头的 `v`，如 `0.0.1-alpha`）和 `sha256`。

### 更新检测

菜单栏和「设置 → 关于」均可检查 GitHub Releases，无需登录 GitHub。默认在启动后检查更新，每 24 小时最多自动检查一次，可在关于页关闭。后台仅在发现新版本时提示，同一版本只提示一次；手动检查会明确显示新版、已是最新或失败原因。

alpha / beta 等预览构建会检查后续预览版及正式版；正式构建仅检查正式版。版本按数值和预发布标识比较，避免把 `0.0.10` 当成比 `0.0.9` 更旧。发现新版后可以下载 DMG 或查看发布说明，当前采用手动安装。

完整发布版本（例如 `0.0.3-alpha`）由 `CRUXSHOT_RELEASE_VERSION` 写入 App；发布脚本会自动设置该值。发布时请保留 `CruxShotter-<版本>.dmg` 的命名并将文件上传完成，更新检测只选择具备有效安装包的版本。

### 应用内自动安装（Sparkle，可选）

检测更新无需 Sparkle 密钥。若之后启用 Sparkle 的应用内下载和安装，还需配置签名密钥及 appcast：

1. 运行一次 Sparkle 的 `generate_keys`（私钥保存在登录钥匙串中）。
2. 把输出的公钥填到 `project.yml` 的 `SPARKLE_PUBLIC_KEY`。
3. 导出私钥（`generate_keys -x file`），保存为 GitHub secret `SPARKLE_PRIVATE_KEY`。

配置完成后，应用切换为 Sparkle 更新流程；未配置时使用上述 GitHub 更新检测。

## 许可证

MIT
