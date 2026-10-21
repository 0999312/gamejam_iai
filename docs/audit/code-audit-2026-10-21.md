# 代码审计报告（2026-10-21）

> **状态：已处理。** 报告正文保持审计当时的原貌（快照），**不要按正文的行号去改当前代码**——多处已重写。
> 逐条的「问题 → 修法 → 验证」见根目录 [`CHANGELOG.md`](../../CHANGELOG.md) 的 `0.1.0` 一节；
> 修复后的测试基线是 **195/195（746 asserts）**，本报告写作时是 169/169（636 asserts）。
> 未修项（7 个空壳 `.tscn`、字体重复、`DuelView`/`DuelAudio` 无直接测试）仍在 `CHANGELOG.md` 与 `README.md` 的「已知未修 / 已知限制」里跟踪。

> 审计人：DSH 主代理 + 4 个分区子代理（A 表现/数据、B 核心/输入/音频、C UI、D 测试）
> 审计对象：`scripts/` 29 个 `.gd`（4,973 行）、`tests/` 24 个 `test_*.gd`（169 用例）、7 个 `.tscn`、`input/` 13 个 `.tres`、`resources/unlocks/` 4 个 `.tres`、`localization/` 2 个 `.json`、`project.godot`、`export_presets.cfg`
> 判定依据：`AGENTS.md` §2/§8、`docs/dev-contract.md` §3/§4、`addons/` 实际源码签名
> **审计阶段只做只读检查，未修改任何代码。** 修复是在人类 `m00319` 给出明确信号后、按批次进行的（见上）。

---

## 0. 结论摘要

| 级别 | 数量 | 一句话 |
|---|---|---|
| **P0** | 1 | 设置页三个音量滑条完全不生效，并向存档写入 3 个脏键 |
| **P1** | 9 | 暂停输入泄漏；HUD 帧数与判定层不一致；商店重开后丢订阅；奖励界面焦点卡死；缺二创声明入口；存档三条可靠性缺陷；契约守卫形同虚设；改键持久化零端到端断言；HUD 每帧全量重建 |
| **P2** | 22 | 架构根因（7 场景全空壳）+ 性能 + 配置/数据层 + 插件边界 + 测试孤儿 |
| **P3** | 30+ | 风格、魔法数字、死代码、注释漂移 |

**总体判断**：工程骨架健康——静态类型 100% 合规、gameplay 代码插件四条禁令零违规、GUT 169/169 真绿（`Start-Process` 复核真实退出码 0）、headless 冒烟无错误、中英 131 键完全对齐、导出包本地化 JSON 经日志实证已进 PCK。问题集中在四处：

1. **「代码即 UI」的连带缺陷**：7 个场景全是空壳，UI 100% 运行时 `new`，直接衍生出焦点脆弱、绝对坐标溢出、帧数二次实现抄错。
2. **表现层与判定层的二次实现**：HUD 自己抄了一份前摇公式，已抄漏 4 项。
3. **存档写入与恢复策略**：截断写、无备份、`version` 从不落盘——正常路径不触发，一旦触发就是丢档。
4. **测试体系的自我验证缺失**：契约守卫是子串匹配（绕过方式极多），改键持久化链因 `save_path = ""` 整条零断言。**这两条让「测试全绿」的可信度打折**，必须先修，否则后续修复没有可靠回归网。

**没有发现**：崩溃路径、导出缺资源、判定层逻辑错误、插件源码被改动、`addons/` 越权修改。

---

## 1. 审计范围、方法与局限

### 1.1 证据等级

| 等级 | 含义 | 本报告中的例子 |
|---|---|---|
| **实测** | 亲自运行/检索/对照插件源码确认 | GUT 退出码、headless 冒烟、导出日志、131 键对齐、`map_codec.gd:70-74` 裁剪行为、`context_for()` 深拷贝 |
| **静态精读** | 逐行阅读 + 交叉核对调用点，未运行触发 | 音量滑条键名错位、暂停队列、HUD 帧数公式、存档三条 |
| **推断** | 依据代码结构判断，需运行验证 | 设置页布局重叠量（按 `custom_minimum_size` 计算）、音频僵尸播放器触发条件 |

### 1.2 未覆盖 / 局限（人工审核时请知悉）

- 未在**非开发机/不同分辨率**实测（`AGENTS.md` §2 质量门槛要求项，checklist 也未勾选）。
- 未做 **10 分钟无崩溃** 长跑；未做 Web/其他平台导出验证。
- 未审计 `addons/` 内部实现（按 §3.2 只读，仅核对被调用 API 的签名/语义）。
- 未审计 `shaders/`、`assets/` 的素材合规性（属 §2 艺术资产范畴，需人工核对）。
- 测试孤儿节点只统计了 GUT 汇总数字，未逐用例定位全部来源。

---

## 2. P0 —— 必修，建议立即处理

### P0-1 设置页三个音量滑条完全不生效，且向存档写脏键

**位置**：`scripts/ui/settings.gd:200-202`、`:293-317`、`:431-437`；`scripts/core/game_bootstrap.gd:112-121`

**证据链**：

1. 调用处把 **I18N 键**当成了设置键传进去（`settings.gd:200-202`）：
```gdscript
_master = _add_slider_row(left, "settings.master", 0.8)
_sfx = _add_slider_row(left, "settings.sfx", 0.8)
_ambient = _add_slider_row(left, "settings.ambient", 0.7)
```

2. `_add_slider_row(parent, key, default_value)` 的 `key` **一职两用**（`settings.gd:293-317`）：既当标签文本 `label.text = _tr(key)`（`:300`），又当回调参数 `slider.value_changed.connect(_on_volume_changed.bind(key))`（`:314`）。

3. 回调把 `key` 直接当设置键写进存档（`settings.gd:431-437`）：
```gdscript
func _on_volume_changed(value: float, key: String) -> void:
	...
	meta.settings[key] = clampf(value / 100.0, 0.0, 1.0)   # 实际写入 "settings.master"
	GameBootstrap.apply_settings()
	GameBootstrap.save_meta()
```

4. 而 `apply_settings()` 读的是**另一套键名**（`game_bootstrap.gd:115-117`）：
```gdscript
var master := clampf(float(meta.settings.get("volume_master", 0.8)), 0.0, 1.0)
var sfx := clampf(float(meta.settings.get("volume_sfx", 0.8)), 0.0, 1.0)
var ambient := clampf(float(meta.settings.get("volume_ambient", 0.7)), 0.0, 1.0)
```

**影响**：
- 拖动「主音量 / 音效 / 环境音」，**对实际音量零影响**（读到的永远是默认 0.8/0.7）。
- 每次拖动都往 `user://meta_save.json` 写 `settings.master` / `settings.sfx` / `settings.ambient` 三个脏键；`MetaSave._to_dict()` 原样序列化 `settings` 字典（`meta_save.gd:62`），`_from_dict` 原样载回 → **脏键永久存在**并随版本迁移一直带着。
- 重开设置页时 `_load_values()`（`settings.gd:417-428`）从真键 `volume_*` 回填，滑条**跳回 80/80/70** → 用户感受是「怎么调都没用，还自己弹回去」。
- 静音与全屏走 `_add_check_row` + 独立处理器（`:204-205`），键名正确，**不受影响**——所以缺陷只覆盖三个滑条，更容易被漏测。

