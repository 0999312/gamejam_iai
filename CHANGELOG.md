# 变更记录（CHANGELOG）

本文件记录**已交付的变更**，按版本倒序。开发期的中间迭代号（`v0.20`–`v0.29`）只出现在 `docs/dev-example/design.md` 的历史行与阶段状态文档里，不再作为发布版本号使用；自本条起使用语义化版本。

格式：`版本 / 日期`，下分「修复」「机制」「文档」三组。每条给出**问题 → 修法 → 验证**，不写「优化了体验」这类无法核对的话。

---

## 未发布 — 2026-10-23

素材入库、粒子接线与刀光/符卡爆环批次：把第三方粒子素材包筛成可用的 36 张贴图，接入命中 / 对刀 / 架防三类战斗事件，再用 `twirl_03` 与 `circle_02` 替换自绘的挥砍弧与符卡爆环，同时把临时素材暂存区从 Godot 的扫描范围与版本控制里摘出去。

### 修复

- **问题** 临时素材包放在工程内会被 Godot 全量扫描导入：`temp_assets/` 有 195 个文件 / 15.2 MB，其中 160 张 512×512 PNG 会被逐个生成 `.ctex`，拖慢首次导入、污染 `.godot/imported`，还会让该目录出现在 FileSystem 面板与导出候选里。
  → **修法** 新增 `temp_assets/.gdignore`（Godot 见到该文件即整目录跳过，不导入、列不出、不导出）；`.gitignore` 追加 `/temp_assets/` 并写明用途。
  → **验证** 重新导入后 `temp_assets/` 内 `*.import` / `*.uid` 均为 0；80 张里**未被选中的 25 个代表文件**（`flame_01`、`muzzle_01`、`window_01`、`symbol_01`、`scratch_01`、`smoke_01`、`dirt_02`、`circle_01`、`star_01`、`spark_03`、`scorch_02`、`trace_01`、`magic_04` 等）在 `.godot/imported/` 中查无对应 `.ctex`，即该目录确实从未被扫描。

### 机制

- **素材入库** 从 Kenney Particle Pack 1.1（CC0 1.0）的 `PNG (Transparent)` 80 张里挑 36 张，按用途放 `assets/particles/{slash,impact,guard,spell,dust,glow}/`（7/10/3/6/7/3）。文件名保留 Kenney 原名、像素未改（纯白 + alpha），运行时用现有调色板上色：`COLOR_P1/P2`、`COLOR_FLOW_LOW/MID/HIGH`、`COLOR_SPELL_P1/P2`——**不为粒子新增颜色**。
  → **验证** 36 张 `.png.import` 与对应 `.ctex` 全部生成；`assets/particles/CREDITS.md` 记录来源包、许可原文要点、未取用子集（黑底版 / Rotated / Unity samples）。
- **粒子接线（第一批）** 新增 `scripts/duel/duel_fx.gd` + `scenes/duel/duel_fx.tscn`：`GPUParticles2D` one-shot 固定池（4 类 × 3 个，只 `restart()` 复用，不在战斗帧新建节点），`DuelView` 在 `_ready()` 装配、在 `hit_landed` / `clash_happened` / `attack_blocked` 三处点火。染色走人类拍板的「攻击方制」：命中=出刀方色、架住=防守方色、对刀=暖白 `#fff3c4`、完美格挡=心流青 `#9ff0d0`（全部取自 `duel_view.gd` 既有调色板）。尺寸按设计像素：命中 110 / 对刀 140 / 架住 170 / 完美 220（对刀与架住按首轮截图从 190/150 收回，避免叠加成一团白）。36 张 `.png.import` 全部开 mipmaps，节点配 `Linear Mipmap` 过滤以消除缩小闪烁；暂停时 `speed_scale = 0` 冻结、`bind()` 换局 `clear_all()`、预留 0–1 强度接口；全屏暖闪 alpha 0.55 → 0.28 降为辅助。
  → **验证** GUT **212/212（811 asserts，退出码 0）**，新增 `tests/unit/test_duel_fx.gd`（10 例）与 `tests/integration/test_duel_view_fx.gd`（7 例：信号→贴图、换局清空、暂停透传）；`tools/capture_fx_preview.gd` 出图 `docs/dev-example/duel-fx-preview.png`（1280×720，四类特效并排）；headless 240 帧冒烟无错误。
- **刀光与符卡爆环（第二批）** `duel_view.gd` 里 `draw_arc(122, ±51.5°)` 的白色挥砍弧换成 `slash/twirl_03` 贴图，`_draw_spell_burst()` 的两道自绘扩散环换成 `guard/circle_02` 紫色 `#b79bff`。
  → **问题** 贴图不是可缩放的整环：`twirl_03` 的亮带在半径 175–231 / 512、张角 -80°…+28°（中心 -26°），直接 `Sprite2D` 摆上去既对不上 122 半径，也朝错方向。
  → **修法** 用实测量化对位——缩放 `122/203 ≈ 0.60` 让亮带压在旧弧上，旋转 `+26°`（P2 再 +180°）把带中心转到出刀方向，弧心复用 `_draw_fighter()` 的 lean/crouch；挥砍是持续 4–6 帧的连续态，因此每帧调 `pose_slash()` 摆位而不是发一次性粒子，旋转随进度前扫 17°、alpha 按 `0.85×(1-p²×0.85)` 淡出。符卡环按 `circle_02` 外缘 172 / 512 缩放，内外两枚由 36 推到 366、0.62s、ease-out，被打断乘 0.6。
  → **验证** GUT **224/224（847 asserts，退出码 0）**（`test_duel_fx.gd` 18 例、`test_duel_view_fx.gd` 11 例，含刀光朝向/缩放/淡出与紫环扩张/寿命）；新截图 `docs/dev-example/duel-fx-slash.png`；`duel_sim.gd` / `fighter_data.gd` 零改动，判定层不受影响；headless 240 帧冒烟无错误。
