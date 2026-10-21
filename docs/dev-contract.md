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

**已登记的豁免（2026-10-21，人类确认「无更新则登记豁免」）**：

| 能力 | 现状 | 豁免理由 | 约束 |
|---|---|---|---|
| Master 音量 / 静音 | `GameBootstrap.apply_settings()` 直连 `AudioServer.set_bus_volume_db` / `set_bus_mute` | SoundManager 上游最新 **v2.6.2** 仍只提供 music/sfx/ui/ambient 分轨音量与 getter，**没有** Master 音量与 mute API | 只允许 Master 总线；分轨一律走 `SoundManager.set_*_volume`；守卫把该模式限制在 `game_bootstrap.gd` |
| 内置 `ui_*` 动作的手柄事件 | `GameBootstrap._ensure_ui_gamepad_actions()` 运行时 `InputMap.action_add_event` | UIManager 与内置 UI 走引擎 `ui_accept` 等动作，GUIDE 不管内置动作 | 只在启动时补一次，不改 `project.godot` 输入资源；守卫限制在 `game_bootstrap.gd` |
| 手柄热插拔即时生效 | `GameBootstrap._refresh_guide_joy_devices()` 调 `GUIDE._input_state._refresh_joy_device_ids(0, 0)` | GUIDE 没有公开的「重新枚举设备」入口 | 只调用不改插件；守卫限制在 `game_bootstrap.gd` |
| 改键资源生命周期 | `InputGuide.build_remap_config()` 调 `GUIDERemappingConfig._bind` / `_unbind` | 插件公开 API 只能整体替换 config，无法逐槽改 | 全部收在 `input_guide.gd` 一个包装层；对局结束 `GUIDE.set_remapping_config(null)` 复位 |
| `Input.get_connected_joypads()` | `input_devices.gd`、`duel_controller.gd`、`settings.gd` | GUIDE 不暴露「已连接手柄数」，且切换上下文前需要判空 | 只读设备数量，不读按键状态 |

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
| `Input.is_action_*` / `Input.get_axis(` / `Input.get_vector(` / `Input.get_joy_axis(` / `Input.get_action_strength(` … | 输入必须经 GUIDE |
| `var x := Input`（把单例整个赋给变量） | 防止用别名绕过上一条 |
| `AudioStreamPlayer.new(` / `AudioStreamPlayer2D.new(` / `AudioStreamPlayer3D.new(` | 音频必须经 SoundManager |
| `TranslationServer.` | 翻译必须经 I18NManager |
| `GUIDEMappingContext.new(` | GUIDE 上下文必须是资源，用 `InputGuide.context_for()` 载入（例外：`input_guide.gd` 复制实例、`tools/generate_guide_context.gd` 生成资源） |
| `AudioServer.set_bus_volume_db(` / `set_bus_mute(` | §3.1 豁免，仅 `game_bootstrap.gd`（Master 总线） |
| `InputMap.action_add_event(` | §3.1 豁免，仅 `game_bootstrap.gd`（内置 `ui_*`） |
| `GUIDE._input_state` | §3.1 豁免，仅 `game_bootstrap.gd`（热插拔兜底） |
| `config._bind(` / `config._unbind(` | §3.1 豁免，仅 `input_guide.gd` |

扫描前会剥离**注释与字符串字面量**：注释里的示例代码不算违规，字符串里提到 API 名也不算。
扫描失败（目录打不开 / 文件读不到 / 扫到的脚本数异常少）直接失败，不再「零文件 = 零违规」。

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
- [ ] 若改版本号，`project.godot` 的 `config/version` 与 `scripts/ui/about_panel.gd` 的 `VERSION_TEXT` 一致，且 `CHANGELOG.md` 有一节对应

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
- **结果**：GUT 169 tests / 636 asserts 全绿。

### 2026-10-21 第三轮：全量代码审计后的修复（v0.24）

人类要求「先审计、人工审核后再改」。审计报告见 `docs/audit/code-audit-2026-10-21.md`
（P0 ×1 / P1 ×9 / P2 ×22 / P3 ×30+），本轮回合修复了全部 P0 与 P1，并清掉可安全落地的 P2/P3。

- **P0**：设置页音量滑条曾把 I18N 键（`settings.master`）当设置键写入，而 `apply_settings()` 读
  `volume_master` → 三个滑条零生效 + 永久脏键。现已把「显示键」与「存储键」拆成两个参数。
- **存档**：`MetaSave.save()` 改为三步原子写（`.tmp` → `.bak` → 正档，失败回滚）；坏档加载时隔离为
  `.corrupt` 而不是被下一次 save 覆盖；`version` 因 MapCodec 裁剪默认值而从未落盘的问题修复
  （`optional_field_of("version", 0)`），并加了 `_migrate()` 补默认键；新增人工清档
  `MetaSave.wipe()` / `GameBootstrap.wipe_save()` 与设置页「清除存档」（二次确认）。
- **暂停**：`_input` 增加 `_paused` 守卫；Esc/Start 二次按下与面板「继续」统一走
  `_on_resume_requested()`（清队列 + 归还奖励焦点），修复「暂停时按刀 → 恢复第一帧出刀」。
