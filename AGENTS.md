# Codex Quota 开发指导方针

## 项目目标

Codex Quota 是一个 macOS 悬浮 HUD：以红绿灯、任务状态和每周额度向用户展示 Codex 的使用状态。

- 界面：SwiftUI
- 悬浮无边框窗口与窗口尺寸：AppKit
- 本地验证应用：`dist/Codex Quota.app`

## 目录说明

- `Sources/CodexTrafficGlassApp/`：应用生命周期、SwiftUI 视图、窗口和 hover 交互。
- `Sources/CodexTrafficGlassCore/`：状态模型、视觉 token、动画 token 和业务逻辑。
- `Tests/CodexTrafficGlassSelfTests/`：可执行的自测程序。
- `dist/Codex Quota.app/`：用于实际运行和截图验收的本地应用包。

## 设计与布局原则

1. 明确区分两层：
   - **外层玻璃面板（background / container）**：负责整体玻璃材质、外轮廓和窗口承载。
   - **内部功能卡片（modules / cards）**：负责当前状态、周额度、重置时间等信息。
   不要把卡片尺寸、卡片间距与外层背景的尺寸混为一谈。

2. 所有可复用的尺寸、圆角、间距统一放在 `CodexPanelVisualMetrics`。
   - 不要在单个 View 中新增无法解释的“魔法数字”。
   - 模块之间的间距与面板内容的四周 inset 应保持一致，除非设计明确要求不同。
   - 修改任一高度时，要计算：header、divider、卡片高度、模块间距以及上下 inset 的总和。

3. 不要用额外 `Spacer`、任意增大外层高度或 `offset` 来掩盖裁切问题。
   先定位实际的 layout owner，再修正该层的约束或显式尺寸。

4. 保持深色 HUD glass 风格。
   - 外层优先使用现有原生材质与 `GlassBackground`。
   - 内部卡片可以更深，但不要把整体改成不透明的普通矩形。
   - 圆角、描边和阴影应从现有 visual metrics / style token 取值。

## 交互规则

- 折叠态通过左侧的展开入口打开面板。
- 展开态仅在鼠标离开**整个组件**后自动收起（hover-only dismissal）。
- 除非产品交互明确变化，不增加冗余的手动收起按钮。
- 保留 hover handoff delay，避免鼠标在相邻交互区域移动时闪烁收起。

## 修改流程

1. 修改前先阅读相关 View、`CodexPanelVisualMetrics`、`CodexPanelMotion` 与对应自测。
2. 对可表达的交互约束或关键视觉 token，先补充/更新一个会失败的 self-test，再实现最小改动。
3. 完成后至少运行：

   ```sh
   swift run --disable-sandbox CodexTrafficGlassSelfTests
   swift build --disable-sandbox
   git diff --check
   ```

4. 只要改动涉及 UI、间距、圆角、尺寸、裁切或动画，都必须更新并启动本地应用包：

   ```sh
   cp .build/debug/Codexquota 'dist/Codex Quota.app/Contents/MacOS/Codexquota'
   codesign --force --deep --sign - 'dist/Codex Quota.app'
   open 'dist/Codex Quota.app'
   ```

5. 使用真实运行态截图验收。**不能只凭代码推断就声称视觉问题已经解决。**
   验收时尤其检查：
   - 底部 inset 是否和模块间距一致；
   - 卡片是否被裁切；
   - 右侧/底部是否因窗口 frame 改动而溢出；
   - hover 展开与自动收起是否稳定。

## 版本发布与恢复

### 版本规则

- 正式版本使用 [Semantic Versioning](https://semver.org/)：`vMAJOR.MINOR.PATCH`。
  - `MAJOR`：不兼容的用户体验、数据格式或公开接口变化。
  - `MINOR`：向后兼容的新功能或明显的体验升级。
  - `PATCH`：向后兼容的 bug fix、视觉修复或小范围优化。
- `v1.0.0` 是首个正式版本。后续版本必须递增，不能复用历史 tag。
- 每个正式版本必须同时拥有：合并至 `main` 的 commit、不可变的 Git tag、GitHub Release 和清晰的发布说明。

### 发布流程

1. 确认工作区干净、全部验证通过，并先推送包含变更的分支。
2. 通过 Pull Request 合并到 `main`；不要从未合并的功能分支直接发布。
3. 从 `main` 创建 GitHub Release / tag。Release 标题格式：`Codex Quota vX.Y.Z`。
4. 发布前更新根目录 `VERSION`，并运行 `./scripts/package-release.sh`。
   - 该脚本会将 `VERSION` 同步至 App 内部版本，重新签名，并生成 `dist/releases/Codex-Quota-vX.Y.Z.zip`。
   - 不得手工拼装或覆盖已有发布资产；脚本发现同名 zip 时应停止，避免误覆盖历史版本。
5. 将该 zip 作为 GitHub Release asset 上传；Release 不能只包含 source code。
6. 发布说明必须写明本版对应的用户可感知变更，至少按以下结构组织：

   ```md
   ## 新增（Added）
   - ...

   ## 调整（Changed）
   - ...

   ## 修复（Fixed）
   - ...

   ## 验证（Verification）
   - CodexTrafficGlassSelfTests 通过
   - Swift 构建通过
   ```

   没有内容的栏目可以省略；不要只写“更新”或只列内部文件名。

7. 发布后必须核对：Release 不是 draft / prerelease、tag 指向正确的 `main` commit、远程 tag 已存在，并且下载 asset 后可解压。
8. 已发布的 tag 和 Release 不得删除、移动、强推覆盖或重用。发现问题时发布新的 PATCH 版本，例如 `v1.0.1`，并在说明中标注修复内容。

### 恢复原则

- GitHub Release 的 tag 是可恢复锚点：任意历史版本都可通过 `git fetch --tags` 后从对应 tag 新建恢复分支，例如 `git switch -c restore/v1.0.0 v1.0.0`。
- 若误删当前项目文件，优先从最近的正式 tag 或 `main` 恢复到新分支，先检查内容再合并；不要直接覆盖现有工作目录。
- GitHub Release 能防范代码历史中的误删，但**不是账号级灾备**。应额外维护一个不依赖 GitHub 的私有 mirror / bare clone，并定期同步；首次配置或改变备份位置前，先征求用户确认。
- 禁止对共享远程执行 force push、重写 `main` 历史或删除远程分支 / tag，除非用户明确授权并确认准确目标。

## 变更边界

- 保留用户已有的未提交改动，不覆盖、不重置、不顺手清理无关代码。
- 只修改当前需求直接涉及的代码；不要将窗口尺寸、动画时序、玻璃材质等不相关内容作为“顺带优化”。
- 完成时说明：修改了什么、运行了哪些验证、哪些视觉结论来自实际截图。
