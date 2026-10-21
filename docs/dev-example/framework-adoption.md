# 核心框架落地：UIManager / EventBus / Codec / GUIDE 资源化

> 本文记录开发期 v0.23 的框架接入，保留原文以便对照；后续审计与修复见根目录 `CHANGELOG.md` 的 `0.1.0` 一节。
> 文中出现的 v0.23 是开发迭代号，发布版本已统一为语义化 `0.1.0`。

> 起因：`docs/dev-contract.md` §6 的审计指出 `EventBus`、`UIManager`、`Codec` **零调用**，
> 且 `GUIDE` 上下文是在 `duel_controller._setup_input()` 里用 300 行代码现搭的。
> 人类要求「替换实现而不是单纯接线 —— 显示 mc_game_framework 插件的优势」，
> 并补两条约束：GUIDE 上下文必须资源化、`addons/` 只读且不进审计。

## 1. 结论先行

| 能力 | 改前 | 改后 |
|---|---|---|
| 商店 / 设置 / 暂停菜单 | 三个各自 `extends Control` 的场景，暂停菜单手动 `instantiate` + `visible` | 注册进 `UIRegistry` 的 `UIPanel`，`open_panel` / `back` 管栈、遮罩、缓存、暂停回调 |
| 菜单与其他界面的状态同步 | 谁后加载谁刷新，靠重新进场景 | `EventBus` 事件：`UnlockPurchasedEvent`、`LanguageChangedEvent`，面板常驻也能刷新 |
| 存档读写 | 手写 `JSON.stringify` + 逐字段 `int(data.get(...))` | `Codec.record(...)` 声明式编解码 + `DataResult` 的 `is_error` / `is_partial` |
| 输入上下文 | 代码里 `GUIDEMappingContext.new()` 现搭 11 个动作 | `res://input/actions/*.tres` + `res://input/contexts/{duel_run,duel_versus}.tres`，`InputGuide` 只负责载入与改键 |
| 改键 | 直接改代码里的 `GUIDEAction` | 资源保持默认绑定，`GUIDERemappingConfig` 在运行期覆盖 |
| `UIManager` 单例 | **`project.godot` 里根本没启用** | 补进 autoload |

GUT：**169 tests / 636 asserts 全绿**（改前 168 / 585）。

## 2. UIManager：面板栈替换手写显隐

### 2.1 注册

`GameBootstrap._register_panels()` 在启动时把三个面板注册进 `RegistryManager` 的 `ui` 注册表：

| 面板 | 资源 id | 层 | 缓存 |
|---|---|---|---|
| 商店 | `iai:shop` | `UILayer.NORMAL` | `CACHE` |
| 设置 | `iai:settings` | `UILayer.NORMAL` | `NONE` |
| 暂停 | `iai:pause` | `UILayer.POPUP` | `NONE` |

主菜单仍是常驻场景（它是对局的入口，不是可叠加的面板）。

### 2.2 三个面板的改法

- 脚本从 `extends Control` 改为 `extends UIPanel`；`.tscn` 不用改（根节点本来就是 `Control`）。
- `_on_init()` 里设 `ui_layer` / `cache_mode` 与 `set_anchors_and_offsets_preset(PRESET_FULL_RECT)`：
  面板挂在 `CanvasLayer` 上，不自己铺满就是 0 尺寸。
- 生命周期改用插件回调：`_on_open()` 刷新数据并聚焦、`_on_close()` 收尾；
  设置面板的语言切换不再 `reload_current_scene()`，改为订阅 `LanguageChangedEvent` 原地重建。
- 暂停菜单**删掉自带的半透明 dim**：`UIManager` 对 `layer >= NORMAL` 会自动加 `BackgroundDimmer`，
  保留会变成双层变黑。它也不再自己管显隐，只发 `resume_requested` / `restart_requested` / `menu_requested`，
  开合由 `duel_controller` 调 `open_panel` / `close_panel`。
- 返回按钮统一 `UIManager.back(UILayer.NORMAL)`。

### 2.3 为什么值得换

- 返回栈、遮罩、同层暂停、缓存上限（`MAX_CACHED_PANELS = 10`）都是现成的，不用每个界面各写一遍。
- 面板开合会发 `UIOpenEvent` / `UIPauseEvent` / `UIResumeEvent` / `UICloseEvent`，将来做「打开设置时暂停对局」
  不需要再改每个界面。
- 测试里可以用 `UIManager.open_panel(...)` 直接开面板，不必 `change_scene_to_file` 再等场景树。

## 3. EventBus：让常驻面板自己刷新

菜单、商店、设置现在可以同时存在（面板叠在菜单上），「重新进场景」这条刷新路径没了，必须用事件：

- `UnlockPurchasedEvent(unlock_id)`：商店买角色 / 开关困难模式后发布，菜单收到后刷新金币与角色列表。
- `LanguageChangedEvent`：`I18NManager` 在 `set_language` 时发布，菜单与设置面板各自重建文案。

订阅都放在 `_ready()`，退订放在 `_exit_tree()`，避免面板被缓存后重复连接。

## 4. Codec：存档从「逐个 get」变成「声明式 schema」

`MetaSave.save_codec()` 用 `Codec.record(MapCodec.build([...], ...))` 声明 5 个字段：

