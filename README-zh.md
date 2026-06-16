# OpenInOtty

[English](./README.md) | [中文](./README-zh.md)

点一下 Finder 工具栏图标，就在 [Otty](https://otty.sh/) 里打开当前目录。

> 灵感来自 [OpenInTerminal-Lite](https://github.com/Ji4n1ng/OpenInTerminal)。  
> 若你已经在用 OpenInTerminal 并切换多种终端，也可以直接用上游的 Otty 支持——见下方 **OpenInOtty 和 OpenInTerminal 怎么选**。

![macOS 12+](https://img.shields.io/badge/macOS-12%2B-blue) ![Swift 5](https://img.shields.io/badge/Swift-5-orange) ![License MIT](https://img.shields.io/badge/license-MIT-green)

![OpenInOtty demo](assets/openinotty-demo.gif)

---

## OpenInOtty 和 OpenInTerminal 怎么选

| 你的情况 | 建议 |
|---|---|
| **只用 Otty**，想要最轻的一键 Toolbar（开 tab、尽量 focus 到新 tab） | 用 **OpenInOtty**（本项目） |
| 已经在用 **OpenInTerminal / Lite**，在 Terminal / iTerm / Ghostty / Otty 等之间切换 | 用 [OpenInTerminal](https://github.com/Ji4n1ng/OpenInTerminal)（[Otty 支持 PR #276](https://github.com/Ji4n1ng/OpenInTerminal/pull/276)） |
| 两个都装 | 可以并存，不冲突。本 app 只服务 Otty；上游是多终端全家桶 |

简单说：

- **OpenInOtty** = Otty 专用遥控器（`otty-cli`：已在跑就新开 tab，并尽量 focus 过去）
- **OpenInTerminal** = 通用工具箱（`open -a Otty` 也能开，但不会走 Otty 的 tab CLI）

---

## 功能

- **一键打开** — 点工具栏图标，Otty 打开到当前 Finder 路径
- **智能路径**
  - 有选中项 → 用选中项（文件则用**父目录**）
  - 无选中 → 用当前 Finder 窗口的文件夹
  - 没有可用窗口 → 打开桌面
- **智能 Otty**
  - Otty 已在跑 → `otty-cli tab new --cwd <path>`，再按 cwd 找到新 tab 并 `tab focus`
  - Otty 未在跑 → `otty-cli open <path>`
  - CLI 失败或找不到 → 回退 `open -a <Otty.app> <path>`（Otty 支持把文件夹当文档打开）
- **按 bundle id 查找 Otty** — 不硬编码只认 `/Applications`（先走 Launch Services，再试默认路径）
- **错误提示** — 失败弹 `NSAlert`，不静默退出
- **无菜单栏 / Dock 图标** — `LSUIElement = true`，点完即退

---

## 环境要求

| 要求 | 版本 |
|---|---|
| macOS | 12.0 Monterey 或更高 |
| Xcode | 15+（App Store 免费安装即可） |
| [Otty](https://otty.sh/) | 较新版本 |

Otty 通常装在 `/Applications/Otty.app`。装在 Launch Services 能扫到的其它位置也可以。

---

## 安装

### 方式 A — 从源码编译

1. 克隆仓库：
   ```bash
   git clone https://github.com/pintaste/OpenInOtty.git
   cd OpenInOtty
   ```

2. 编译 Release：
   ```bash
   xcodebuild -project OpenInOtty.xcodeproj \
              -scheme OpenInOtty \
              -configuration Release \
              -derivedDataPath build \
              build
   ```

3. 安装到 Applications：
   ```bash
   cp -R build/Build/Products/Release/OpenInOtty.app /Applications/
   ```

   或用 Xcode 打开 `OpenInOtty.xcodeproj`，选择 **Product → Archive** 后导出。

### 添加到 Finder 工具栏

按住 **⌘ (Command)**，把 `/Applications/OpenInOtty.app` 拖到 Finder 工具栏。

第一次点击图标时，macOS 会弹出 Apple Events 权限对话框——点 **允许** 以授予 Finder 访问。

### 重置权限（如果不小心点了拒绝）

```bash
tccutil reset AppleEvents com.local.OpenInOtty
```

然后再次点击工具栏图标以重新触发提示。

---

## 给 AI agent / LLM

在用户 Mac 上安装、验证或排查 OpenInOtty 时用本节。优先使用下面的准确命令；不要编造 bundle ID。

### 事实表

| 项 | 值 |
|---|---|
| Bundle ID | `com.local.OpenInOtty` |
| App 安装路径 | `/Applications/OpenInOtty.app` |
| Otty 发现方式 | `NSWorkspace.urlForApplication(withBundleIdentifier: "io.appmakes.otty")`，否则 `/Applications/Otty.app` |
| Otty CLI | `<Otty.app>/Contents/MacOS/otty-cli`（可选；没有则走 `open -a`） |
| Otty bundle ID | `io.appmakes.otty` |
| 源码真相 | `OpenInOtty/main.swift`（单文件 app） |
| UI 类型 | `LSUIElement = true`（无 Dock / 菜单栏图标） |

### 安装清单（agent）

在目标 Mac 上执行（需要 Xcode CLI 或完整 Xcode）：

```bash
# 0) 前置条件 — Launch Services 或默认路径能找到 Otty
mdfind "kMDItemCFBundleIdentifier == 'io.appmakes.otty'" | head -1
# 或: test -d /Applications/Otty.app
xcodebuild -version

# 1) 克隆（如需）并编译 Release
git clone https://github.com/pintaste/OpenInOtty.git
cd OpenInOtty
xcodebuild -project OpenInOtty.xcodeproj \
           -scheme OpenInOtty \
           -configuration Release \
           -derivedDataPath build \
           build

# 2) 安装
cp -R build/Build/Products/Release/OpenInOtty.app /Applications/
```

**必须由用户完成的步骤（没有 UI 自动化很难代劳）：**

1. 打开 Finder。
2. 按住 **⌘**，把 `/Applications/OpenInOtty.app` 拖到 Finder **工具栏**。
3. 点一次工具栏图标；若 macOS 询问对 Finder 的自动化 / Apple Events 权限，选 **允许**。

### 验证

```bash
# App 是否存在
test -d /Applications/OpenInOtty.app && echo "app ok"

# Otty 是否可被发现
mdfind "kMDItemCFBundleIdentifier == 'io.appmakes.otty'" | head -1

# Otty CLI（若存在）
CLI="$(mdfind "kMDItemCFBundleIdentifier == 'io.appmakes.otty'" | head -1)/Contents/MacOS/otty-cli"
test -x "$CLI" && "$CLI" version

# 手动：在 Finder 打开某文件夹（或选中一个文件），点工具栏图标，
# 预期 Otty 在该文件夹打开/新 tab（选中文件则打开父目录）。
```

### 权限 / 自动化

- 权限类型：控制 Finder 的 **Apple Events**。
- 重置（然后重新点工具栏图标以再触发提示）：

```bash
tccutil reset AppleEvents com.local.OpenInOtty
```

- 设置里卡住时： **系统设置 → 隐私与安全性 → 自动化**（OpenInOtty → Finder）。

### 运行时行为（排查用）

1. 经 ScriptingBridge 解析路径（`finderPath()`）：
   - 优先选中项（文件 → 父目录）
   - 否则最前 Finder 窗口文件夹
   - 否则 `~/Desktop`
2. 用 bundle id 解析 Otty.app，否则 `/Applications/Otty.app`。
3. 若有 `otty-cli`：
   - Otty 在跑 → `tab new --cwd` → `tab list --json` 按 cwd 匹配 → `tab focus <id>`
   - 否则 → `otty-cli open <path>`
4. CLI 缺失或失败 → `/usr/bin/open -a <Otty.app> <path>`。
5. 全失败：`NSAlert`，非 0 退出；成功：立即 exit 0。

### 做 / 不做

**做**

- 使用上面完全相同的 `xcodebuild` 命令。
- 优先按 bundle id 发现 Otty；不要假定只能在 `/Applications`。
- 提醒用户必须 **⌘-拖** 到 Finder 工具栏（agent 跳不过这一步）。

**不做**

- 不要在未同步 `Info.plist`、entitlements 和本文档的情况下改 bundle ID。
- 不要期待点击后还有 Dock 图标或后台进程。
- 不要把最小化的 Finder 窗口当成当前文件夹。
- 不要提交 `build/`、`DerivedData/` 或 `.DS_Store`。
- 不要把路径拼进 AppleScript 或 `sh -c`（始终用离散的 `Process` 参数）。

### 演示素材

| 文件 | 用途 |
|---|---|
| `assets/openinotty-demo.gif` | GitHub README（自动播放） |
| `assets/openinotty-demo.mp4` | Twitter / X、本地预览 |

重新生成（需要 `assets/sources/` 素材 + `ffmpeg` + Pillow）：

```bash
python3 scripts/make_demo_gif.py
```

---

## 工作原理

整个 app 就是一个 Swift 文件（`main.swift`）——没有 AppDelegate，也没有常驻事件循环。

```
点击工具栏图标
       │
       ▼
  finderPath()
  ┌─────────────────────────────────────────────────────────┐
  │ selection? → 第一项 URL（文件 → 父目录）                │
  │ else FinderWindows → 第一个窗口 target URL              │
  │ else ~/Desktop                                          │
  └─────────────────────────────────────────────────────────┘
       │
       ▼
  解析 Otty.app（bundle id → 默认路径）
       │
       ▼
  otty-cli 可用？
  ┌─ 是，已运行 ─► tab new --cwd → list → tab focus ─┐
  │  是，未运行 ─► open <path>                       │
  └─ 否 / 失败 ──► open -a Otty.app <path> ──────────┤
                                                     ▼
                                            出错？ → NSAlert
                                                     │
                                                   exit
```

**为什么用 `perform(NSSelectorFromString:)` 而不是 ScriptingBridge 协议？**

Swift 的 `@objc optional` 协议调用会先检查 `respondsToSelector:`。ScriptingBridge 的私有 `SBScriptableApplication` 对动态转发的方法会返回 `false`，于是调用静默得到 `nil`——更关键的是，TCC 权限对话框永远不会弹出。使用 `perform()` 可以绕过 selector 检查，让 ScriptingBridge 真正发出 Apple Event。

---

## 项目结构

```
OpenInOtty/
├── OpenInOtty.xcodeproj/
│   └── project.pbxproj
├── OpenInOtty/
│   ├── main.swift                  # 全部逻辑
│   ├── Info.plist                  # LSUIElement=true、用途说明
│   ├── OpenInOtty.entitlements     # Apple Events 权限
│   └── Assets.xcassets/
│       └── AppIcon.appiconset/     # 应用图标
├── assets/
│   ├── openinotty-demo.gif         # README 演示
│   └── openinotty-demo.mp4         # 社交 / 本地预览
├── scripts/
│   └── make_demo_gif.py            # 重建演示素材（可选）
├── README.md                       # 英文（默认）
└── README-zh.md                    # 中文
```

---

## 排查

**点图标没反应**

- 确认已安装 Otty（Spotlight / Launchpad 能搜到即可，不必须在 `/Applications`）
- 检查 **系统设置 → 隐私与安全性 → 自动化**（OpenInOtty → Finder）
- 若没有权限条目：运行 `tccutil reset AppleEvents com.local.OpenInOtty` 后再点一次

**打开的是桌面而不是当前文件夹**

- 至少要有一个未最小化的 Finder 窗口，或先选中某个文件/文件夹

**Otty 开了新窗口而不是 tab**

- 当时 Otty 没在跑，或 `otty-cli` 不可用已回退到 `open -a`。先手动打开一次 Otty 再点图标，应会走新 tab。

---

## 许可证

MIT — 见 [LICENSE](LICENSE)。