**修复建议（任选一）**：
- 推荐：签名改 `_add_slider_row(parent: VBoxContainer, label_key: String, setting_key: String, default_value: float)`，调用处传 `("settings.master", "volume_master", 0.8)`，回调 `bind(setting_key)`。
- 或最小改动：调用处直接传 `"volume_master"`，标签改用 `_tr("settings." + key.trim_prefix("volume_"))`。
- 配套：调用 `set_value_no_signal()` 或加 `_loading` 守卫（见 P2-3）。
- 补测试：`_on_volume_changed(50.0, "volume_master")` 后断言 `meta.settings["volume_master"] == 0.5` 且 `not meta.settings.has("settings.master")`。

**为何定 P0**：核心设置项 100% 失效 + 存档数据污染，直接命中活动质量门槛「无阻塞性操作问题」，且是玩家第一时间会去点的功能。

---

## 3. P1 —— 建议本期修

### P1-1 暂停期间输入进入队列，且两条恢复路径行为不一致 → 恢复后自动出招

**位置**：`scripts/duel/duel_controller.gd:96-137`（`_input`）、`:140-144`（`_physics_process` 早退）、`:169`（`_clear_input_flags`）、`:386-396`（`_on_pause_pressed`）、`:416-418`（`_on_resume_requested`）

**证据**：
- `_input()` **没有 `_paused` 守卫**，暂停面板打开时按 J/K/符卡键仍置位 `_attack_queued` / `_guard_queued` / `_spell_queued`。
- `_physics_process` 在 `_paused` 时直接 `return`（`:143-144`），队列不被消费也不被清理；`_clear_input_flags()` 只在 `_physics_process` 末尾调用（`:169`）。
- 恢复有两条路径，**行为不一致**：
  - 面板「继续」→ `_on_resume_requested()`（`:416-418`）→ 调了 `_clear_queued_input()`，干净。
  - **Esc / Start 再按一次** → `_on_pause_pressed()`（`:393-395`）→ `_paused` 为真时只调 `_close_pause_panel()`，**不清队列** → 恢复第一帧立即消费暂停期间按下的攻击/符卡。

**影响**：在「帧精确读招」的对局里，玩家按 Esc 关面板的瞬间角色自己出刀，这一刀还带 `slash_cost` 心流代价与空挥硬直——属操作失控，可判「阻塞性操作问题」。`tests/integration/test_duel_pause.gd`（47 行）只测 `_on_pause_pressed()`→`_on_resume_requested()` 这条干净路径与重开，**未覆盖 Esc 二次按下这条 bug 路径**。

**修复建议**：
- `_input()` 开头加 `if _paused: return`（手柄兜底分支同样处理）；或
- 在 `_on_pause_pressed` 的关闭分支补 `_clear_queued_input()`，与 `_on_resume_requested` 对齐（最少一行）。
- 补测试：暂停 → 按攻击 → 用「Esc 再按」恢复 → 断言推进一帧后 `sim.p1.state == IDLE`。

### P1-2 HUD 显示的「前摇/架窗帧数」与判定层实际值不一致

**位置**：`scripts/duel/duel_hud.gd:157-166` vs `scripts/duel/duel_sim.gd:427-429`、`:453-457`

**证据**：

HUD 自己重算了一份公式（`duel_hud.gd:158-161`）：
```gdscript
func _commit_frames(fighter: FighterState) -> int:
	var tier := DuelTypes.tier_for_flow(fighter.flow)
	return maxi(DuelSim.COMMIT_MIN_FRAMES,
			fighter.data.base_commit + DuelTypes.COMMIT_TIER_OFFSET[tier])
```

判定层真正的公式（`duel_sim.gd:427-429`）：
```gdscript
fighter.commit_total = maxi(COMMIT_MIN_FRAMES,
		fighter.data.base_commit + tier_offset + opening_offset + riposte_offset
				+ repeat_offset + counter_offset)
```

HUD 漏掉 **opening_offset（开场心得）、riposte_offset（反斩）、repeat_offset（连斩惩罚）、counter_offset（顺势斩）** 四项；架窗同理漏掉符卡架势的 30f 下限（`duel_sim.gd:456-457`：`fighter.guard_duration = maxi(fighter.guard_duration, SPELL_STANCE_GUARD_FRAMES)`）。

**影响**：
- 连斩惩罚时实际 22f、HUD 显示 14f；符卡架势实际 30f、HUD 显示 20f。玩家按 HUD 读帧会被系统性误导。
- 更严重的是语义错位：COMMIT 状态下 HUD 显示的是「下一刀」的预测值，而本次真实耗时 `fighter.commit_total` 就在状态里。
- `tests/` 对 `commit_total` 有 9 处断言，对 HUD `_commit_frames` **0 处**。

**修复建议**：COMMIT 状态直接显示 `fighter.commit_total - fighter.state_frame`；IDLE 时若要预测，把 `_enter_commit` 公式抽成 `DuelSim.predict_commit_frames(fighter)` 单一来源，HUD 只调用不重写。

### P1-3 商店作为 CACHE 面板，关闭一次后永久丢失 EventBus 订阅

**位置**：`scripts/ui/shop.gd:16-32`；`addons/mc_game_framework/autoload/ui_manager.gd:336-347`

**证据**：
```gdscript
func _on_init() -> void:
	cache_mode = CacheMode.CACHE          # :18
func _ready() -> void:
	EventBus.subscribe(&"LanguageChangedEvent", _on_language_changed)   # :26
	EventBus.subscribe(&"UnlockPurchasedEvent", _on_unlock_purchased)   # :27
func _exit_tree() -> void:
	EventBus.unsubscribe(&"LanguageChangedEvent", _on_language_changed) # :31
```
UIManager 的 CACHE 分支只 `remove_child` 并存进 `_cached_panels`，再次入树时**不调 `request_ready()`** → 第二次打开时 `_ready()` 不重跑，订阅不恢复。

**影响**：主菜单 → 商店 → 返回 → 设置里切语言 → 再开商店，标题/分组/条目/返回键仍是旧语言（`_on_open` 只 `_refresh()` 金币与按钮态）。`UnlockPurchasedEvent` 同样失联，目前只因 `_on_action_pressed` 末尾手动 `_refresh()` 才没暴露。

**修复建议**：订阅移到 `_enter_tree`（缓存面板每次入树都会走），或商店改 `CacheMode.NONE`（4 条目录重建成本可忽略）。补测试：`open → close → open` 后发事件验证 `_build_ui` 被调用。

### P1-4 奖励三选一被暂停打断后焦点不恢复，纯手柄玩家卡死

**位置**：`scripts/ui/pause_menu.gd:29-31`；`scripts/duel/duel_controller.gd:416-418`；`scripts/duel/duel_hud.gd:369-380`

**证据**：奖励阶段仍能按 Esc/Start 开暂停（`_on_pause_pressed` 不判断 `run.phase`），面板 `_on_open` 里 `_resume_button.grab_focus()` 抢走焦点；关闭时该 Control 退出场景树即释放焦点，而 `show_rewards()` 只在 `duel_controller.gd:200-201` 调一次（`_settled` 已 true 不会重调）。