- **表现层**：HUD 的「下一刀/下一次架」改调 `DuelSim.projected_commit_frames()` /
  `projected_guard_frames()`，删掉第二份公式（原先漏 4 个 offset）；`refresh()` 加数据签名脏检查，
  报幕颜色不再每帧 `add_theme_color_override`。
- **AI**：`AiProfile._BASE` 的 `counter` 从死数据变为真实生效（`counter_delay_frames` 认招迟滞）；
  二阶段加成改为 AI 内部偏移，不再改写共享 Resource；换 sim 时重连信号；删除死字段 `flow_speeds_commit`。
- **种子**：`RunState` 不再写死 `12345`，改为开局 `randomize()` 一次、局内按场次派生
  （`_stage_seed`），跨局不重复。
- **守卫**：`test_project_contract.gd` 重写为正则 + 标识符边界、剥离注释与字符串、扫描失败即失败，
  并新增扫描器自检用例；规则表同步到 §4 与 §3.1。
- **新增测试**：`test_meta_save_atomic.gd`（5）、`test_duel_sim_projection.gd`（4）、
  `test_settings_volume.gd`（3）、`test_duel_pause.gd` +2（Esc 清队列 / 暂停吞咽输入）。
- **结果**：GUT **185 tests / 723 asserts** 全绿（退出码 0）；headless 冒烟 240 帧无错误，
  本地化 **147 keys × 2 语言**。
- **未修（留待人工决策）**：7 个 `.tscn` 仍是空壳（UI 仍由代码构建，改为编辑器场景是独立重构）；
  `MetaSave` 设置去抖只做到 0.35s 合并写入；`duel_view.gd` / `duel_audio.gd` 仍无直接测试。

### 2026-10-21 第四轮：架防手感与难度单一真相

人类决策（`m01110`）：空架收势「缩短到 1 到 2 帧，重剑最多 4 帧，然后扣除心流」，理由是
「架防过期可以让人无感切换，但总有操作空间，也便于区分角色」。

- **架防**：新增 `FighterData.whiff_guard_recovery`（均衡 2f / 快剑 1f / 重剑 4f）；`_finish_guard`
  的空架分支从 `guard_recovery`（8/7/9f）改用它，`GUARD_REC` 只留给「格挡成功后」。
  空架仍扣 8 心流、断完美连击、发 `guard_whiffed`——惩罚保留，罚站取消。
  配合「按住防御在 `IDLE` 自动起架」，预判失败后按住不放即可续下一段架。
- **副作用（已记录）**：空架窗口（1–4f）已短于 AI 认招迟滞 `counter_delay_frames`（6–8f），
  AI 不再保证反抓空架；确定反改由「被架收招」（`blocked_recovery` 24–36f）覆盖。
  `_try_counter` 同时修正为「只有真的起构才消费骰子」，自己还在硬直里时保留机会。
- **难度单一真相**：删除 `GameBootstrap.hard_mode` 缓存副本（与 `meta.settings["hard_mode"]` 脱钩，
  测试替换 meta 后第 2 关敌人血量被错算成 40），`duel_controller` 改读 `_meta_hard_mode()`。
- **结果**：GUT **191 tests / 736 asserts** 全绿（退出码 0）。

### 2026-10-21 第五轮：难度回调、强化名副其实、占位描述同步

人类反馈（`m01359`）：「整体难度意外的上调了，而且随意出手导致无法后续攻击以及防御的代价
让我在中途就很难战胜敌人了」；并要求「再检查一下战斗逻辑」「更新占位文本和对强化的描述」
「根据目前战斗系统变动而调整强化效果」。人类随后（`m01536`）澄清：**文案仍未定案，保持占位设计**。

- **难度回调（战斗逻辑检查的直接结论）**：AI 的确定反迟滞 `counter_delay_frames`
  由 `roundi((1-counter)*8)`（4–5f）改为 `maxi(6, roundi((1-counter)*14))`（6–8f）。
  原因：玩家出刀总硬直 39–47f（`base_commit + slash + whiff_recovery`），AI 反斩前摇
  `28~30 + riposte(-10)` = 18–20f，4–5f 的迟滞等于「出刀即必被反斩」。现在给玩家
  100–133ms 的收手窗口。人类须试玩确认是否已够。
- **强化效果调整**：`u01` 架窗 +2→**+3**、`u02` 前摇 -2→**-3**、`u05` 预警 4→**6**。
  理由：前摇基准已从 18f 降到 14f，`-2f` 只有 14% 感知不到；刀光预警本身只有 8f，提前 4f 不够用。
- **「看破」（u05）语义修正**：`hint_lead` 原只加在 **P1 自己**的收束环上（`duel_view.gd`），
  与「看破对手」的名实不符；改为只加在 **P2（对手）**的环上，玩家才能提前看到对手的刀光。
