# 变更记录（CHANGELOG）

本文件记录**已交付的变更**，按版本倒序。开发期的中间迭代号（`v0.20`–`v0.29`）只出现在 `docs/dev-example/design.md` 的历史行与阶段状态文档里，不再作为发布版本号使用；自本条起使用语义化版本。

格式：`版本 / 日期`，下分「修复」「机制」「文档」三组。每条给出**问题 → 修法 → 验证**，不写「优化了体验」这类无法核对的话。

---

## 0.1.0 — 2026-10-21

首个语义化版本。判定依据：基本操作可确定（键鼠 + 手柄、暂停/恢复、改键、存档/清档全链路）且难度经人工简测通过。此前全部代码在这一天经历了**一次全量审计 + 六批修复**，下面按批次记录。

### 批次一：全量代码审计（只读，`docs/audit/code-audit-2026-10-21.md`）

四路并行审计（判定/表现层、核心/存档/输入/音频、UI 层、测试层），产出 1 条 P0、9 条 P1、22 条 P2、30+ 条 P3，每条都带 `file:line` 与证据三级标注（实测 / 静态精读 / 推断）。审计结论中**没有**发现崩溃路径、导出缺资源、判定层逻辑错误、插件源码被改。

### 批次二：P0 + 存档可靠性 + 种子 + AI 性格（`a9fcb5c`）

- **修复（P0）音量滑条完全无效**：`settings.gd` 把 I18N 键 `settings.master` 当作设置键传入，显示与存储一职两用，而 `apply_settings()` 读的是 `volume_master`。→ 拆成 `label_key` / `setting_key` 两个参数，三个滑条分别写 `volume_master`/`volume_sfx`/`volume_ambient`；`_load_values()` 改用 `set_value_no_signal`，避免打开设置页触发 5 次 `apply_settings()` + 5 次落盘。
- **修复（P1）存档三条同源缺陷**：`FileAccess.WRITE` 截断写无备份；损坏档回落默认值后下次 `save()` 直接覆盖原档；`version` 因等于默认值被 `MapCodec` 裁剪，文件里从来没有版本号。→ 改为三步原子写（`.tmp` → 旧档转 `.bak` → 转正，失败回滚）；坏档改名 `.corrupt` 隔离；`version` 改为默认 `0` 并在 `_from_dict` 记录来源版本，`_migrate()` 按来源版本补缺键；新增 `MetaSave.wipe()`。
- **机制** 种子随机化：`duel_controller` 原来写死 `12345`，导致每局三选一/AI 序列完全相同。→ 新增 `_new_seed()`（`randi_range(1, 2147483646)`，避开 0 哨兵）与 `_stage_seed(stage_index)`（线性同余，保证同局内各关可复现）。
- **机制** AI 性格正式生效：`ai_profile.gd` 的 `_BASE["counter"]` 五个值从未被读取（两分支都硬编码 `counter_chance = 1.0`），`flow_speeds_commit` 也是死字段。→ 删死字段；新增 `counter_delay_frames = maxi(6, roundi((1.0 - counter) * 14.0))`（6–8 帧，认招快慢的差异），`_try_counter` 用它做迟滞。
- **机制**「关于」页：新建 `scenes/ui/about.tscn` + `scripts/ui/about_panel.gd`，含东方 Project 二创声明、与官方无关联声明、AI 使用说明、素材来源、版本号；主菜单入口。
- **机制** 人工清档：设置页「清除存档」二次确认（3 秒内按两次），删 `.json`/`.tmp`/`.bak`/`.corrupt` 四类。
- **文档** `docs/dev-contract.md` §3.1 登记 5 项插件豁免（AudioServer Master/mute、`InputMap` 的 `ui_*` 手柄补充、`GUIDE._input_state`、`GUIDERemappingConfig._bind/_unbind`、`Input.get_connected_joypads()` 只读），并附 SoundManager 上游 v2.6.2 仍无 master/mute 的证据。
- **验证** GUT 185/185（723 asserts）、headless 冒烟 240 帧无错误、本地化 147 键中英一致。