**影响**：奖励按钮可见但无焦点，方向键与 `ui_accept` 全失效；键盘仍可按 1/2/3（GUIDE `duel_offer_*`），**纯手柄玩家只能重开对局** —— 命中活动质量门槛「无阻塞性操作问题」。

**修复建议**：`_on_resume_requested()` 里若 `run.phase == RunState.Phase.REWARD` 则重新 `_hud.show_rewards(run.offers)` 或给 `DuelHud` 加 `refocus_rewards()`；更彻底的是奖励阶段禁止开暂停菜单。

### P1-5 游戏内缺「关于」页 / 二创声明入口（活动硬约束）

**位置**：`scripts/ui/menu.gd`（全 222 行无相关代码）、全仓 `scripts/` 无「关于」「二次创作」「ZUN」字样

**依据**：`AGENTS.md` §2「游戏内『关于』页与提交 README 必须注明『本作是东方 Project 二次创作，版权归上海爱丽丝幻乐团及 ZUN 所有』」；`docs/gamejam/submission-checklist.md` §1 该项未勾选。

**影响**：这是**活动硬性约束**，不是代码质量问题。截止 2026-11-07 10:00 前必须完成，且文案必须由**人类撰写**（AI 不得生成文案，只能做接线与布局）。

**修复建议**：菜单加「关于」入口（复用 `UIManager` 的 NORMAL 面板），文案键先放 `about.statement` 并在两份 json 写 `[占位]` 登记 PH 编号，等人类填字。代码侧只做布局与 `_tr()` 接线。

### P1-6 存档三条可靠性缺陷：截断写 / 损坏即覆盖 / version 从不落盘

**位置**：`scripts/core/meta_save.gd:100-104`、`:77-83`、`:47`、`:143`；`addons/mc_game_framework/codec/core/map_codec.gd:70-74`

**证据与影响**（三条同源，建议同批修）：

**① 非原子截断写（`meta_save.gd:100`）**
```gdscript
var file := FileAccess.open(save_path, FileAccess.WRITE)
if file == null:
	push_warning("MetaSave: cannot write %s" % save_path)
	return false
file.store_string(JsonOps.to_json_string(encoded.get_value(), "\t"))
return true
```
`FileAccess.WRITE` 先截断再写，任一时刻崩溃/断电/磁盘满都会留下 0 字节或半截 JSON，而原档已被覆盖；`store_string` 写错误与 `close()` 失败都没检查，`return true` 不代表已落盘。全项目只有这一处 `FileAccess.open`，无 `.bak`、无临时文件。

**② 损坏档回落默认值后不备份，下次 save 即永久覆盖（`meta_save.gd:77-83`）**
JSON 解析失败或字段校验失败时只 `push_warning` 并返回一份默认 `MetaSave`。进游戏后 `GameBootstrap.meta` 就是默认档（gold=0、只剩 char_a）；随后开局/切语言/拖音量任意一次 `save()` 会用默认值覆盖原文件，**金币与解锁彻底消失且无法人工恢复**。`is_error()` 是整份失败，一个字段类型错就全归零。

**③ `version` 被 MapCodec 裁掉，文件里永远没有版本号（`meta_save.gd:47`）**
```gdscript
Codec.INT().optional_field_of("version", VERSION)
```
因为 `version == VERSION == 1`，`addons/mc_game_framework/codec/core/map_codec.gd:70-74` 的 `if _optional and _is_default(value): return DataResult.success(ops.create_map({}))` 会把它裁掉；`_from_dict`（`:143`）也不比较 VERSION、无 `if version < VERSION` 迁移段 → 首次把 VERSION 提到 2 时，旧档会被当新档静默错读，迁移代码无从触发。

**修复建议**：
- 写 `user://meta_save.json.tmp` → flush/close → 校验 `get_error()` → `DirAccess.rename_absolute` 覆盖正式档；正式档改名保留 `.bak`；`load_from` 在正式档损坏时先试 `.bak`。
- 检出损坏时先把原文件重命名为 `user://meta_save.corrupt-<unix>.json` 并 `push_error`，再试 `.bak`，都失败才用默认值；UI 提示「存档损坏已备份」。
- `version` 改必选字段（`field_of` 或默认 -1）；`_from_dict` 加 `if version < VERSION: _migrate_from(version)`，补 GUT 用例模拟 v1 文件。

### P1-7 契约守卫形同虚设：子串匹配 + 漏扫即放行

**位置**：`tests/unit/test_project_contract.gd:63-74`、`:100-102`、`:65-66`

**证据**：守卫用「文本是否包含 needle 子串」判断违规，而非语法/AST 检查：
- `var i := Input` 后 `i.is_action_pressed(...)` —— 不含 `Input.is_action_pressed` 子串，**违规仍绿**。
- `Input.get_vector(...)`、`AudioStreamPlayer2D.new(...)`、`Input . is_action_pressed(...)`（中间加空格）同理绕过。
- `:100-102 if dir == null: return found` 与 `:65-66` 空串 continue 让「没扫描到 = 没违规」——目录读失败、扩展名过滤错、路径拼错都会静默通过。
- 反向误报：注释/字符串里出现 needle 就报违规。
- 只扫 `res://scripts/`，`tools/generate_guide_context.gd:70` 的 `GUIDEMappingContext.new()` 在范围外。
- 守卫自身无自检用例（`scan_text` 不可单测）。

**影响**：`docs/dev-contract.md` 的 §0/§3/§5 硬约束（输入走 GUIDE、音频走 SoundManager、文本走 I18N、不直操作 AudioServer）目前**没有任何可靠的自动化保障**。本报告的「gameplay 代码零违规」结论来自人工 grep，不是来自这个测试。

**修复建议**（半天）：
- 改成匹配「标识符边界 + 排除注释/字符串」的正则（`\bInput\s*\.\s*is_action_`、`\bAudioStreamPlayer2D?\s*\.\s*new\s*\(`），或解析 GDScript token。
- 扫描前把注释与字符串字面量剥离（可用 `GDScript` 的 tokenizer 或简单状态机）。
- 扫描失败必须**报错而不是放行**；目录不存在 = 失败。
- 扩到 `res://` 全仓（排除 `addons/`、`build/`）。
- 给 `scan_text()` 加自检用例：喂入 5 种违规样本 + 3 种安全样本，断言精确命中数。

### P1-8 改键持久化链零端到端断言（`save_path = ""` 让 `save()` 永远失败）

**位置**：`tests/unit/test_key_bindings.gd:14-18`；`tests/integration/test_settings.gd:10-11`；`scripts/core/meta_save.gd:36`、`:94-95`

**证据**：`MetaSave.new()` 的 `save_path` 默认为 `""`（`meta_save.gd:36`），`save()` 在 `:94-95` 直接 `return false`。测试只断言内存字典 `meta.settings["keys"]` 变了，**从未走过**「改键 → save → 重启 → `load_from` → `normalize`（`meta_save.gd:158`）」这条链。

**影响**：改键功能（8 个动作 × 键/手柄）是玩家可见的核心设置，其持久化路径**完全没有测试**。若 `normalize()` 或 JSON 往返有键名/类型问题，测试仍全绿。

