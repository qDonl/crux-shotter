# CruxShotter

CruxShotter 是一个 macOS 14+ 的菜单栏截图工具：区域/全屏截图、标注、贴图、文字识别（OCR）。使用 Swift 6、AppKit 与 SwiftUI 构建。

## 安装（0.0.2-alpha）

1. 从 GitHub Release 下载 `CruxShotter-0.0.2-alpha.dmg`（仓库目前为私有，需要有访问权限）：
   <https://github.com/qDonl/crux-shotter/releases>
2. 打开 DMG，把 CruxShotter 拖到「应用程序」。
3. 首次打开会被 Gatekeeper 拦截：alpha 版本是 ad-hoc 签名、未经公证。打开「系统设置 › 隐私与安全性」，
   在页面下方点「仍要打开」；或者在终端执行：

   ```bash
   xattr -dr com.apple.quarantine /Applications/CruxShotter.app
   ```

4. 按引导授予「屏幕录制」权限，然后重启 CruxShotter（引导窗口里的「我已授权，立即重启」）。

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

### 自动更新（Sparkle）

配置 EdDSA 密钥之前自动更新处于关闭状态：

1. 运行一次 Sparkle 的 `generate_keys`（私钥保存在登录钥匙串中）。
2. 把输出的公钥填到 `project.yml` 的 `SPARKLE_PUBLIC_KEY`。
3. 导出私钥（`generate_keys -x file`），保存为 GitHub secret `SPARKLE_PRIVATE_KEY`。

在此之前，菜单中的「检查更新…」和设置里的按钮均为灰色。

## 许可证

MIT
