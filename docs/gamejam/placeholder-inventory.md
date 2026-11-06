# 占位字符串清单（Placeholder Inventory）

> **状态（2026-11-06）：44 条主表已按人类定稿全部回填**，见 `docs/gamejam/44条本地化占位-定稿.md` 与 `docs/dev-example/localization-final-copy-and-release-build.md`。
> 全文保留为 2026-11-04 的历史快照；**玩家可见占位已于 2026-11-06 清零**——`tutorial.spell` 显示已删除、修罗模式/快刀重刀已同步、8 处 `_tr()` 兜底改为缺键留空，详见 §9。
> 本文件 §2 的「44 条 × 2 份 = 88 条字符串」是回填前的统计，请勿再当作现状。

> 快照时间：2026-11-04　|　对象：本仓库当前工作树（语义化版本 `0.1.0`）
> 口径：**玩家可见文本占位** = 本地化文件里以 `[占位]` / `[PLACEHOLDER]` 开头的条目，加上提交清单里仍标「待提供」的文本项。
> 数据来源：直接解析 `localization/zh_CN.json`、`localization/en.json`，并逐条核对脚本里的取词调用链（不依赖文档里的历史统计）。

---

## 0. 一句话结论

- **44 条**文案占位 × 中英 **2 份** = **88 条字符串**，全部集中在 `localization/`；两份文件键集合 **151 / 151** 完全一致，占位键也**一一对应**。
- 另有 **9 处**代码内兜底占位（`"[占位] " + key` 之类）和 **3 类**非文本占位（素材、构建、提交材料），单列在 §4、§5。
- 两个**结构性缺口**（不是改文案能解决的）：
  1. `spell.*.desc` 4 条**没有任何显示路径**——`SpellCardData.desc_key` 只赋值、从不读取，改完了玩家也看不见；
  2. **5 个对手名没有任何文本载体**——HUD 不显示对手名，`AiProfile.display_name` 只是编辑器可读性字段，PH-03 目前无处落地。

---

## 1. 统计总览

| 类别 | 条数 | 键 | 对应登记 |
|---|---|---|---|
| 作品标题 / 标语 | 2 | `menu.title`、`menu.subtitle` | PH-01 |
| 商店条目（名 + 描述 × 4） | 8 | `shop.item.{char_b,char_c,start_slot,hard_mode}.{name,desc}` | PH-16 |
| 状态显示名 | 1 | `state.spell` | PH-05 |
| 教程提示 | 5 | `tutorial.{start,guard,attack,flow,wait}` | PH-07 / PH-14 |
| 心得（名 + 描述 × 10） | 20 | `upgrade.u01..u10.{name,desc}` | PH-04 / PH-14 |
| 符卡（名 + 描述 × 4） | 8 | `spell.{spell_a,spell_b,spell_c,spell_boss}.{name,desc}` | PH-18 |
| **合计** | **44** | — | PH-14 / PH-17 |

> ⚠️ `docs/dev-example/design.md` §15.2 末尾那句「分布为作品名 1、玩家角色名 3、商店条目 8、状态名 1、教程 5、心得 20、符卡名 4、符卡描述 4」**加起来是 46，与实际 44 对不上**：玩家角色名 3 条（`menu.char_a/b/c`）从来没有加占位标记，而标题实际有 title + subtitle 两条。本文的分布是实扫结果，以此为准。

---

## 2. 主表：44 条本地化占位

> 「JSON 行」是中英两份文件里的**同一行号**（两份文件结构完全对齐）。
> 「显示位置」都是仓库相对路径 + 行号，可直接跳转。