**修复建议**：新增 `tests/integration/test_key_binding_persistence.gd`：临时 `user://` 路径 → `set_key` → `save()` 断言 true → `MetaSave.new()` + `load_from(path)` → 断言 `get_keys()` 与绑定一致 → 覆盖 `KEY_NONE`、冲突键、双动作同键三种边界。

### P1-9 HUD 每物理帧全量重建文本（性能）

**位置**：`scripts/duel/duel_controller.gd:174`、`:156`；`scripts/duel/duel_hud.gd:238-314`

**证据**：`_physics_process` 每帧末尾无条件 `_hud.refresh()`（对局结束后同样）；`refresh()` 内每帧约 12 次 `_tr()`、6 次 `KeyBindings.label`（内部 `OS.get_keycode_string`）+ 6 次 `String.replace` + 20 余次 `%` 格式化；`duel_hud.gd:311` 报幕期间每帧 `add_theme_color_override` 触发样式重算。

**影响**：60Hz 下每秒数千次临时 String/Array 分配；本作是帧精确读招（`SLASH_WARN_FRAMES = 8f`），低端机/Web 导出掉帧会直接影响手感。

**修复建议**：`if sim.frame != _last_refreshed_frame:` 再刷新；`_controls_text()` 结果缓存，只在 `bind`/语言切换/改键时失效；配色改为仅档位变化时 override。

---

## 4. P2 —— 排期处理

### 4.1 架构根因：7 个场景全是空壳，UI 100% 由代码 `new`

**位置**：`scenes/duel/duel.tscn`、`duel_view.tscn`、`hud.tscn`、`scenes/menu/menu.tscn`、`scenes/ui/{pause_menu,settings,shop}.tscn`

**证据**：7 个文件各 180-302 字节，内容一律「1 个根节点 + script 外链」：
```
[gd_scene load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/ui/menu.gd" id="1_menu"]
[node name="Menu" type="Control"]
anchors_preset = 15
script = ExtResource("1_menu")
```
对应五份 `_build_ui()`：`menu.gd:36-145`、`settings.gd:153-291`、`shop.gd:62-127`、`pause_menu.gd:34-60`、`duel_hud.gd:42-125`（HUD 在 `_ready` 里堆 20+ 节点）。

**影响**：
- §8「复杂 UI 必须独立 .tscn 子场景」形式合规、实质落空；**全项目 0 个 `%UniqueName`、0 个编辑器信号绑定、0 个 `focus_neighbor`**。
- 布局只能在运行时看，改一行间距要改代码；`_tr()`、`FONT` preload、按钮工厂在五个文件里重复。
- 直接衍生 P1-2（帧数二次实现）、P1-4（焦点链脆弱）、P2-4（布局溢出）、P3 的 1280×720 硬编码。

**建议**：本期至少把 **HUD** 场景化（唯一被 §8 直接点名且已有 P1-2 缺陷），把 14 个 Label / 2 个 ProgressBar / 奖励弹层搭进 `hud.tscn` 并标 `unique_name_in_owner`，脚本改 `@onready var _p1_hp: Label = %P1Hp`。其余四个 UI 场景延后；按钮工厂抽 `scripts/ui/ui_builder.gd`。

### 4.2 设置页每次打开执行 5 次 `apply_settings()` + 5 次落盘

**位置**：`scripts/ui/settings.gd:417-428`、`:314`、`:326`

`_load_values()` 用 `_master.value = ...` 与 `_mute.button_pressed = ...` 赋值，而 `Range.set_value` / `BaseButton.set_pressed` **会发信号** → 3 次 `_on_volume_changed` + 2 次 toggled → 每次打开设置页（含切语言重建）跑 5 次 `apply_settings()` 与 5 次 `save_meta()`；`_on_fullscreen_toggled` 还重复 `DisplayServer.window_set_mode()`。附带把浮点音量按 `step=1` 量化后写回。

**建议**：加 `_loading: bool` 守卫，或改用 `set_value_no_signal()` / `set_pressed_no_signal()`。与 P0-1 同批修最省事。

### 4.3 设置页右列超出声明高度，整页被顶到 y=64 与标题重叠

**位置**：`scripts/ui/settings.gd:167-198`、`:334`

标题 `title.position = Vector2(0, 42)`、`title.size = Vector2(1280, 60)`（文字带约 y=42–90）；`right.custom_minimum_size = Vector2(450, 430)`（`:196`）但实际内容 = 30+22+8×40+38+22+22 + 12×6 = **526**；`outer` 实际高度 ≥592，被 `CenterContainer` 垂直居中到 y=(720−592)/2 = **64**，与标题文字带重叠约 26px（数值为静态推算，需运行确认）。

**建议**：标题放进 `outer` 一起参与布局，删绝对 `position`；右列放进 `ScrollContainer`，`custom_minimum_size` 只当下限。

### 4.4 字体 UID 冲突（导出日志实证）

**位置**：`assets/MiSans-Semibold.otf`、`.ttf` 与 `assets/fonts/` 下同名文件；`build/export.log:17-19`

```
WARNING: UID duplicate detected between res://assets/MiSans-Semibold.otf and res://assets/fonts/MiSans-Semibold.otf
WARNING: UID duplicate detected between res://assets/MiSans-Semibold.ttf and res://assets/fonts/MiSans-Semibold.ttf
```
两份共约 29 MB，仅 `assets/fonts/` 被 `duel_hud.gd:8` 与各 UI 的 `FONT` preload 使用；`export_presets.cfg` 的 `exclude_filter` 只排了根目录 `assets/MiSans-Semibold.*`，重复项仍被打包且产生 UID 冲突。

**建议**：删根目录两份，重新导入后确认无 UID 警告。可减约 14 MB 包体。

### 4.5 写盘失败无任何用户可见反馈

**位置**：`scripts/core/game_bootstrap.gd:107-109`；`scripts/core/meta_save.gd:93-104`

`meta.save()` 返回 `bool` 并在失败时 `push_warning`，而 `save_meta()` 声明 `-> void` 直接丢弃返回值；`settings.gd:437/446/455`、`shop.gd:207` 全部经由它；全项目 12 处保存调用无人检查结果（`run_state.gd:302`、`unlocks.gd:59/70` 同样丢弃）。`UIManager.show_toast` 已具备但项目未注册任何 Toast 场景，等于没有错误通道。

**建议**：`save_meta() -> bool` 透传；失败走 toast 或 HUD 角标。购买失败目前也是静默无变化（`shop.gd:205-209`）。

### 4.6 契约例外未登记：AudioServer / InputMap 直连

**位置**：`scripts/core/game_bootstrap.gd:119-121`（`AudioServer.set_bus_volume_db` / `set_bus_mute`）、`:140-153`（运行时 `AudioServer.add_bus` 建 4 条子总线）、`:73-88`（`InputMap.action_add_event("ui_accept", ...)` 为内置 `ui_*` 补手柄）、`scripts/core/input_devices.gd:15`（`Input.get_connected_joypads()`）

**判定**：`docs/dev-contract.md` §3 明令「禁止直接操作 AudioServer 总线」。但核查 `addons/sound_manager/sound_manager.gd` 只提供 `set_sound_volume` / `set_ambient_sound_volume` / `set_music_volume`，**没有 master 与 mute 接口**；插件内部自己也是直接 `AudioServer.set_bus_volume_db`（`:67-68`、`:118`、`:147`）。因此这是**插件能力缺口**，不是绕过插件偷懒。

