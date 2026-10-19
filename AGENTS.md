# godot_dsh_test — 项目指令（AGENTS.md）

> 本文件由 DeepSeek Harness (DSH) 自动加载到本项目的每个会话，作为项目级工作指令。
> 更具体的指令优先于更宽泛的指令；本文件不覆盖系统、开发者或用户的直接指令。

## 1. 项目概况

- **引擎**: Godot **4.7.2** stable (mono，支持 C#)。引擎路径 `E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe`（目录名为旧版遗留，二进制实测 `4.7.2.stable.mono.official`）
- **脚本语言**: 以 GDScript 为主，必要时 C#
- **开发环境**: DSH (DeepSeek Harness) Web — 工具均为小写命名
- **交流语言**: 中文
- **项目性质**: 参加「幻游万象展」GameJam（东方 Project 主题）。本期活动主题：**「心」**；本项目方向：**剑术（居合道）与心流——东方 Project 各角色间的瞬息间剑术对决**。详见 `docs/gamejam/README.md`「本期主题」
- **代码仓库**: https://github.com/0999312/gamejam_iai （远端 `origin`，主干 `main`；工程根目录即仓库根目录）

## 2. 活动硬性约束（最高优先级，违反即违规）

> 完整清单见 `docs/gamejam/constraints.md`；AI 披露见 `docs/gamejam/ai-disclosure.md`；提交清单见 `docs/gamejam/submission-checklist.md`。
> 来源：《幻游万象展参与指南》（仓库根目录 `幻游万象展参与指南.md`，未纳入版本控制）+ 东方 Project 二次创作规约。

- **截止**: 2026-11-07 10:00（制作期 2026-10-17 10:00 起，共 3 周）。通道关闭后**不允许任何新的迭代与提交**。建议提交不晚于 09:40。
- **主题**: 须围绕主办方公布的主题（可自由理解）；**不接受 NSFW** 及违反创作规约、公序良俗的内容。主题公布后填入 `docs/gamejam/README.md` 的「本期主题」。
- **AI 允许/禁止（关键）**: 可用 AI **写代码**（`.gd`/`.cs`/shader/测试/构建脚本）；**禁止 AI 生成任何艺术资产**——美术、音乐、音效、文案（剧情、对白、旁白、道具与技能描述、UI 文字、作品 README、宣发文案）。需要这些内容时由人类提供；临时缺失用显式 `PLACEHOLDER` 占位并登记到 `docs/gamejam/submission-checklist.md`，**不得用 AI 先写一版凑数**。
- **AI 披露**: 每个模块完成后在 `docs/gamejam/ai-disclosure.md` 追加一行（日期 / 模块 / AI 产品 / 用途 / AI 率 / 人类复核）。
- **东方二次创作**: 游戏内「关于」页与提交 README 必须注明「本作是东方 Project 二次创作，版权归上海爱丽丝幻乐团及 ZUN 所有」；**禁止使用原作游戏素材**（截图/游玩视频仅可作宣传）；禁止暗示官方授权；不得未经许可使用他人二创素材。
- **提交物**: 可运行构建 + 人类撰写的 README + 人类制作封面 + AI 披露 + 署名。
- **质量门槛**: 无崩溃、无阻塞性操作问题；至少在 1 台非开发机/不同分辨率上验证过。

## 3. 插件（addons/，全部已在 project.godot 启用）

| 插件 | 版本 | 用途 |
|------|------|------|
| mc_game_framework | v1.0.0 | 核心框架：EventBus、UIManager、Registry、Codec、I18N |
| guide | v0.13.0 | 输入映射与上下文系统（替代原生 Input Map，GUIDEAction / GUIDEMappingContext / GUIDEMappingContext） |
| sound_manager | v2.6.1 | 音频管理（音乐 / 音效 / 环境音） |
| gut | v9.6.0 | GDScript 单元测试框架 |
| kenney_interface_sounds | — | UI 音效素材包（无插件，纯资源） |

## 4. 资源与目录约定

- `assets/fonts/` — MiSans-Semibold（中文友好字体，otf/ttf）
- `assets/theme/` — `minimal_vector.tres`（已接线到 project.godot）/ `modern_flat.tres`
- `assets/icons/` — 220 个单色 SVG 图标（按功能分类）
- `tools/generate_guide_context.gd` — GUIDE 上下文生成脚本（headless 运行，依赖 `res://input/actions/*.tres`，创建对应 Action 后使用）
- 新功能按模块放入 `scenes/`、`scripts/`、`resources/`、`input/` 等目录（按需创建），保持模块化

## 5. 策划 → 开发 → 评审工作流（一句灵感起步）

`docs/dev-example/README.md` 提供简化后的即插即用流程：**最小输入只有一句策划灵感**，主代理会补足需求定义、加载技能并完成策划 / 实现 / 评审。

1. **策划**: 直接说 `帮我策划：<一句话灵感>`，由主代理在当前会话完成（不启动子代理），产出 `docs/dev-example/design.md`
2. **实现**: 主代理按 `design.md` 实现（默认主代理）
3. **评审**: 默认主代理；**全量代码审查**或需要并行搜索时，才启动子代理

`docs/agent-prompts/` 三个提示词为**可选项**：仅作为子代理提示词或角色说明，不是启动前置条件。
示例需求单：`docs/dev-example/feature-brief-example.md`（可选；想控制细节时才替换为真实需求）

## 6. 测试与运行

```powershell
# 运行 GUT 单元测试
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless -s addons/gut/gut_cmdln.gd --path .

# 运行游戏
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --path .

# 首次导入/重新导入资源
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --import --path .
```

## 7. 注意事项

- **技能裁剪**：实际开发中如技能过多，可直接删除 `.dsh/skills/` 中不需要的条目（随仓库提交）
- **技能更新**：`tools/update-godotprompter.ps1` 从上游仓库同步技能目录
- **C# 脚本**：DSH 会话内无法编译 C#，新增/修改 C# 后需在 Godot 编辑器内构建
- **外部程序执行受限**：DSH 沙箱默认下启动 `godot.exe`/`git.exe` 报 `Access is denied`；需带 `sandbox_permissions` 触发一次性审批后才可执行（已用该方式完成 `git init` 与首个提交）。未审批时 §6 的 `--headless` 导入、GUT 测试、启动游戏都无法运行，验证需由人在本机执行
- **不要修改** `addons/` 内第三方插件源码（除非明确要求）；`docs/agent-prompts/` 为上游 GodotPrompter 的 DSH 适配版（MIT）

## 8. 编码规范

- **静态类型**：所有变量声明标注类型（`var hp: int = 100`），返回值标注（`-> void`）
- **优先复用现有能力**：Godot 插件已有功能优先，自主实现为候补；必要情况下需要告知人工更新插件
- **命名**：常量 `UPPER_SNAKE_CASE`，枚举 `enum`
- **节点引用**：优先 `%UniqueName`，避免绝对路径 `$"../../.."`
- **时间相关**：`_process(delta)` 中所有速度/计时乘以 `delta`
- **输入检测**：通过 `GUIDE` 上下文系统，不直接 `Input.is_action_*`，不硬编码键名
- **信号连接**：优先编辑器绑定；代码连接时使用 `signal.connect(callable)` 语法
- **`@onready`**：仅延迟初始化时使用，不在 `_ready()` 中赋值后又声明 `@onready`
- **场景组织**：单一职责原则，一个 `.tscn` 做一件事；组合优于继承
- **场景实例化隔离**：复杂 UI 或独立敌人实体必须存为独立的 .tscn 子场景，不得在主场景中直接堆砌孤立的节点层级。