| # | I18N 键 | JSON 行 | 中文占位（zh_CN） | 英文占位（en） | 显示位置 | 登记 |
|---|---|---|---|---|---|---|
| T-01 | `menu.title` | 26 | `[占位] 刀剑 · 心流` | `[PLACEHOLDER] Sword · Flow` | `scripts/ui/menu.gd:55`（主菜单大标题） | PH-01 |
| T-02 | `menu.subtitle` | 27 | `[占位] 一瞬决胜负` | `[PLACEHOLDER] One instant decides` | `scripts/ui/menu.gd:65`（标题下一行） | PH-01 |
| T-03 | `shop.item.char_b.name` | 61 | `[占位] B · 快剑` | `[PLACEHOLDER] B · Swift` | `scripts/ui/shop.gd:149`（商店条目标题） | PH-16 |
| T-04 | `shop.item.char_b.desc` | 61 | `[占位] 前摇 11 帧、收招最快，单刀 7 伤` | `[PLACEHOLDER] 11-frame windup, fastest recovery, 7 damage per cut` | `scripts/ui/shop.gd:156`（条目副标题） | PH-16 |
| T-05 | `shop.item.char_c.name` | 62 | `[占位] C · 重剑` | `[PLACEHOLDER] C · Heavy` | `scripts/ui/shop.gd:149` | PH-16 |
| T-06 | `shop.item.char_c.desc` | 62 | `[占位] 生命 40、单刀 15 伤并附加 12 帧破势，前摇最长` | `[PLACEHOLDER] 40 HP, 15 damage plus 12 frames of stagger, longest windup` | `scripts/ui/shop.gd:156` | PH-16 |
| T-07 | `shop.item.start_slot.name` | 63 | `[占位] 起始心得` | `[PLACEHOLDER] Starting Insight` | `scripts/ui/shop.gd:149` | PH-16 |
| T-08 | `shop.item.start_slot.desc` | 63 | `[占位] 每局开局随机获得一个心得` | `[PLACEHOLDER] Gain one random insight at the start of each run` | `scripts/ui/shop.gd:156` | PH-16 |
| T-09 | `shop.item.hard_mode.name` | 64 | `[占位] 困难模式` | `[PLACEHOLDER] Hard Mode` | `scripts/ui/shop.gd:149` | PH-16 |
| T-10 | `shop.item.hard_mode.desc` | 64 | `[占位] 对手心流更高、出手更频繁；架窗整体回退一档` | `[PLACEHOLDER] Opponents start with more flow and act more often; guard windows drop one tier` | `scripts/ui/shop.gd:156` | PH-16 |
| T-11 | `state.spell` | 132 | `[占位] 符卡` | `[PLACEHOLDER] Spell` | `scripts/duel/duel_hud.gd:446`（中央状态行，仅 SPELL 状态出现） | PH-05 |
| T-12 | `tutorial.start` | 135 | `[占位] 开局：先看清刀光，别急着出手` | `[PLACEHOLDER] Opening: read the tell before you move` | `scripts/duel/duel_hud.gd:435`（单人模式底部提示，开局窗） | PH-07 |
| T-13 | `tutorial.guard` | 136 | `[占位] 对手起构：按住防御，在刀到之前架住` | `[PLACEHOLDER] Opponent commits: hold guard before the blade lands` | `scripts/duel/duel_hud.gd:437`（对手 COMMIT 时） | PH-07 |
| T-14 | `tutorial.attack` | 137 | `[占位] 对手收招：现在出刀，他挡不住` | `[PLACEHOLDER] Opponent recovering: strike now, they cannot block` | `scripts/duel/duel_hud.gd:439`（对手 RECOVERY / GUARD_REC 时） | PH-07 |
| T-15 | `tutorial.flow` | 138 | `[占位] 心流偏低：架窗变窄，先稳住` | `[PLACEHOLDER] Low flow: your guard window narrows, steady yourself` | `scripts/duel/duel_hud.gd:441`（P1 心流 ≤ 20） | PH-07 |
| T-16 | `tutorial.wait` | 139 | `[占位] 对峙中：别先出手，等他的破绽` | `[PLACEHOLDER] Standoff: do not strike first, wait for the opening` | `scripts/duel/duel_hud.gd:442`（以上都不满足时的默认行） | PH-07 |
| T-17 | `upgrade.u01.name` | 143 | `[占位] 架窗` | `[PLACEHOLDER] Guard Window` | `scripts/duel/duel_hud.gd:394`（三选一按钮首行） | PH-04 |
| T-18 | `upgrade.u01.desc` | 144 | `[占位] 架刀有效帧 +3，更容易架住快刀` | `[PLACEHOLDER] Guard lasts 3 more frames, easier to catch fast cuts` | `scripts/duel/duel_hud.gd:396`（三选一按钮第二行） | PH-04 |
| T-19 | `upgrade.u02.name` | 147 | `[占位] 疾构` | `[PLACEHOLDER] Quick Commit` | 同上 | PH-04 |
| T-20 | `upgrade.u02.desc` | 148 | `[占位] 出刀前摇 -3 帧，抢刀更快` | `[PLACEHOLDER] Slash windup -3 frames, win the race` | 同上 | PH-04 |
| T-21 | `upgrade.u03.name` | 151 | `[占位] 完美` | `[PLACEHOLDER] Perfect` | 同上 | PH-04 |
| T-22 | `upgrade.u03.desc` | 152 | `[占位] 完美格挡回心流 18（基础为 12）` | `[PLACEHOLDER] Perfect guard returns 18 flow (base is 12)` | 同上 | PH-04 |
| T-23 | `upgrade.u04.name` | 155 | `[占位] 静心` | `[PLACEHOLDER] Calm Mind` | 同上 | PH-04 |
| T-24 | `upgrade.u04.desc` | 156 | `[占位] 开局心流 +10，起手更宽裕` | `[PLACEHOLDER] Start each duel with +10 flow` | 同上 | PH-04 |
| T-25 | `upgrade.u05.name` | 159 | `[占位] 看破` | `[PLACEHOLDER] Read` | 同上 | PH-04 |
| T-26 | `upgrade.u05.desc` | 160 | `[占位] 对手的刀光预警提前 6 帧` | `[PLACEHOLDER] The opponent's blade warning appears 6 frames earlier` | 同上 | PH-04 |
| T-27 | `upgrade.u06.name` | 163 | `[占位] 见切` | `[PLACEHOLDER] See-Through` | 同上 | PH-04 |
| T-28 | `upgrade.u06.desc` | 164 | `[占位] 心流不低于 50 时可抵消一次伤害，额外消耗 30 心流（每场一次）` | `[PLACEHOLDER] At 50+ flow, negate one hit for an extra 30 flow (once per duel)` | 同上 | PH-04 |
| T-29 | `upgrade.u07.name` | 167 | `[占位] 追击` | `[PLACEHOLDER] Pursuit` | 同上 | PH-04 |
| T-30 | `upgrade.u07.desc` | 168 | `[占位] 命中后 3 秒内下一刀 +10 伤害（每场一次）` | `[PLACEHOLDER] The next hit within 3s after a hit deals +10 damage (once per duel)` | 同上 | PH-04 |
| T-31 | `upgrade.u08.name` | 171 | `[占位] 胆力` | `[PLACEHOLDER] Guts` | 同上 | PH-04 |
| T-32 | `upgrade.u08.desc` | 172 | `[占位] 受击后 5 秒内免疫心流流失` | `[PLACEHOLDER] No flow loss for 5s after taking a hit` | 同上 | PH-04 |
| T-33 | `upgrade.u09.name` | 175 | `[占位] 先手` | `[PLACEHOLDER] First Strike` | 同上 | PH-04 |
| T-34 | `upgrade.u09.desc` | 176 | `[占位] 开局第 3 至 8 秒内出刀前摇 -3 帧` | `[PLACEHOLDER] Slash windup -3 frames from second 3 to 8` | 同上 | PH-04 |
| T-35 | `upgrade.u10.name` | 179 | `[占位] 复元` | `[PLACEHOLDER] Recovery` | 同上 | PH-04 |
| T-36 | `upgrade.u10.desc` | 180 | `[占位] 每场胜利后的回复量翻倍` | `[PLACEHOLDER] Healing after each win is doubled` | 同上 | PH-04 |
| T-37 | `spell.spell_a.name` | 184 | `[占位] 架势` | `[PLACEHOLDER] Stance` | `scripts/duel/duel_hud.gd:221`（HUD 符卡行）+ `:371`（`◆ 名称 ◆` 报幕） | PH-18 |
| T-38 | `spell.spell_a.desc` | 184 | `[占位] 展开架势：60 帧内任意架刀都判定为完美格挡` | `[PLACEHOLDER] Any guard within 60 frames counts as a perfect guard` | **无显示路径**（见 §6.2） | PH-18 |
| T-39 | `spell.spell_b.name` | 185 | `[占位] 疾风连斩` | `[PLACEHOLDER] Gale Slash` | `duel_hud.gd:221` / `:371` | PH-18 |
| T-40 | `spell.spell_b.desc` | 185 | `[占位] 蓄力 8 帧后自动出刀，20 伤害，无视对手的架` | `[PLACEHOLDER] After an 8-frame charge, cut for 20 damage, ignoring guard` | **无显示路径** | PH-18 |
| T-41 | `spell.spell_c.name` | 186 | `[占位] 崩山` | `[PLACEHOLDER] Mountain Fall` | `duel_hud.gd:221` / `:371` | PH-18 |
| T-42 | `spell.spell_c.desc` | 186 | `[占位] 蓄力 20 帧后自动出刀，30 伤害，无视架并追加硬直` | `[PLACEHOLDER] After a 20-frame charge, cut for 30 damage, ignoring guard and adding stagger` | **无显示路径** | PH-18 |
| T-43 | `spell.spell_boss.name` | 187 | `[占位] 终式` | `[PLACEHOLDER] Final Form` | `duel_hud.gd:221` / `:371`（关底「剑鬼」） | PH-18 |
| T-44 | `spell.spell_boss.desc` | 187 | `[占位] 蓄力 14 帧后自动出刀，30 伤害，无视架并追加硬直` | `[PLACEHOLDER] After a 14-frame charge, cut for 30 damage, ignoring guard and adding stagger` | **无显示路径** | PH-18 |