**建议**：不要删这段代码（删了主音量与静音就没了）。按 §3.1「人类确认豁免」写进 `docs/dev-contract.md` §3.1，注明「待插件提供 master/mute API 后回收」。`ui_*` 的 `InputMap` 直连同理（GUIDE 只覆盖自定义动作，内置 UI 导航不在其管辖）。另建议总线固化进 `default_bus_layout.tres`，代码只做 `set_default_*_bus` 兜底。

### 4.7 GUIDE 私有 API 耦合

**位置**：`scripts/core/input_guide.gd:83-85`、`scripts/core/game_bootstrap.gd:66-68`

`config._bind(context, mapping.action, key_input, index)` / `config._unbind(...)` 全是下划线私有方法（`GUIDERemappingConfig` 公开 API 只有 `GUIDE.set_remapping_config(config)`，`addons/guide/guide.gd:100`）；`GUIDE._input_state._refresh_joy_device_ids(0, 0)` 直接戳插件内部状态机。

**已核验**：`index` 语义**正确**——`guide.gd:281-290` 应用的正是 `action_mapping.input_mappings` 的数组索引，与 `input_guide.gd:77` 循环一致，**不存在错位风险**（此前怀疑撤销）。另：`input_guide.gd:81-82` 复制键盘槽只赋 `key`，丢弃 shift/control/alt/meta 修饰位（当前资源未用修饰键，属潜在问题）；改键配置从不 `set_remapping_config(null)`，最后一场的对象被 GUIDE 全局持有到进程结束。

**建议**：属上游 API 设计问题，项目侧只能封装 + 注释。登记为已知耦合，向上游提 issue；**不要**在 `addons/` 内改源码。

### 4.8 AiProfile 两处死配置（调参陷阱）

**位置**：`scripts/duel/ai_profile.gd:37`、`:47-53`、`:82`、`:89`

- `_BASE` 五个 persona 各写了不同的 `"counter"`（0.40/0.50/0.55），但 `for_persona` 在 hard（`:82`）与 normal（`:89`）两个分支都硬编码 `profile.counter_chance = 1.0` → **`_BASE["counter"]` 从未被读取**，5 个性格的反斩倾向完全一致。
- `@export var flow_speeds_commit: bool = false`（`:37`）**全项目零读取**；真正生效的是 `FighterData.flow_speeds_commit`（`fighter_data.gd:24`，`duel_sim.gd:395` 读取）。`fighter_data.gd:23` 注释声称「由 MatchSetup 从 AiProfile 注入」，实际不存在该注入（对手是 `opponent_base()` 手工置 false，`fighter_data.gd:176`）。

**影响**：策划改 `_BASE["counter"]` 或 `AiProfile.flow_speeds_commit` 完全无效且不报错。

**建议**：删死列/死字段（或改成读 `base["counter"]`，属平衡改动需人类确认）；修正注释。

### 4.9 数据层无 `.tres`，`@export` 默认值与工厂已漂移

**位置**：`scripts/duel/fighter_data.gd:94-124`、`spell_card.gd:54-116`；`fighter_data.gd:24` vs `:176`

8 个角色与 4 张符卡全部硬编码在静态工厂里，无 `.tres`、无缓存，每次 `for_character()` 都 `new`；`@export var base_commit: int = 18`（默认）与工厂赋值 `14` 不一致；`spell_id` 默认 `""` 与工厂 `spell_a` 不一致。当前全走工厂，默认值不参与，暂无功能影响；一旦有人把 `FighterData` 存成 `.tres` 或单测直接 `FighterData.new()`，就拿到另一套数值。

**建议**：落成 `resources/fighters/*.tres` 走 `RegistryManager`，或至少让默认值等于工厂首角色值并注释「工厂会覆盖」。

### 4.10 AI 三条内部问题

- **`duel_ai.gd:44-49` 自连 sim 信号无 teardown**：`tick()` 首次调用时 `sim.hit_landed.connect(...)` 等三条，`_hit_connected` 置 true 后再不重连；换 sim 后 `_sim` 仍指旧 sim，命中间合/连挨计数/符卡失败回滚全部静默失效。当前每场 `DuelAi.new()` 故未触发。建议改 `attach(sim)` / `detach()` 由控制器成对调用。
- **`duel_ai.gd:73-79` 二阶段直接改写外部 `AiProfile` Resource**（`profile.aggression = minf(1.0, profile.aggression + 0.15)` 等 4 处）：当前 `run.build_match()` 每场新建 profile 才没污染（`run_state.gd:113-115 enemy_profile()` 已核验每次 `for_persona` 新建）；一旦 profile 被缓存复用，加成会永久累积。建议改用 AI 内部乘子。
- **`duel_ai.gd:33-40` / `duel_sim.gd:92-95` `seed_value == 0` 走 `rng.randomize()`**：0 无法作为显式种子，属语义陷阱。建议改 `-1` 表示随机。

### 4.11 种子写死 12345 → 每局三选一/AI 序列完全相同

**位置**：`scripts/duel/duel_controller.gd:75-76`、`:207`、`:215`；`scripts/run/run_state.gd:61-64`

`run = RunState.new(12345, ...)`，且 `:207/:215` 用 `12345 + run.stage_index`。正式流程每局同一 seed ⇒ 三选一、开局免费心得、AI 出招序列、敌方开局宽限全部固定，**第二局起就在看同一套三选一**。

**建议**：seed 作为可注入参数，默认 `Time.get_ticks_usec() & 0x7fffffff`，仅测试/回放传固定值。

### 4.12 环境音：把音量当淡入时长，且退出时二次硬停产生僵尸播放器

**位置**：`scripts/audio/duel_audio.gd:87`、`:90-92`、`:98-102`、`:168-169`；`scripts/duel/duel_controller.gd:88`

- `SoundManager.play_ambient_sound(_wind, 0.6)` 的第二参数是**淡入时长**（`addons/sound_manager/sound_manager.gd:121` `func play_ambient_sound(resource, fade_in_duration: float = 0.0, override_bus := "")`），不是音量。插件按 `fade_volume(player, -80, 0, 0.6)` 淡到满音量 0 dB，0.7s 后才被本文件拉到 -14 dB → **开场 0.6 秒环境音明显偏响，随后「啪」地掉下来**。
- `stop_ambient(true)` 里 `_wind_player.stop(); _wind_player.stream = null` 改的是 SoundManager 池内播放器；`addons/sound_manager/abstract_audio_player_pool.gd:67-71` 的 `if player.stream.resource_path == resource.resource_path` 会对 null 取属性 → 僵尸播放器 + 潜在运行时报错（已亲验该行）。且 `duel_controller.gd:88` 的 0.3s 淡出被 `_exit_tree` 同帧硬停取消，离开对局时声音「啪」一声断掉。

**建议**：只调 `SoundManager.stop_ambient_sound(_wind, 0.3)` 并把 `_wind_player` 置 null，不要动池内播放器的 `stop()/stream`；目标音量与淡入分开设置；删掉 controller:88 的重复调用。