| 字段 | Codec | 缺省 |
|---|---|---|
| `version` | `INT` | `VERSION` |
| `gold` | `INT` | 0 |
| `unlocks` | `STRING.list_of()` | 空 |
| `settings` | `map_of(STRING, AnyCodec)` | 空字典 |
| `stats` | `map_of(STRING, AnyCodec)` | 空字典 |

两个设计点：

1. **`AnyCodec`**：设置与统计的键集合由运行时决定（音量、键位、手柄键、残心统计……），
   不能逐字段写死；`AnyCodec` 只放行 JSON 兼容类型并递归校验，别的一律 `DataResult.error`。
2. **JSON 解析仍走 `JSON.parse`**：`JsonOps.from_json_string` 内部用 `JSON.parse_string`，
   坏存档会打引擎错误（GUT 会判 `Unexpected Errors` 而失败）。
   这里只用 Codec 的 `decode/encode`（结构层），字符串层交给 `JSON`。

读档时 `is_error` → 打警告并用默认值；`is_partial` → 打警告但已解出的字段照常使用（容错不丢档）。

## 5. GUIDE：上下文从代码搬进资源

### 5.1 资源布局

```
input/actions/duel_attack_p1.tres … duel_offer_3.tres   （11 个 GUIDEAction）
input/contexts/duel_run.tres        （单人：P1 + 键盘 P2 + 1 个手柄槽）
input/contexts/duel_versus.tres     （双人：P1 用手柄 0、P2 用手柄 1）
```

资源由 `tools/generate_guide_context.gd`（`extends SceneTree`，headless 跑一次）生成：
默认绑定直接取 `KeyBindings.DEFAULT_KEYS` / `DEFAULT_JOY_BUTTONS`，所以**默认键位只有一处真相**，
以后改默认键位就重跑生成器，不用手改 `.tres`。

### 5.2 接线层

`scripts/core/input_guide.gd`（`class_name InputGuide`）只做三件事：

1. `context_for(mode)`：载入对应 `.tres`，并为每个对局**复制**成独占实例。
   原因：GUIDE 的启用/禁用是按「上下文实例 + 动作实例」记状态的，同一份资源被两个对局共用时，
   旧对局 `disable` 会把新对局在用的动作一起停掉，表现为「改键后没反应」。
2. `action(context, name)`：按动作名取 `GUIDEAction`，控制器只认名字，不认下标。
3. `build_remap_config(context, meta)`：把玩家改过的键套成 `GUIDERemappingConfig`——
   键盘槽按顺序替换、多出来的槽显式 `_unbind`（否则旧默认键会残留），手柄槽只换按钮、保留 `joy_index`。

### 5.3 结果

`duel_controller._setup_input()` 从约 130 行降到约 45 行，且删掉了 `_add_action()` 这个「代码造动作」的入口。
守卫测试新增禁令：`scripts/` 里出现 `GUIDEMappingContext.new(` 即失败（唯一例外是 `input_guide.gd` 的复制逻辑）。

## 6. 新增的可执行约束

`docs/dev-contract.md`：

- §3.1 未接线插件的「接线 / 豁免」二选一 —— 本轮把三项全部接线，偏差清零。
- §3.2 **`addons/` 只读**：不改插件源码、不给插件加钩子；需要不同行为在本项目一侧包一层。
  审计范围明确为 `res://scripts/`，不把插件内部写法计入本项目违规，也不许「因为插件这么写」而模仿。
- §4 守卫新增 `GUIDEMappingContext.new(` 禁令 + 校验 `input/contexts/*.tres` 存在且每个动作都有输入；
  `_REQUIRED_AUTOLOADS` 增加 `UIManager`。

## 7. 验证

```powershell
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --import --path .
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- GUT：169 tests / 636 asserts 全绿。
- 手工冒烟：菜单 → 商店（买角色 → 金币与角色列表即时刷新）→ 返回菜单 → 设置（切语言原地重建）→
  开局 → ESC 暂停（遮罩只一层）→ 继续 / 重开 / 回菜单。
- `--headless --quit-after 120` 无脚本报错。

## 8. 遗留

- `change_scene_to_file` 只剩主菜单 → 对局这一处（真正的场景切换），符合契约。
- 商店/设置面板当前不暂停对局（它们只在菜单里打开）；将来若在对局中打开，`UIManager` 的
  `UIPauseEvent` 已经能接到 `duel_controller`，不需要改面板。
- `GUIDERemappingConfig` 每次 `build_remap_config` 重建一次；设置里连续改键时应在保存时重建
  （当前设置在关闭面板前就调 `set_remapping_config`，对局内改键不生效——与改前行为一致）。
- **与 `godot-input-handling` 技能的已知偏差**：技能规定玩法输入走 `_unhandled_input`、不要用 `_input`。
  本项目的 `duel_controller._input()` 仍保留一段**手柄兜底**（GUIDE 设备枚举失败时按 `event.device`
  直接分发 P1/P2）。保留理由：headless 与无手柄环境下列举可能为空，兜底能避免「输入完全失效」；
  正常路径仍是 GUIDE 的 `GUIDEAction.just_triggered`。若后续 GUIDE 升版修掉枚举问题，可删除该兜底。
- 技能复核结论（补载 `godot-input-handling` 后）：`_physics_process` 采样、禁止硬编码键码、
  改键持久化三条均符合；其 `input_buffer` 建议与人类「取消输入缓冲」的决策冲突，
  按「人类指令 > 技能」处理（见 `balance-pass-04.md` §6）。
