# 开发契约（Dev Contract）

> **本文件是强制性的，不是建议。** 每个新对话的第一条工具调用必须是读取本文件；
> 在读完之前不得创建/修改/删除仓库内任何文件。规则来源与优先级见 `AGENTS.md` §0。

## 0. 为什么有这份文件

2026-10-21 的审计发现：项目引入了 33 个 GDAS 技能与 5 个插件，但**技能一次都没被实际加载使用**，
插件的使用也是不完整的（`EventBus` / `UIManager` / `Codec` 零调用）。原因不是谁偷懒，而是
`AGENTS.md` §9 写的是「使用约定」，没有强制门、没有验收手段。本文件把「约定」升级为「契约」。

## 1. 开工检查清单（每个新对话，按顺序）

1. 读本文件。
2. 在第一条回复里写明：**本次任务将加载的技能**（`skill` 工具名）与**将使用的插件**；
   没有匹配技能时必须写一句「为什么没有」。
3. 用 `skill` 工具真正加载技能（只写名字不算），按技能里的决策树执行。
4. 实现完成后：跑 GUT、更新对应 `docs/dev-example/*` 文档、在 `docs/gamejam/ai-disclosure.md` 追加一行（注明技能名）。
5. 提交前自检本文件 §5 的验收清单。

## 2. 技能：必需，且要留下证据

技能目录：`.dsh/skills/`（GDAS 2D 剪枝副本，33 个，LGPL-3.0，来源见 `.dsh/skills/ATTRIBUTION.md`）。
技能是**参考实现**，其中的示例面向纯 Godot，套用前必须适配本项目的 GUIDE / sound_manager / mc_game_framework 与 `AGENTS.md` §8 规范。

### 2.1 任务 → 技能映射（最小集合，允许叠加）

| 任务 | 必载技能 |
|---|---|
| 角色移动/碰撞/状态机 | `godot-characterbody-2d`、`godot-state-machine-advanced` |
| 战斗判定/伤害/受击 | `godot-combat-system`、`godot-2d-physics`、`godot-genre-fighting` |
| 帧数据/输入缓冲/招式取消 | `godot-genre-fighting`、`godot-input-handling` |
| 动画/前摇表现/刀光 | `godot-2d-animation`、`godot-animation-player` |
| 音效/音乐接入 | `godot-audio-systems` |
| UI/主题/HUD 布局 | `godot-ui-theming`、`godot-ui-containers` |
| 存档/解锁/数据表 | `godot-save-load-systems`、`godot-resource-data-patterns` |
| 单例/全局状态/场景切换 | `godot-autoload-architecture`、`godot-scene-management`、`godot-signal-architecture` |
| 测试（GUT） | `godot-testing-patterns`（**本项目已改写为 GUT 版，唯一权威**） |
| 导出/CI | `godot-export-builds`、`godot-platform-desktop` |
| 性能/崩溃/孤儿节点 | `godot-debugging-profiling`、`godot-performance-optimization` |

### 2.2 冲突处理

`AGENTS.md`（尤其 §2 活动硬约束、§8 编码规范）> 本文件 > 技能原文。
技能与本项目约定冲突时，按本项目约定写，并在提交说明或 `ai-disclosure` 里记一句「技能 X 的写法 Y 未采用，因为 Z」。

## 3. 插件：能用插件的，不自己写

插件已在 `project.godot` 启用。下表是**当前实际使用状态**（2026-10-21 审计）与硬性要求。