### 4.13 `settings`/`stats` 透传无 schema、无类型校验

**位置**：`scripts/core/meta_save.gd:154-165`

AnyCodec 只保证「JSON 载体类型」，任意键/任意嵌套结构都会进 `settings`/`stats`。手改档或字段冲突时：`stats` 混入数组 → `int([])` 直接抛运行时报错；`mute` 存成字符串 `"false"` → `bool("false")` 为 true（`game_bootstrap.gd:118`），玩家莫名静音；未知键永久累积。

**建议**：settings 加键白名单 + 每键类型强制；stats 用 `is int/float` 判断后再 `int()`，否则回落默认值并 warning。

### 4.14 `save()` 无去抖，拖音量就是几十次截断重写

**位置**：`scripts/core/meta_save.gd:93`；`scripts/ui/settings.gd:431-437`

滑块 `value_changed` 每次都 `apply_settings()` + `save_meta()`，拖一次音量就是几十次「截断+重写」，把 P1-6① 的丢档窗口放大两个数量级，设置页拖动也明显更卡。

**建议**：`save()` 加脏标记 + 0.3–0.5s 去抖/合并写，或 `_on_volume_changed` 用 `drag_ended`/定时器收口。

### 4.15 一次购买落盘两次，失败仍返回 true

**位置**：`scripts/core/unlocks.gd:52-60`；`scripts/ui/shop.gd:205-209`

`buy()` 内部 `meta.add_unlock(id); meta.save(); return true`，调用方 `elif Unlocks.buy(meta, id): GameBootstrap.save_meta()` 再写一次；`buy()` 不看 save 结果，返回 true 后商店立即显示「已拥有」，写盘失败则重启后物品消失而金币已扣——状态与存档不一致。

**建议**：领域方法只改内存，落盘统一由 `GameBootstrap.save_meta() -> bool` 收口；UI 依据保存结果显示成功/失败。

### 4.16 其余 P2（逐条）

| 编号 | 位置 | 问题 |
|---|---|---|
| P2-16 | `scripts/ui/shop.gd:56-59` | `_unhandled_input` 无 `visible`/栈顶判定，被覆盖时仍吞 `ui_cancel` 并 `UIManager.back()`；`settings.gd:80` 有守卫，两处不一致 |
| P2-17 | `scripts/ui/pause_menu.gd:19-20` vs `game_bootstrap.gd:180` | `ui_layer`/`cache_mode` 两处声明，`_on_init()` 在注册表之后执行并覆盖注册表值 → 改注册表静默无效 |
| P2-18 | `scripts/duel/match_setup.gd:40-41` | `swapped()` 换边后沿用旧 P2 的 `p2_profile`，性格错配；`of()` 无 null 校验。当前仅 `test_run_state.gd:163` 调用，属未接线但写错的入口 |
| P2-19 | `scripts/duel/duel_view.gd:180` | 表现层直读 `sim.mods` 可变 Dictionary（`sim.mods.get("hint_lead", 0)`），与「只读快照」注释不符；`mods` 改名会静默丢落刀预警 |
| P2-20 | `scripts/duel/duel_hud.gd:429` | `bar.max_value = 100.0` 不读 `fighter.data.max_flow`，改数值即错位 |
| P2-21 | `tests/` | GUT 退出期 `30 RIDs of type "CanvasItem" were leaked`、`151 ObjectDB instances were leaked`、`13 resources still in use`；`test_ui_gamepad.gd::test_shop_focuses_first_available_action` 单测 30 orphans；全套 `assert_no_new_orphans` **0 次**、`autofree` 仅 19 处 |
| P2-22 | `scripts/audio/duel_audio.gd:37-39` | `load()` 返回资源缓存里的共享实例，运行时改 `_wind.loop = true` 会污染整个进程；`amb_wind_loop.ogg.import:15` 里 `loop=false`，真正该改的是 `.import` |

---

## 5. P3 —— 记入待办即可

### 死代码 / 死常量（已跨文件复核）
- `scripts/duel/duel_sim.gd:32 const GUARD_COST := 5` —— 定义后从未引用。
- `scripts/core/input_devices.gd:8-11` `P1_ATTACK_BUTTON / P1_GUARD_BUTTON / P1_PAUSE_BUTTON / P1_RESTART_BUTTON` —— 四常量零引用，且是 `KeyBindings.DEFAULT_JOY_BUTTONS` 的手抄副本。
- `scripts/duel/duel_view.gd:26` 的 `_hit_side` —— 只赋值无读取。
- `scripts/duel/fighter_data.gd:182-190` `opponent_teaching()` / `opponent_for_stage()` —— 仅测试使用的薄封装。
- `scripts/duel/run_state.gd:18-21 const UPGRADE_IDS` —— 与 `game_bootstrap.gd:183-196 UPGRADE_DEFS` 双份真相；`_all_upgrade_ids()`（`:305-315`）已能从注册表取全量。

### 魔法数字（建议提常量或进数据表）
- `duel_controller.gd:210` `sim.p2.flow = 40`；`:211` `opening_lock_frames = 180`；`:214` `opening_grace_frames = 210`；`:236` `pending_character` 缺省 `&"char_a"`。
- `duel_ai.gd:184` `sim.frame >= 900`（15 秒）、`:198-200` `randi_range(3, 4)`、`:229` `0.15 * mini(..., 3) + clampf(0.75)`、`:76-77` `+0.15 / minf(0.9)`。
- `duel_hud.gd:284` `+42`、`:313` `/96.0`、`:342` `+96`、`:397` `flow <= 20`。
- `duel_view.gd:243` `span = 60.0`；`run_state.gd:249-265`（金币 10+6×hp_ratio、flawless +10、boss +30、heal = max_hp/3、zanshin 上限）。
- `fighter_state.gd:15/16/21/36` 默认值（hp=3、guard_duration=12、last_commit_frame=-9999）与数据层不一致，全靠 `reset()` 覆盖。

### 三份「心流档位」阈值实现
`duel_types.gd:56-57` 判定阈值 33/66；`duel_hud.gd:171-175` 用 34/67 判色；`duel_view.gd:86-90` 又一套。调常量时颜色与判定会脱钩。建议 `DuelTypes.flow_color_band()` 单一来源。

### 硬编码 / 占位
- `scripts/ui/settings.gd:12 const LANGUAGE_LABELS: Array[String] = ["中文", "English"]` —— 玩家可见文本绕过 I18N。
- `"[占位] " + key` 在 `menu.gd:221`、`pause_menu.gd:99`、`settings.gd:484`、`shop.gd:232`、`duel_hud.gd:409` **重复 5 份**；`duel_hud.gd:227` 靠 `begins_with("[占位]")` 做控制流，而英文占位前缀是 `[PLACEHOLDER]` → 英文环境该分支永不命中。
- 缺 `state.unknown` 键（`duel_types.gd:68-91 state_name()` 的 UNKNOWN 兜底）。
- `key_bindings.gd:195` `"Btn %d"` 硬编码英文兜底，经 `settings.gd:373` 直接进 UI。