---

## 3. 未加占位标记、但清单仍标「待提供」的条目

这些条目**已经有正式文本**，只是文本是「通用代号 / 功能性标签」性质，清单里仍挂着「待提供」。替换与否需要人类拍板，不计入 44 条，但提交前必须逐条确认。

| # | I18N 键 | JSON 行 | 当前文本（中） | 显示位置 | 登记 | 说明 |
|---|---|---|---|---|---|---|
| U-01 | `menu.char_a` | 39 | `A · 均衡` | `scripts/ui/menu.gd:178`（角色下拉） | PH-02 | 通用代号，非角色真名 |
| U-02 | `menu.char_b` | 40 | `B · 快剑` | 同上 | PH-02 | 同上（需解锁） |
| U-03 | `menu.char_c` | 41 | `C · 重剑` | 同上 | PH-02 | 同上（需解锁） |
| U-04 | `state.idle` | 123 | `待机` | `duel_hud.gd:446`（状态行） | PH-05 | 功能性状态名，非占位 |
| U-05 | `state.commit` | 124 | `构` | 同上 | PH-05 | 同上 |
| U-06 | `state.slash` | 125 | `斩` | 同上 | PH-05 | 同上 |
| U-07 | `state.recovery` | 126 | `硬直` | 同上 | PH-05 | 同上 |
| U-08 | `state.guard` | 127 | `架` | 同上 | PH-05 | 同上 |
| U-09 | `state.guard_rec` | 128 | `收架` | 同上 | PH-05 | 同上 |
| U-10 | `state.hitstun` | 129 | `受击` | 同上 | PH-05 | 同上 |
| U-11 | `state.clash` | 130 | `刃鸣` | 同上 | PH-05 | 同上 |
| U-12 | `state.down` | 131 | `败北` | 同上 | PH-05 | 同上 |
| U-13 | `ui.round_start` | 18 | `开始` | `scripts/duel/duel_hud.gd:273`（开局提示） | PH-15 | 礼让结束的「开始」提示，清单明确待提供 |
| U-14 | （无键、无载体） | — | — | — | PH-03 | **5 个对手名在游戏里根本没有显示位置**，需先加 HUD 位置与 I18N 键 |