- **第三批（人类三点反馈）** ① 符卡爆环看起来像 `circle_03`——核实贴图确实是 `circle_02`（MD5 与源包一致），真因是**内外两枚 0.72 倍叠加**被读成厚环，改为**单枚**；② 刀光要「扇形随挥刀方向消失」——新增 `resources/shaders/slash_sweep.gdshader`，刀锋角 `head` 由 -83° 扫到 +29°，扫过的角度在片元里抹掉，`modulate.a = 0.9×(1-0.35p²)` 只管整体衰减；③ 攻击前摇要有圆形特效件，且是**替换**自绘收束弧而不是叠加——`_draw_fighter()` 里两道 `draw_arc` 整段删除，改由 `DuelFx.pose_charge()` 摆一枚 `spell/light_03`（`CHARGE_TEX_RADIUS = 208`），半径 20 → 132 由小长大、`#fffdf7` → `#ffc94a` 由白转亮金、alpha 0.32 → 0.82，圆心取 `_draw_aura()` 的 `(x, GROUND_Y - 90)` 与心流圆环同心（不吃 COMMIT 前倾/下蹲）；临刀只让金色 alpha 呼吸，不掺白（掺白会洗成米色）。
  → **问题** 初版 shader 的 `tail_span` 取 1.35 rad（77°），比月牙总张角 108° 还宽 ⇒ 永不塌陷，肉眼只见整体变淡；蓄力环初版用「收紧」与去饱和的金，观感偏暗且与心流环不同心（圆心偏 14px、低 16px）。
  → **验证** GUT **229/229（871 asserts，退出码 0）**（新增刀光 shader 进度/前扫断言、单枚爆环 ≠ null、蓄力环同心且随进度变大变亮）；四格连拍 `docs/dev-example/duel-fx-sweep.png` 证明 0% 全弧 → 35% 上端消失 → 70% 半截 → 100% 收尾；新增 `docs/dev-example/duel-fx-charge.png`；headless 240 帧冒烟无错误。

### 文档

- 新增 `docs/particle-assets-plan.md`：边界（AI 不生成美术）、目录约定、贴图规格、**游戏事件 → 贴图对照表**（出刀/连斩/命中/对刀/被架/完美格挡/空架/符卡蓄力/发动/打断/落地/收刀/心流氛围）、导入设置建议、接入方案、44 张未选贴图的理由。
- `docs/particle-assets-plan.md` §6 改写为「已接入（第一、二批）」+ §6.5「刀光与符卡爆环」记录对位数学（半径/朝向/弧心三列）与取舍，§5 尺寸表标注定稿值，§8 补 8.1/8.2 两轮验证；`docs/dev-example/development-log.md` 新增 §9（粒子接线）与 §10（刀光/爆环）记录口径与踩坑；新增 `docs/dev-example/duel-fx-preview.png` 与 `duel-fx-slash.png` 两张验收截图（非游戏资源）。
- `AGENTS.md` §4 补 `assets/particles/` 与 `temp_assets/` 两条约定；`assets/particles/CREDITS.md` 新增；`docs/gamejam/ai-disclosure.md` §4 追加一行、§6 补素材来源行；`docs/gamejam/submission-checklist.md` 补粒子贴图许可勾选项。
- 本次 **美术仍为 0% AI**：贴图是第三方 CC0 素材，AI 只做筛选、复制归档与写文档，未绘制、未改像素。

### 已知未修

- 战斗事件已接：命中 / 对刀 / 架防三类粒子，外加挥砍刀光（`twirl_03` + `slash_sweep.gdshader`）、符卡爆环（单枚 `circle_02` 紫）、起构蓄力环（`light_03`，已替掉自绘收束弧）；**未接**：符卡蓄力法阵与光柱、落地扬尘、空架、收刀、心流氛围，贴图已备在 `assets/particles/` 对应子目录，映射见 `docs/particle-assets-plan.md` §5。
- 判定类提示中，**预警收束弧已由蓄力环接管**；架窗环、血条仍走 `draw_*`，**不交给粒子**：人手要读的是几何形状，不是光效。连斩第 2 段起换 `twirl_01/02` 也未做。
- `DuelFx.set_strength()` 只有接口，尚未进设置页（0 = 完全关闭）。
- 贴图的 mipmaps 已开启并配对 `Linear Mipmap` 过滤；若后续在低分辨率窗口下仍见闪烁，优先怀疑 `ParticleProcessMaterial` 的 scale 曲线而不是导入设置。

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
