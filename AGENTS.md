# godot_dsh_test — 项目指令（AGENTS.md）

> 本文件由 DeepSeek Harness (DSH) 自动加载到本项目的每个会话，作为项目级工作指令。
> 更具体的指令优先于更宽泛的指令；本文件不覆盖系统、开发者或用户的直接指令。

## 0. 会话启动契约（最高优先级，先做这一步）

> 2026-10-21 审计发现：项目引入了 33 个 GDAS 技能与 5 个插件，但**技能一次都没被实际加载使用**；
> 插件的使用也是不完整的（`EventBus`/`UIManager`/`Codec` 零调用）。因此把「使用约定」升级为强制契约，
> 并在同日完成第二轮：`EventBus`/`UIManager`/`Codec` 与 GUIDE 上下文资源化全部落地。
> 详细规则、技能↔任务映射表、插件允许/禁止用法、验收清单见 **`docs/dev-contract.md`**。

1. **开工第一步**：读取 `docs/dev-contract.md`。**在读完之前，不得创建、修改或删除仓库内任何文件**
   （只读勘察除外，但勘察完仍要先读契约再动手）。
2. **声明**：第一条回复里写明「本次任务加载的技能：…；使用的插件：…」。没有匹配技能时，写明为什么没有。
3. **真加载**：用 `skill` 工具实际加载技能（只写名字不算），按其决策树执行；技能示例代码必须适配本项目
   （`GUIDE` 输入、`sound_manager`、`mc_game_framework`、GUT、§8 规范）。
4. **插件优先**：输入一律 `GUIDE`（禁止 `Input.is_action_*` 等直读）；音频一律 `SoundManager`
   （禁止 `AudioStreamPlayer.new()`）；文本一律 `I18NManager`（禁止 `TranslationServer`）；
   数据表用 `RegistryManager`；测试只用 `GUT`。不得绕过插件自建替代实现。
5. **框架优先**：`EventBus`（跨场景事件）、`UIManager`（面板/遮罩/返回栈）、`Codec`（存档编解码）已全部接线，
   新功能一律沿用；出现新的零调用插件时，处置只能是「接线」或「人类确认豁免」，二选一后写进
   `docs/dev-contract.md` §3.1。`addons/` 只读，不在本项目内修改插件源码（§3.2）。
6. **留痕**：模块完成后在 `docs/gamejam/ai-disclosure.md` 追加一行，其中写明所用技能名；
   并在对应 `docs/dev-example/*.md` 记录改动与验证数据。
7. **冲突即停**：本契约与技能原文冲突时，`AGENTS.md`（尤其 §2 活动硬约束、§8 编码规范）优先；
   与人类当次指令冲突时，停下来说明，由人类裁决。

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
- `input/actions/*.tres` / `input/contexts/*.tres` — GUIDE 动作与上下文的**资源定义**（代码里不得现搭上下文，见 `docs/dev-contract.md` §3）
- `tools/generate_guide_context.gd` — 生成上面两类资源的 headless 脚本：默认绑定取自 `KeyBindings.DEFAULT_KEYS` / `DEFAULT_JOY_BUTTONS`，改完默认值重跑即可
- 新功能按模块放入 `scenes/`、`scripts/`、`resources/`、`input/` 等目录（按需创建），保持模块化
- `.dsh/skills/` — 项目级技能目录（第三方 GDAS 技能库的 2D 剪枝副本，33 个），DSH 自动发现；来源与许可见 `.dsh/skills/ATTRIBUTION.md`，使用约定见 §9

## 5. 策划 → 开发 → 评审工作流（一句灵感起步）

**最小输入只有一句策划灵感**，主代理会补足需求定义、加载技能并完成策划 / 实现 / 评审。

1. **策划**: 直接说 `帮我策划：<一句话灵感>`，由主代理在当前会话完成（不启动子代理），产出 `docs/dev-example/design.md`
2. **实现**: 主代理按 `design.md` 实现（默认主代理）
3. **评审**: 默认主代理；**全量代码审查**或需要并行搜索时，才启动子代理

交付记录写入根目录 `CHANGELOG.md`（按批次：问题 → 修法 → 验证）；单轮平衡与手感细节写入 `docs/dev-example/balance-pass-*.md`；过程与踩坑写入 `docs/dev-example/development-log.md`。
（原 `docs/dev-example/README.md`、`docs/agent-prompts/`、`docs/dev-example/feature-brief-example.md` 未随当前仓库保留，故不再引用。）

## 6. 测试与运行

> **测试框架唯一为 GUT**（`addons/gut` v9.6.0）。所有测试脚本 `extends GutTest`，放在 `res://tests/`；不得引入 GdUnit4 或其他测试框架。写法与判定见 §8 末条与 `.dsh/skills/godot-testing-patterns/SKILL.md`。