---

## 4. 代码内占位与兜底字符串

这些不是「待人类填的文案」，但会在**键缺失**时显示到玩家眼前，属于占位体系的一部分。

| # | 位置 | 字符串 | 触发条件 | 备注 |
|---|---|---|---|---|
| C-01 | `scripts/ui/menu.gd:238` | `"[占位] " + key` | I18N 取不到该键 | `_tr()` 兜底，会把键名暴露给玩家 |
| C-02 | `scripts/ui/shop.gd:241` | `"[占位] " + key` | 同上 | 同上 |
| C-03 | `scripts/ui/settings.gd:589` | `"[占位] " + key` | 同上 | 同上 |
| C-04 | `scripts/ui/pause_menu.gd:99` | `"[占位] " + key` | 同上 | 同上 |
| C-05 | `scripts/ui/mode_select.gd:141` | `"[占位] " + key` | 同上 | 同上 |
| C-06 | `scripts/ui/about_panel.gd:163` | `"[占位] " + key` | 同上 | 同上 |
| C-07 | `scripts/duel/duel_hud.gd:452` | `"[占位] " + key` | 同上 | 判定用**判等**（`text == key`）而非前缀，改动安全 |
| C-08 | `scripts/duel/ai_profile.gd:12` | `"PLACEHOLDER_OPPONENT` | 资源默认值 | 注释明确「不参与显示」，可保留 |
| C-09 | `scripts/duel/ai_profile.gd:80` | `"PH_OPPONENT_%s" % id` | `for_persona()` 构造时 | 仅编辑器内可读，**不出现在画面**；与 PH-03 有关但不算文案 |

另有两条**非占位**的优雅兜底（不属于占位，替换文案时不必动）：