### 批次三：架防按住不生效 + 主菜单二级化（`2b15e04`）

- **修复** 「按住防御仍挨打」：`_apply_pending_input` 只把「按下那一帧的上升沿」交给 `_apply_action`，`_guard_held` 从不参与起架，所以礼让期内按住、硬直中按住、架满自动收架后仍按住，三种情况都永不生效。→ 在 `action == NONE` 分支补「仍按住且 `IDLE` → 补发 GUARD」。**只补 `IDLE` 是刻意的**：`COMMIT` 中按防是「取消出刀转架」，必须一次明确的新按下，否则按住防御就永远出不了刀。
- **机制** 主菜单二级化：一级入口 6 → 4（开始游戏 / 商店 / 设置 / 退出），「单人阶梯」「本地双人」收进「开始游戏」的 `mode_select` 面板；「关于」移到设置页。解决 6 个按钮在 720p 下重叠。
- **文档** 新建 `docs/dev-example/balance-pass-05.md`（架防根因链、未采用的三种做法、验证与遗留）。
- **验证** GUT 190/190（731 asserts）、冒烟 151 键 × 2 语言。

### 批次四：空架手感与难度单一真相（`2a7e205`、`8c30dd5`）

- **机制** 空架收势 8/7/9f → **2/1/4f**（均衡/快剑/重剑）：架窗按满却没挡到，仍扣 8 心流、断完美连击，但不再「罚站」到被对手确定惩罚。人类原话（`m01110`）：「可以缩短到 1 到 2 帧，重剑最多 4 帧。然后扣除心流……至少架防过期可以让人无感切换，但总有操作空间，也便于区分角色。」
- **修复** `GameBootstrap.hard_mode` 缓存副本与 `meta.settings` 脱钩，测试替换 `GameBootstrap.meta` 后第 2 关敌人血量被错算成 40。→ 删除缓存字段，改为只从 `meta.settings["hard_mode"]` 读一处真相。
- **修复** AI 反斩骰子被白白消费：`_counter_will = false` 在 `press(ATTACK)` 之前无条件执行，自身还在硬直时按键被丢弃且进入冷却。→ 改为「真正起构才消费」。
- **文档** 更正 `docs/gamejam/ai-disclosure.md` 早期「只架不攻必赢」的结论：`_check_end()` 只看 HP、格挡不造成伤害，该说法在代码上不成立；`balance-pass-05.md` §7 记录。
- **验证** GUT 191/191（736 asserts）。

### 批次五：文案占位与描述对齐（`e1fc420` 前半）

- **修复** 7 条升级描述与实际不符：u03 是绝对值 18（基础 12，描述没写）；u05「看破」描述为看对手，实际 `hint_lead` 只提前**自己**的收束环；u06 漏写「消耗 30 心流」；u07 描述 +1 伤害实际 **+10**；u08 描述 2 秒实际 **5 秒**；u09 描述「开场 3 秒」实际第 180–479 帧；u10 描述「+2 生命」实际**回复量翻倍**。→ 按实际数值重写 10 条描述（中英），保留 `[占位]` / `[PLACEHOLDER]` 前缀（人类 `m01536`：文案仍在开发期，保持占位等人类定稿）。
- **修复** u03 的 `perfect_gain` 会同时作用于双方（P2 完美格挡也吃 18）。→ `_do_block` 只对 P1 读 `mods`，P2 恒用基础值 12。
- **修复** u05 对对手无效，名实不符。→ `duel_view` 的 `hint_lead` 改为**对 P2 的收束环也提前**，玩家能更早看到对手出刀。
- **调整** 难度回落：`SLASH_WARN_FRAMES` 8 → 16；玩家架窗 20/18/22 → 24/22/26；空挥收招 20/16/24 → 14/12/18；被架收招 32/24/36 → 28/22/32；`cancel_cost` 5 → 10；AI `guard_chance` 下调到 0.18/0.15/0.24/0.24/0.28。
- **验证** GUT 192/192（738 asserts）。