| 插件 / 单例 | 现状 | 必须用它做什么 | 禁止的替代写法 |
|---|---|---|---|
| `GUIDE`（guide v0.13.0） | ✅ 已用（上下文资源 + `GUIDERemappingConfig`） | 所有输入读取、上下文切换、按键/手柄映射 | `Input.is_action_*`、`Input.get_axis`、`Input.is_key_pressed`、硬编码键码、**代码里现搭 `GUIDEMappingContext.new()`** |
| `SoundManager`（sound_manager v2.6.1） | ✅ 已用（7 个文件） | 全部音乐/音效/环境音、音量与总线 | 直接 `AudioStreamPlayer.new()` / 直接操作 AudioServer 总线 |
| `I18NManager`（mc_game_framework） | ✅ 已用（11 个文件） | 所有玩家可见文本的取词、语言切换、加载翻译表 | `TranslationServer.translate`、硬编码中文字符串进 UI 节点 |
| `RegistryManager`（mc_game_framework） | ✅ 已用（4 个文件） | 数据注册表（解锁表、心得表、**UI 面板表**） | 在场景里散落 `const` 字典当数据库 |
| `EventBus`（mc_game_framework） | ✅ 已用（菜单/商店/设置的事件刷新） | 跨场景/跨系统事件（解锁变化、语言变化、暂停/恢复事件） | 新增全局状态传播时又写一个自定义单例信号 |
| `UIManager`（mc_game_framework） | ✅ 已用（商店/设置/暂停菜单改为 UIPanel 栈） | 面板开关与栈式返回、遮罩、Toast、缓存 | 用 `change_scene_to_file` 打开可叠加的界面（主菜单→对局这种真正的场景切换仍可切换场景） |
| `Codec`（mc_game_framework） | ✅ 已用（`MetaSave` 存档编解码） | 存档/配置的编解码与校验 | 自写二进制序列化、手写 `int(data.get(...))` 逐字段解析 |
| `GUT` v9.6.0 | ✅ 唯一测试框架 | 所有测试 | GdUnit4、任何其他框架（`AGENTS.md` §6 明令禁止） |

### 3.1 未接线插件的处置（不得默默忽略）

历史偏差（`EventBus` / `UIManager` / `Codec` 零调用）已于 2026-10-21 全部接线，见 §6 第二轮审计。
此后若再出现零调用插件，处置方式只有两种，且必须二选一后写进本文件：

- **A. 接线**：下一次触及对应能力时用插件替换现写法（一次改一处，带 GUT）。
- **B. 豁免**：由人类确认「本项目不需要」，并在本表对应行标注「豁免（日期 / 理由）」。

在此之前：**新增代码不得扩大偏差**（不许再写裸 `change_scene_to_file` 做面板切换、不许再自建全局单例信号）。

### 3.2 `addons/` 只读

`addons/` 下的插件源码属于第三方依赖，**本项目不修改**：

- 不改插件内部实现、不「顺手修」插件 bug、不给插件加钩子。
- 需要不同行为时，在本项目一侧包一层（如 `scripts/core/input_guide.gd` 包 GUIDE 的上下文与改键），
  或联系人类升级插件版本。
- 代码审计与守卫测试**只扫 `res://scripts/`**，不把 `addons/` 里的写法计入本项目风格违规；
  反过来，也不能因为「插件里就是这么写的」而模仿它绕过本契约。
- 例外：经人类明确要求升级/替换插件版本，按版本升级流程单独提交。

## 4. 可执行守卫

`tests/unit/test_project_contract.gd` 会扫描 `res://scripts/` 下全部 `.gd`，命中以下模式即测试失败：

| 模式 | 原因 |
|---|---|
| `Input.is_action_` / `Input.get_axis(` / `Input.is_key_pressed` / `Input.is_physical_key_pressed` | 输入必须经 GUIDE |
| `AudioStreamPlayer.new(` | 音频必须经 SoundManager |
| `TranslationServer.` | 翻译必须经 I18NManager |
| `GUIDEMappingContext.new(` | GUIDE 上下文必须是资源，用 `InputGuide.context_for()` 载入（唯一例外：`scripts/core/input_guide.gd` 内部把资源复制成对局独占实例） |

同时校验：

- `project.godot` 的 autoload 里 `GUIDE` / `SoundManager` / `I18NManager` / `RegistryManager` / `EventBus` / `UIManager` 均存在；
- `res://input/contexts/duel_run.tres` 与 `duel_versus.tres` 存在、可载入、每个动作都有输入。