- `scripts/run/run_state.gd:228` → `ui.upgrade_unknown`（`未命名心得`），心得资源缺失时的名字兜底；
- `scripts/run/run_state.gd:235` → 空串，描述缺失时的兜底。

---

## 5. 非文本占位（素材 / 构建 / 提交材料）

| # | 项 | 落点 | 现状 | 登记 |
|---|---|---|---|---|
| A-01 | 角色/对手立绘 | `resources/spine/*.tres` + `skeleton.spine-json`/`.atlas`/`.png` | 8 份档案共用 1 套**测试 chibi**（32 骨骼/33 槽位/10 IK/1323×1537）；已有 `zhanli`/`gongji`/`bei_gongji`/`fangyu`/`siwang` 五段，缺符卡与专门的对刀动画；缺失时回退灰盒 | PH-12 / PH-19 |
| A-02 | 灰盒角色 | `scripts/duel/duel_view.gd` | 无 Spine 档案/扩展时的几何体替身 | 同上 |
| A-03 | 战斗音效 / 环境音 | `assets/audio/sfx/`（16 个）+ `assets/audio/amb/amb_wind_loop.ogg` | CC0 第一版已接线，未经人类试听选型 | PH-11 |
| A-04 | 封面 | 仓库外 | 未提供 | PH-10 |
| A-05 | 提交用 README | 仓库外 / `README.md` 是工程说明 | 人类撰写中 | 清单 §4 |
| A-06 | 提交记录表 | `docs/gamejam/submission-checklist.md:120-126` | 时间/通道/凭证/构建版本/提交人 全为「（待填）」 | 清单 §5 |

---

## 6. 替换前必须知道的 6 件事

### 6.1 测试会红——断言把 `[占位]` 前缀写死了

改完 JSON 立刻跑 GUT 会失败，因为下面几处断言要求文本**仍以占位前缀开头**：

| 测试 | 行 | 断言 |
|---|---|---|
| `tests/unit/test_game_data.gd` | 19 | `I18NManager.get_text("upgrade.u01.name").begins_with("[占位]")` |
| `tests/unit/test_game_data.gd` | 20 | `...("upgrade.u01.desc").contains("+3")` ← **描述里的数值也被锁死** |
| `tests/unit/test_game_data.gd` | 21 | `...("tutorial.start").begins_with("[占位]")` |
| `tests/unit/test_i18n.gd` | 15 | 英文 `upgrade.u01.name` `begins_with("[PLACEHOLDER]")` |
| `tests/unit/test_i18n.gd` | 34 / 37 | 9 个符卡键 + `state.spell` 中/英都必须以占位前缀开头 |
| `tests/integration/test_duel_hud.gd` | 25 | 奖励按钮文本 `begins_with("1. [占位]")` |

替换文案时，**同一批**把上述断言改成「非占位」判定（例如 `assert_false(...begins_with("[占位]"))`），否则 `-gexit` 退出码为 1。

### 6.2 符卡描述改了也看不见

`scripts/duel/spell_card.gd:21` 的 `desc_key` 只在 `_guard_stance()` 等 4 处被赋值，**全仓库没有任何读取点**（`duel_hud.gd:221` 只读 `card.name_key`）。想让它可见，得先加 UI（例如在 HUD 符卡行加 tooltip 或长按提示），这属于功能改动，不是文案替换。

### 6.3 键不能被删，只能改值

`_tr()` 的兜底是「取不到 → 显示 `[占位] <key>`」。删键或改键名会让玩家看到 `[占位] upgrade.u01.name` 这种开发者标记，且 `test_i18n` 的键存在性检查会失败。

### 6.4 中英必须同步改

两份文件键集合当前 151/151 完全一致，占位键也一一对应。只改中文而不改英文，`en` 玩家仍会看到 `[PLACEHOLDER] ...`，且 `test_i18n.gd:15` 依赖英文占位形态。

### 6.5 描述里的数值目前是「真实机制数值」

10 条心得描述与 4 条符卡描述已经按 0.1.0 的实际机制写好（+3 / -3 / 18 / 6 帧 / 30 心流 / 20 伤 等）。替换文案时**保留数值与效果**，只改措辞和名称——否则会与 `run_state.gd` 的实际加成脱节，`test_game_data.gd:20` 也会失败。

### 6.6 关底符卡与角色符卡共用一套键结构

`spell_boss` 与 `spell_a/b/c` 同级，报幕只显示名字（`◆ 名称 ◆`，96f），**不加任何动词**（设计约定）。写文案时不要写成句子，否则报幕会超宽。