### 规范 / 一致性
- `scripts/ui/settings.gd:46,72`、`shop.gd:37` 用 `call_deferred("_focus_default")` 字符串方法名 → 改名不报错、运行时静默无焦点。改 `_focus_default.call_deferred()`。
- `settings.gd:95,106,135` 取消绑定硬编码 `JOY_BUTTON_B` / `KEY_ESCAPE` / `JOY_BUTTON_BACK`，与 `ui_cancel` 并行的两套取消来源（重绑 UI 的合理例外，但未登记豁免）。
- `duel_view.gd:32-37` `disconnect` 未加 `is_connected` 防护（`duel_hud.gd:130-135`、`duel_audio.gd:64-81` 都有）。
- `duel_view.gd:47-52` 每帧无条件 `queue_redraw()`（`sim == null` 也重绘），`_draw` 内 arc 48/40/36/24 段每帧重建。
- `duel_hud.gd:384` `preload` 写在函数体内；`:54`、`:70-92` 大量 `Vector2(1280, ...)` 绝对尺寸。
- `duel_controller.gd:389-392` 用 `Time.get_ticks_msec()` 做 200ms 墙钟去抖（非帧基）。
- `menu.gd:145` 语言变化重建后无条件 `grab_focus()`，会去抢当前活跃面板焦点。
- `menu.gd:215`、`duel_controller.gd:434` `change_scene_to_file` 返回值未检查。
- `menu.gd` `_populate_characters()` 中 `ids[selected]` 未防空数组越界。
- `scripts/core/key_bindings.gd:106-112` 单键模型吃掉 `[KP_1, I]` 双键、不拒 `KEY_NONE(0)`（写入 0 会永久压住默认绑定）；`:91-94` `get_keys()` 读接口内部调 `normalize()` 有写副作用、O(n²)。
- `scripts/run/run_state.gd:240-242` `on_duel_finished()` 无 `if phase != Phase.DUEL: return` 守卫，重复调用会重复加金币/`record_run`/回血。
- `scripts/run/run_state.gd:185` `perfect_gain` 默认 12 vs 升级表 `u03` amount 18（靠赋值非叠加才没出错）。
- `scripts/audio/duel_audio.gd:161-165` `_play(options: Array, …)` 无元素类型（应 `Array[AudioStream]`）+ `randi()`/`randf_range` 走全局 RNG。

### 注释漂移
- `ai_profile.gd:7` 写 `FighterData._stage_enemy_id()`（实际 `stage_enemy_id`，`fighter_data.gd:195`）。
- `duel_ai.gd:199` 注释「0..4f 可取消窗」与实际 `cancel_window = 10` 不符；`DuelSim.cancel_commit()`（`duel_sim.gd:191-202`）本身不校验窗口。
- `fighter_data.gd:23` 声称「由 MatchSetup 从 AiProfile 注入 `flow_speeds_commit`」——不存在该注入。
- `duel_controller.gd:140` `_physics_process(_delta)` 未用 delta（帧基设计，可接受但缺注释）。
- `docs/dev-contract.md:137` 记 168 tests 与现 169 不一致。

### 仓库卫生
- `.gitignore` 中文注释为 GBK 编码，UTF-8 工具下显示乱码。
- `docs/gamejam/submission-checklist.md:63` 记录的产物大小 123,619,784 B 与实测 123,636,728 B 不一致。
- 导出包打进了 `res://addons/guide/debugger/guide_debugger.gdc` 与 `.scn`（`exclude_filter` 只排了 `addons/guide/editor/*`）。
- `localization/*.json` 无 `.import`、`include_filter` 为空，目前依赖 `export_filter="all_resources"` 的隐式行为被打包（日志已证实）。建议在 `include_filter` 显式加 `localization/*.json` 作回归防护。

---

## 6. 测试体系专项评估（子代理 D）

### 6.1 数量与形态

24 个文件（unit 15 + integration 9）、169 个 `func test_`、636 asserts。无 `assert_true(true)` 空测试、无 `OS.delay`/`sleep`、信号断言前都有 `watch_signals`、随机全部走 `RandomNumberGenerator`（无 `randf/randi/randomize()`）。

### 6.2 真实缺口（按严重度）

**P1 级覆盖缺口**

| # | 位置 | 缺口 |
|---|---|---|
| 1 | `test_meta_save.gd:44-50` | 只测「非 JSON」，`meta_save.gd:84-85` 的 `is_partial()` 字段级损坏分支**从未执行** |
| 2 | `test_duel_pause.gd:25-30` | 直调私有方法绕过真实 Esc（Esc 同时是 GUIDE `pause` 与 PauseMenu `ui_cancel`），200ms 墙钟去抖 `duel_controller.gd:389-392` 无覆盖 |
| 3 | `test_duel_gamepad.gd:32` | `assert_not_null(action)` 恒真；`:106-117` 热插拔只断言 `_context` 换对象、不验输入仍可用 |
| 4 | `test_settings.gd:10-24`、`test_duel_input.gd:84-109` | 全局 `GameBootstrap.meta` 在**用例末尾**还原，断言失败即污染后续 |
| 5 | `test_duel_input.gd` | 硬编码 `KEY_J/KEY_K/KEY_Y` 且析取断言掩盖帧序 |
| 6 | `test_menu.gd:24-39` | 只测金币文本与按钮数 `>=5`，五个入口接线零断言、按中文文案匹配 |
| 7 | `test_duel_hud.gd:24-26` | 断言私有节点与硬编码 `"1. [占位]"`、`"败北"`、`"开始"` |
| 8 | `test_duel_versus.gd:29-33` | 直调 `_on_p2_attack_pressed()` |
| 9 | `scripts/duel/duel_view.gd`（344 行）、`scripts/audio/duel_audio.gd`（169 行） | **tests 零引用** |
| 10 | `scripts/ui/shop.gd:193-209` | 无购买/开关行为测试（P0/P1 的商店缺陷因此未被发现） |

**P2 级：接近恒真或自证真**

- `test_input_devices.gd:31` 期望值由被测谓词自推（同义反复）。
- `test_duel_sim.gd:90` `assert_eq(state_duration, data.blocked_recovery)` 接近恒真；`:337-338` 复刻实现公式。
- `test_ui_gamepad.gd:23-29` 断言引擎默认 `ui_accept` 含手柄 A（删掉 `_add_joy_event` 仍绿）、`:77-98` 自建 Button 测引擎行为。
- `test_i18n.gd:18-21` 依赖前一条用例已载入 en。
- `test_duel_run.gd:26-28` 直接伪造 `sim.finished/winner` 绕过 `_check_end`。
- `test_duel_ai.gd:140-159` 直接驱动 `ai._guard_chance_now()` / `_consecutive_hits_taken` / `_on_hit_landed` 等私有成员。
- 平衡数值散落行为用例（`test_duel_sim.gd:91-92` flow 47/28、`test_run_state.gd:26-28` 金 12/治疗 20 等几十处）——调平衡必改测试。
- `test_shop_catalog.gd:8-14` 钉死 `items.size()==4` 与下标。
- `test_game_data.gd:24-26` 断言中文文案。

**P3**：`test_duel_pause.gd:6` / `test_duel_run.gd:6` `var ctrl` 无类型；`test_meta_save.gd:45-47` 文件句柄未判空；守卫 allow 用完整路径（改名即失效）。