新增禁止项时：先在本文件 §4 加一行，再在测试的 `_BANNED` 数组里加一条，然后修代码——顺序不能反。

## 5. 验收清单（提交前逐条）

- [ ] 本次任务匹配的技能已用 `skill` 加载，名称写进了 `ai-disclosure` 那一行
- [ ] 没有新增 `Input.*` 直读、没有 `AudioStreamPlayer.new()`、没有 `TranslationServer`、没有 `GUIDEMappingContext.new()`
- [ ] 输入相关改动只改 `res://input/` 资源（或重跑 `tools/generate_guide_context.gd`）
- [ ] 没有修改 `addons/` 下任何文件（§3.2）
- [ ] GUT 全绿（`-gdir=res://tests -ginclude_subdirs -gexit`），并在文档里记录 tests / asserts 数
- [ ] 对应的 `docs/dev-example/*.md` 已更新（改了什么、为什么、实测数据）
- [ ] `docs/gamejam/ai-disclosure.md` 已追加本模块一行
- [ ] 未生成任何玩家可见文案/美术/音乐（需要时用 `PLACEHOLDER` 并登记 `submission-checklist.md`）

## 6. 审计记录

### 2026-10-21 首次审计

- **技能**：0 次加载。`scripts/`、`tests/`、`docs/dev-example/` 中无任何技能引用；`ai-disclosure.md` 的历史行里也没有技能名。
  结论：开发全程（M1–M5、符卡 v0.20 重做、平衡 02–04b）未使用技能辅助，**属实**。
- **插件**：`GUIDE` ✅、`SoundManager` ✅、`I18NManager` ✅、`RegistryManager` ✅、`EventBus` ❌、`UIManager` ❌、`Codec` ❌。
- **实际影响**：功能没坏（判定、输入、音频都正常），但代价是——帧数据、输入缓冲、状态机这些**技能里已有成熟模式**的部分
  被重新推导了一遍（例如输入缓冲先后做了「4f → 覆盖硬直 → 整体删除」三次迭代，`godot-genre-fighting` /
  `godot-input-handling` 里对「读招类游戏不该用长缓冲」有直接论述）。这次偏差直接产生了返工。
- **结论**：把 `AGENTS.md` §9 的「使用约定」升级为 §0 强制契约 + 本文件 + 守卫测试。

### 2026-10-21 第二轮：插件从「接线」改为「替换实现」

- **Codec**：`MetaSave` 的存档编解码改为 `Codec.record(...)` + `AnyCodec`（运行时键集合的字典），
  载入时走 `DataResult` 的 `is_error` / `is_partial`，字段缺失用 optional 默认值兜底；`JSON` 只保留字符串层。
- **UIManager**：`project.godot` 补上此前**根本没启用**的 `UIManager` autoload；商店 / 设置 / 暂停菜单
  从「各自 `Control` + 手动显隐」改为注册进 `UIRegistry` 的 `UIPanel`，开合走 `open_panel` / `back`，
  由插件负责栈、遮罩、缓存与暂停/恢复回调。
- **EventBus**：菜单与商店/设置之间不再靠「谁后加载谁刷新」，改为 `UnlockPurchasedEvent` /
  `LanguageChangedEvent` 事件刷新；插件自带的 `UIOpenEvent` / `UIPauseEvent` 由 UIManager 自动发。
- **GUIDE**：`duel_controller` 里 300 行的「代码现搭上下文」删除，改为 `res://input/actions/*.tres` +
  `res://input/contexts/{duel_run,duel_versus}.tres`，由 `tools/generate_guide_context.gd` 生成；
  玩家改键通过 `GUIDERemappingConfig` 覆盖，不改资源。守卫测试新增 `GUIDEMappingContext.new(` 禁令。
- **约束**：新增 §3.2「`addons/` 只读」；审计范围明确为 `res://scripts/`。
- **结果**：GUT 168 tests / 585 asserts 全绿。
