# 应用内更新

配置 `SUPublicEDKey` 的构建使用 Sparkle 2：用户选择「检查更新…」后，在应用内查看版本、下载、验证更新，并选择安装与重新启动。下载失败或签名不匹配时不会安装；无需用户手动挂载 DMG 或拖动替换 App。没有配置公钥的自定义构建保留 GitHub 手动下载入口。

- 启动检查沿用原有偏好和每日检查限制，通知中的「下载并安装」打开 Sparkle 更新窗口。下载及安装前仍由用户确认；不默认静默安装。
- 更新源为 `https://raw.githubusercontent.com/qDonl/crux-shotter/feat/v1/appcast.xml`，不使用 GitHub 的 `latest` 地址（该地址不包含 alpha 预发布）。
- 所有安装包和更新源使用 Ed25519 签名；客户端在解包前验证安装包，并验证更新源签名。
- 正式版仅接收默认通道，alpha / beta / rc 等预览版同时接收 `preview` 通道与正式版。
- Sparkle 按 `CFBundleVersion` 比较版本。每次发布必须增加 `project.yml` 的 `CURRENT_PROJECT_VERSION`，不能复用已发布的构建号。
- ad-hoc 签名仍不能替代 Apple Developer ID 与公证；自动安装不能保证消除 macOS 的首次启动或录屏授权提示。

## 密钥

首次初始化运行 `swift scripts/prepare-update-key.swift`。它仅打印公钥；私钥种子保存在当前用户的 `~/Library/Application Support/CruxShotter/ReleaseSigning/ed25519.key`，目录权限 700、文件权限 600。公钥写入 `project.yml` 的 `SPARKLE_PUBLIC_KEY`。同一台机器重复运行会复用原密钥。

私钥必须备份，不能加入 Git，也不能在已分发公钥后随意重新生成。其他发布机器通过 `SPARKLE_PRIVATE_KEY_FILE` 指定同一私钥文件；CI 使用 `SPARKLE_PRIVATE_KEY` secret。构建工具会验证生成的包签名与 App 内嵌公钥匹配，不匹配时终止发布流程。

## 发布顺序

1. 增加版本与构建号，测试后运行 `scripts/build-release.sh <version> [--skip-sign]`。即便 ad-hoc 构建也必须生成更新签名。脚本生成 DMG 与 `build/appcast.xml`，不会立即改动线上更新源。
2. 推送对应提交与标签，发布 Release，上传该 DMG 和签名后的 appcast.xml。
3. 确认安装包可公开访问后，将 `build/appcast.xml` 原样复制为根目录 `appcast.xml`，提交并推送至 `feat/v1`。不要修改签名后的 XML。自动签名发布 workflow 已包含该顺序；本地发布也应遵循相同顺序。
4. 用户用包含新公钥的旧版本检查更新，验证后续新版的下载、安装、重启。

`appcast.xml` 初始为空且已签名，避免向新客户端提供不包含公钥的历史构建。第一个启用应用内更新的版本需要手动安装一次；0.0.5-alpha 及更早发布的 App 没有此安装入口，不能直接获得该能力。

## 验证

- `swift test --package-path CruxShotKit`：版本通道、原有版本比较与检查策略，以及截图核心测试。
- `python3 -m unittest discover -s scripts/tests -v`：安装包名称、签名字段、构建号、预览通道、保留历史条目与同构建重复生成。
- Release 构建后用 `scripts/generate-update-feed.py <app> <dmg> <sparkle-bin>` 生成并校验签名；`verify-update-signature.swift` 使用客户端公钥独立验证签名，修改安装包字节后必须失败。
- 不进行界面自动化；真实安装与重启交互由用户验收。