### 6.3 建议补的 6 个测试（按优先级）

1. **守卫自检 + 扩范围**（对应 P1-7）：喂违规/安全样本，断言精确命中数；扫 `res://` 全仓。
2. **改键持久化端到端**（对应 P1-8）：带真实 `save_path` 的 save→load 往返。
3. **暂停/恢复真实 Esc/Start 链路**（对应 P1-1）：含 200ms 去抖与奖励阶段的焦点。
4. **坏档矩阵**（对应 P1-6）：非 JSON / 字段类型错 / 缺 version / 空文件 / 只读目录，断言备份与回落。
5. **商店购买持久化 + CACHE 重开后订阅**（对应 P1-3、4.15）。
6. **手柄热插拔后 A/B 功能可用**（对应 P1-7 的 `test_duel_gamepad.gd:106-117`）。

---

## 7. 已核验正常项（避免后续误报）

| 检查项 | 结论 |
|---|---|
| 静态类型 | **100% 合规**：0 个 `var` 缺显式类型、0 个 `func` 缺 `-> Type` |
| `Input.is_action_*` / `get_axis` / `is_key_pressed` 直读 | gameplay 代码 0 处（仅守卫测试的 needle 字符串）；`Input.*` 直读仅设备枚举/取消键兜底 6 处 |
| `TranslationServer` | 0 处 |
| `AudioStreamPlayer.new()` | 0 处；音效走 `SoundManager.play_ui_sound(preload(...))` |
| `GUIDEMappingContext.new()` | 仅 `scripts/core/input_guide.gd:36`（契约 §4 白名单）+ `tools/generate_guide_context.gd:70`（工具脚本，不在守卫范围） |
| `get_node("/root")` / 相对路径 `$"../../.."` | 0 处 |
| 字符串 `connect("name")` | 0 处，全部 `signal.connect(callable)` |
| `OS.delay_*` / `sleep` | 0 处 |
| GUT 全量 | 169 tests / 636 asserts / 24 scripts **全过**，`Start-Process` 复核**真实退出码 0** |
| headless 冒烟 | `--quit-after 240` 退出码 0，stderr 空，无 `SCRIPT ERROR` / `push_error` |
| 本地化 | zh 131 键 / en 131 键**集合完全相同**；代码引用的 65 个字面量键无缺失（`upgrade.%s.name` 是模板虚警） |
| 导出包本地化 | `build/export.log:643-644` 实证 `zh_CN.json` 与 `en.json` 已 `savepack` 进 PCK |
| 信号契约 | `DuelSim` 13 个信号与 HUD/View 处理函数签名逐一匹配 |
| 判定层易错点 | 双方同死 `winner = -1`（`duel_sim.gd:692-693`）、clash 双调用有 state 防护（`:483`）、礼让期 `last_input_frame` 重置（`:640-641`）均正确 |
| 输入上下文隔离 | `context_for()` 深拷贝 action 与 input（`input_guide.gd:32-50`），有注释说明「共享实例会被禁用旧上下文停掉」——正确解法，热插拔不会重复连接 |
| GUIDE 改键 index | `guide.gd:281-290` 用 `input_mappings` 数组索引，与 `input_guide.gd:77` 循环一致，**无语义错位** |
| autoload 顺序 | `project.godot:21-27` RegistryManager→EventBus→I18NManager→UIManager→SoundManager→GameBootstrap→GUIDE 与依赖一致 |
| 存档编码 | 走 `Codec`（`meta_save.gd:47-59`），JSON 解析错误走诊断路径 |
| 面板生命周期 | 开合全走 `UIManager.open_panel/back/close_panel`；两处 `change_scene_to_file` 都是主菜单↔对局的真场景切换，合规 |
| `addons/` | 未被修改（§3.2 遵守） |
| 工作区 | `git status --porcelain` 空 |

---

## 8. 建议的修复批次

**批次 A（半天内，低风险，先修测试地基）**
1. P1-7 守卫改标识符边界匹配 + 扫失败即报错 + 自检用例
2. P1-8 改键持久化端到端测试
3. P0-1 音量滑条键名（一处签名 + 三处调用 + 一个测试）
4. P1-1 暂停队列（`_clear_queued_input()` 或 `_paused` 守卫 + 一个测试）
5. P1-2 HUD 帧数（COMMIT 分支改读 `commit_total`）
6. P3 死常量删除（`GUARD_COST` + 4 个 `P1_*_BUTTON`）

**批次 B（一天，需回归）**
7. P1-3 商店订阅移到 `_enter_tree`
8. P1-4 奖励焦点恢复 + 奖励阶段禁开暂停
9. P2-2 设置页 `_loading` 守卫（与 P0-1 同批最省事）
10. P1-6 存档原子写 + 损坏备份 + version 迁移段（含坏档矩阵测试）
11. P2-4 字体去重 + `exclude_filter` 清理（省约 14 MB，消 UID 警告）

**批次 C（截止前，需人工决策）**
12. P1-5 关于页接线（**文案必须人类提供**）
13. P1-9 HUD 每帧刷新改脏检查
14. P2-1 HUD 场景化（最大工作量，可只做 HUD）
15. P2-6 契约例外登记（改 `docs/dev-contract.md`，非代码）
16. P2-8 删 AiProfile 死配置（涉及平衡参数，需人类确认）
17. P2-11 种子随机化（涉及可复现性策略，需人类确认）

**不做（记入 backlog）**
- P3 全部魔法数字提取、注释漂移、`.gitignore` 编码、三份档位阈值合并、测试孤儿节点治理、`duel_audio.gd` 的 `load`→`preload`。

---

## 9. 需要人类决策的 5 个点

1. **P1-5 二创声明文案**：AI 不得生成文案，需人类提供「关于」页正文（可先给 `[占位]` 键，但提交前必须填）。
2. **P2-8 `_BASE["counter"]` 与 `flow_speeds_commit`**：删死字段，还是改成真正生效（平衡改动）？
3. **P2-11 种子随机化**：正式版要不要每局随机？若要保持可复现（便于回放/调试）则维持现状。
4. **P2-6 AudioServer / InputMap 例外登记**：确认豁免写进 `docs/dev-contract.md` §3.1，还是等插件补 API。
5. **首批修复范围**：批次 A+B 是否本期全做？P0-1 与 P1-1 各约 10 行，建议先做这两条再评估。

---

## 附录：审计实证命令

```powershell
# 版本
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --version
# → 4.7.2.stable.mono.official.ed1daf0bf

# GUT 全量（必须用 Start-Process 取真退出码；管道会让退出码变 1）
$p = Start-Process -FilePath "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" `
  -ArgumentList '--headless','--path','.','-s','addons/gut/gut_cmdln.gd','-gdir=res://tests','-ginclude_subdirs','-gexit' `
  -NoNewWindow -PassThru -Wait -RedirectStandardOutput build/gut_full_out.log -RedirectStandardError build/gut_full_err.log
$p.ExitCode   # → 0；169 tests / 636 asserts

# headless 冒烟
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --path . --quit-after 240
# → 退出码 0；stdout 仅两行 Language loaded；stderr 空
```

导出日志关键证据：`build/export.log:17-19`（字体 UID 冲突）、`:643-644`（localization JSON 入包）。