---

## 7. 建议替换顺序（按依赖与体量）

1. **T-01 / T-02**（标题、标语）——最先定，其他文档/封面要跟它对齐；
2. **T-17 ~ T-36**（心得 20 条）——体量最大，但结构统一，可一次改完；
3. **T-03 ~ T-10**（商店 8 条）——依赖角色/心得名，等 1、2 定稿后再改；
4. **T-37 / T-39 / T-41 / T-43**（符卡名 4 条）——报幕与 HUD 同时生效，改完进一局看宽度；
5. **T-38 / T-40 / T-42 / T-44**（符卡描述 4 条）——先决定是否接 UI（§6.2），否则可延后；
6. **T-12 ~ T-16**（教程 5 条）——建议真人试玩一局后再写，避免与手感脱节；
7. **T-11**（`state.spell`）——一条即可；
8. **§3 的 U-01 ~ U-14**——确认「代号算不算正式名」，以及是否给对手名加 HUD 位置。

每批改完后：跑 GUT（`-gdir=res://tests -ginclude_subdirs -gexit`）→ 更新 `docs/gamejam/submission-checklist.md` §7 的数量 → 在 `CHANGELOG.md` 记一行。

---

## 8. 复核方式（复查时用同一口径）

```powershell
# 中文占位条数（应为 44）
(Select-String -Path localization/zh_CN.json -Pattern '[占位]' -SimpleMatch | Measure-Object).Count

# 英文占位条数（应为 44）
(Select-String -Path localization/en.json -Pattern '[PLACEHOLDER]' -SimpleMatch | Measure-Object).Count

# 代码内兜底占位（7 个 _tr() + 2 个 ai_profile 常量）
Get-ChildItem scripts -Recurse -Filter *.gd | Select-String -Pattern '[占位] ' -SimpleMatch
```

> 口径提醒：`about.ai_body`（`localization/zh_CN.json:117`）正文里含「显式占位」四个字，用「含『占位』」计数会得到 45，**它不是占位条目**。用 `[占位]` 精确匹配即得 44。
> **2026-11-06 更新：此复核命令的期望值已失效**——两份 JSON 现只剩 1 条占位（`tutorial.spell`），代码内兜底串仍是 8 处（`about.ai_body` 措辞已过时）。

---

## 9. 2026-11-06 最终现状（本节为最新）

已完成：

- 44 条按定稿回填，`zh_CN.json` / `en.json` 各 165 键；GUT 311/311（1309 asserts）通过。改写过的 5 处占位断言见 `docs/dev-example/localization-final-copy-and-release-build.md` §1。
- `shop.hard_on/off` → 「修罗模式：开/关」（en `Asura Mode: ON/OFF`）；`menu.char_b/c` → 「B · 快刀 / C · 重刀」（en `B · Swift Blade / C · Heavy Blade`），与商店条目名统一。
- 8 处 `_tr()` 兜底取消占位前缀：缺键时 `push_warning` 并返回空串；`scripts/ui/settings.gd` 键位按钮在空绑定时显示 `—`（标识空键位）。`scripts/duel/spell_card.gd:6` 注释同步。
- `tutorial.spell` 的**显示已删除**：`scripts/duel/duel_hud.gd` 的 `_tutorial_text()` 不再返回它；底部操作行（`ui.controls` / `ui.controls_template`）已含「L 发动符卡」。键保留在 JSON 中但无引用。

仍保留（不阻塞提交）：

1. `tutorial.spell` 键仍是 `[占位]` / `[PLACEHOLDER]` 值（无显示路径）；定稿表补文案后可直接替换，或按需删除该键。
2. `spell.*.desc` 4 条无显示路径（`scripts/duel/spell_card.gd` 只赋 `desc_key`，HUD 不读），按人类指令「先记着」保留。
3. 非文本占位（§5）：Spine 运行时授权、封面/README 等提交材料仍需人类确认；导出构建已产出（见 `docs/dev-example/localization-final-copy-and-release-build.md` §2），Spine 运行时会随包分发，对外发布前须确认授权。

> 复核命令（2026-11-06 口径）：`Select-String -Path localization/zh_CN.json -Pattern '[占位]' -SimpleMatch` 命中 **1**（`tutorial.spell`，无显示路径）；`Get-ChildItem scripts -Recurse -Filter *.gd | Select-String -Pattern '"[占位] "'` 命中 **0**。