- **「完美」（u03）泄漏修复**：`_do_block` 原直接读 `mods["perfect_gain"]` 且无阵营判定，
  对手完美格挡也会回 18 心流——等于把玩家心得白送 AI。现只在 `defender.side == P1` 时读。
- **占位同步**：44 个占位（中英各 44）的**描述文字**按当前实际数值重写（u07 +10 而非 +1、
  u08 5 秒而非 2 秒、u09 第 3–8 秒、u10 回复量翻倍、u06 补「额外消耗 30 心流」），
  但**保留 `[占位]` / `[PLACEHOLDER]` 前缀**，等人类定稿；`spell.*.desc` 4 键仍无显示路径。
- **结果**：GUT **192 tests / 738 asserts** 全绿（退出码 0）；headless 冒烟 240 帧无错误，
  本地化 151 keys × 2 语言。

### 2026-10-21 第六轮：难度量化与结构性修复（v0.29）

人类（`m01664`）：「难度似乎还是会有点吃力，我自己都过不去……或许是空挥，或许是其他原因。
可能需要大幅度检查。」→ 本轮先写可复现的量化工具，再按证据改数值，而不是继续猜单点。

- **新增工具**：`tools/sim_balance.gd`（5 关 × 60 局自动对战，输出反应延迟曲线与 AI 架刀率对照）、
  `tools/sim_trace.gd`（单局逐帧日志）。二者都是 `--headless -s` 跑的临时工具，不进 GUT。
- **实测根因（三条）**：① AI 架刀率是最大难度源——`guard_chance` 压到 0 / 0.15 / 0.30 时胜率
  99.9% / 89.6% / 65.3%，原档只有 31.9%；② 玩家出刀后 39–47f（修复后 27–41f）完全无法防御，而 AI 前摇 24–36f，
  「出刀 → AI 起手」在数值上必挨一刀；③ 告警窗 `SLASH_WARN_FRAMES = 8`（133ms）低于人类视觉反应。
- **改动**：`SLASH_WARN_FRAMES` 8→**16**；玩家 `guard_duration_base` 20/18/22→**24/22/26**、
  `whiff_recovery` 20/16/24→**14/12/18**、`blocked_recovery` 32/24/36→**28/22/32**、
  `cancel_cost` 5→**10**；`ai_profile.gd` 五性格 `guard_chance` 约 -40%；
  `duel_sim.gd` 新增**收招取消**（`RECOVERY` 第 2 帧起按防可取消转防，代价 10 心流 + 架窗减半），
  并让 `_guard_held` 的「按住即起架」覆盖 `RECOVERY`。
- **验证**：模拟延迟 9f（150ms）胜率 31.9%→**100%**，延迟 15f（250ms）**50%**，延迟 0（告警即按）
  **53.3%**（早按会空架 -8 心流）；GUT **195 tests / 746 asserts** 全绿；headless 冒烟 240 帧
  `151 entries × 2 语言`、stderr 空。
- **未做**：7 个空壳 `.tscn` 的场景化、`duel_view`/`duel_audio` 直接测试、`test_project_contract`
  对 `tools/` 以外目录的扩展。详见 `docs/dev-example/balance-pass-05.md` §9。

### 2026-10-21 第七轮：文档整理与语义化版本 0.1.0

人类（`m01940`）：「整理所有文档，根据对本次审计和修改经过的总结修改相关的文档，然后推送远端。
语义化版本号可以推进为 0.1.0 —— 基本的操作可以确定且难度简测还算通过。」

- **版本号**：`project.godot` 的 `config/version` 与 `about_panel.gd` 的 `VERSION_TEXT` 统一为
  **`0.1.0`**；`design.md` 变更表补 v0.23 / v0.24 / 0.1.0 三行，并声明此前的 `v0.x` 是开发迭代号。
- **新增 `CHANGELOG.md`**：按六批记录「问题 → 修法 → 验证」，是本次审计与修复的**唯一汇总入口**；
  它同时承担「哪些已修、哪些没修」的边界说明。
- **审计报告加状态头**：`docs/audit/code-audit-2026-10-21.md` 正文保持快照，但顶部写明「已处理、
  不要按报告行号改当前代码、修法见 CHANGELOG」，并注明测试基线从 169 变成 195。
- **文档一致性**：`README.md`（状态/存档/CI/已知限制/合规）、`development-log.md`（时间线、当前状态、
  插件审计结论从「4 用 3 空」更新为「已补齐 + 5 项豁免」）、`framework-adoption.md`（标注为开发期快照）、
  `design.md` §13（151 键、`0.1.0`）与 §15.2（占位实际落点）、`submission-checklist.md`（M6 记录、
  EXE 大小、151 键、0.1.0 占位说明）、`ai-disclosure.md`（追加本轮披露行）。
- **验证**：GUT **195 / 746**、退出码 0；headless 冒烟 240 帧、`151 entries × 2 语言`、stderr 空。
- **未做**：README 的「已跑通 Release」仍指向 `2026-10-20-02` 的旧附件（118 MB），
  重新导出后需人工核对大小与 sha256；44 条文案占位不动（人类 `m01536` 指示等定稿）。