### 批次六：难度量化 + 收招取消（`6f36b27`）

- **工具** 新增 `tools/sim_balance.gd`（5 关 × 60 局自动对战，输出胜率 + 反应延迟曲线 + 架刀率消融）与 `tools/sim_trace.gd`（单局逐帧日志，定位「按了没反应」）。这是把「我觉得难」变成可复现数字的关键一步。
- **发现** 三个结构性根因：① 出刀总硬直（前摇 + 5f 判定 + 收招 20f）里攻击/防御输入被**静默丢弃且无缓冲**，玩家体感「按了没反应」；② AI 前摇 28–30f 几乎等于玩家「看到起手才反应」的最快反应时间（18–30f），`SLASH_WARN_FRAMES` 是唯一公平预警；③ AI 架刀吃满（`guard_chance` 0.45 + 「看到出刀再架」的对策），架住即白送一刀。
- **机制** 收招取消：`RECOVERY` 第 2 帧起按防可转架，代价 10 心流 + 架窗减半（`_guard_held` 也扩展到 `RECOVERY` 以支持按住）。把「出刀 = 必被惩罚」改成「出刀 = 可买保险」。
- **验证** 模拟器在延迟 4–12 帧全 100%（旧参数在延迟 10 帧只有 13%）；GUT 195/195（746 asserts）、冒烟 151 键 × 2 语言。
- **遗留** 模拟器假设玩家永不主动进攻，偏保守；「延迟 4–12f 全 100% 是否偏松」「早按空架 -8 心流是否可学」待人类试玩。

### 文档与工程

- 新建 `CHANGELOG.md`（本文件）；`README.md` 状态节重写（版本、测试数、目录结构、存档机制、已知限制、合规入口）。
- `docs/dev-contract.md` 追加第二至第七轮记录；`docs/gamejam/ai-disclosure.md` 逐轮追加披露行。
- `AGENTS.md` 修正两处过期：§5 删掉未随仓库保留的 `docs/dev-example/README.md`、`docs/agent-prompts/`、`feature-brief-example.md` 引用，改为指向 `CHANGELOG.md` / `balance-pass-*.md` / `development-log.md`；§7 的「外部程序执行受限、需审批」改为实测可直接执行（2026-10-21 复核）。
- 版本号统一为 `0.1.0`：`project.godot` 的 `config/version` 与「关于」页 `VERSION_TEXT`。

### 已知未修

- 7 个 `.tscn` 是空壳，节点树由代码建，`%UniqueName` 未使用（不满足 §8 实质要求，功能不受影响）。
- 字体重复：`assets/MiSans-Semibold.*` 与 `assets/fonts/` 同名同尺寸各一份（约 29 MB），导出有 UID 重复警告。
- `DuelView` 与 `DuelAudio` 无直接测试。
- 未在非开发机 / 不同分辨率验证；未做 10 分钟长跑。
- 44 条玩家可见文案仍为占位。

---

## 0.0.0 — 2026-10-17 ～ 2026-10-20（开发期）

M1–M5 五个阶段的实现记录见 `docs/dev-example/m1-status.md` … `m5-status.md`，战斗数值与机制迭代见 `docs/dev-example/design.md` 的版本表（`v0.1` ～ `v0.29`）与 `docs/dev-example/balance-pass-01.md` … `balance-pass-05.md`。要点：

- 居合判定（前摇 / 判定帧 / 收招 / 硬直 / 无输入惩罚）。
- 心流资源（40–46 起手、100 上限、15 下限、攻击与受击消耗、待机回复）。
- 架刀与完美格挡（架窗按心流档位加宽、完美窗 3–5f、连击加成上限 +9）。
- 8 位角色固定数据、4 张符卡、10 个心得、商店解锁、阶梯 5 场。
- 本地双人、键鼠 + 手柄、GUIDE 上下文输入、SoundManager 音频、I18N、UIManager 面板栈、Codec 存档。
- GUT 从 0 到 169 用例（636 asserts）。