```powershell
# 运行全部 GUT 测试（退出码 0 = 全过，1 = 有失败）
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit

# 只跑文件名含 damage 的测试（调试用；完整参数见 .dsh/skills/godot-testing-patterns/references/gut-quick-reference.md）
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gselect=damage -gexit

# 一键脚本（等价，见技能目录 scripts/run_tests.ps1）
pwsh -File .dsh/skills/godot-testing-patterns/scripts/run_tests.ps1

# 运行游戏
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --path .

# 首次导入/重新导入资源
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --import --path .
```

## 7. 注意事项

- **技能来源**：`.dsh/skills/` 是第三方 GDAS 技能库的 2D 剪枝副本（LGPL-3.0，33 个），来源、提交号与许可见 `.dsh/skills/ATTRIBUTION.md` 与 `.dsh/skills/LICENSE`；除下方说明的一处本地改写外，不要手改技能文件
- **唯一本地改写**：`godot-testing-patterns` 已由 GdUnit4 版改写为 **GUT 版**（SKILL.md、references、scripts 全部重写，时间 2026-10-19），改写记录见 `ATTRIBUTION.md` §6。上游再同步该技能时**不要覆盖**，需按 GUT 版重新适配
- **技能更新**：更新源为仓库外 `.research/Game-Dev-Agentic-Skills`（已 gitignore），`git pull` 后按 `ATTRIBUTION.md` §4 重新复制并更新提交号（需外部命令审批）
- **C# 脚本**：DSH 会话内无法编译 C#，新增/修改 C# 后需在 Godot 编辑器内构建
- **外部程序执行**：本机 `godot.exe` 与 `git.exe` 实测可直接由 DSH 执行（2026-10-21 复核，`--version`、GUT、`--headless` 冒烟、`git push` 均成功）。若后续环境变了、出现 `Access is denied`，再带 `sandbox_permissions` 触发一次性审批
- **不要修改** `addons/` 内第三方插件源码（除非明确要求）

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
- **测试（GUT）**：只用 GUT——`extends GutTest`，文件放 `res://tests/`（`unit/` 纯逻辑、`integration/` 场景、`fixtures/` 数据工厂），文件名以 `test_` 前缀、`.gd` 后缀；禁止 GdUnit4 或混用两套 API。异步一律 `await wait_frames(n)` / `await wait_physics_frames(n)` / `await wait_for_signal(sig, timeout)`，**不用 `OS.delay_*`/`sleep`**；帧窗判定（如居合判定帧）按 `Engine.get_physics_frames()` 计数断言。信号先 `watch_signals(obj)` 再 `assert_signal_emitted*`；协作者用 `double()` + `stub(...).to_return(...)` + `assert_called*`。节点用 `autofree` / `add_child_autofree`，套件末尾 `assert_no_new_orphans()`；随机只经 `RandomNumberGenerator` 并固定 `seed`。输入测试用 `GutInputFactory.key_down/key_up/action_down/action_up` 或 GUIDE 上下文切换，不硬编码键名。

## 9. 项目技能（.dsh/skills）

本项目从上游 [Game Dev Agentic Skills (GDAS)](https://github.com/thedivergentai/Game-Dev-Agentic-Skills)（LGPL-3.0，提交 `db004d74`，版本 0.1.1）引入技能，按「Godot 4.7 + 2D 剑术对决」剪枝保留 33 个，完整清单与更新流程见 `.dsh/skills/ATTRIBUTION.md`。

**分组**：架构与工程（9）、2D 玩法与表现（12）、UI/音频/存档（4）、构建与质量（6）、类型参考（2：格斗 + AI 导航）。

**使用约定**（**强制门见 §0 与 `docs/dev-contract.md`**，本节是背景说明）：
1. 实现前先按任务匹配加载对应技能（如玩家角色 → `godot-characterbody-2d`；判定 → `godot-combat-system` / `godot-2d-physics`；状态 → `godot-state-machine-advanced`）。
2. 技能为**参考**而非成品：其示例代码默认面向纯 Godot，需适配本项目插件约定（`GUIDE` 输入、`mc_game_framework`、`sound_manager`）、静态类型与命名规范（§8）。
3. 技能只解决工程实现；**涉及文案/美术/音乐的需求仍受 §2 约束**（AI 不得生成，由人类提供或 `PLACEHOLDER`）。
4. 需要 3D、多人、移动/主机、RPG 剧情等已剪枝能力时，从上游按需临时引入单个技能目录，并在 ATTRIBUTION 中登记。
5. `godot-testing-patterns` 已本地改写为 **GUT 版**（上游为 GdUnit4）：本项目所有测试按该技能的决策树、脚本与 `references/gut-quick-reference.md` 执行；即使临时引入其他技能，也不要引入 GdUnit4。
