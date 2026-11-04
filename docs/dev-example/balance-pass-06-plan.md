# 平衡与体验调整方案 06（待人工审核 · 2026-11-04）

> 触发：2026-11-04 人类试玩反馈三条，记录见「playtest-06.md」。
> **本文只是方案，未改动任何游戏代码。** 所有帧数按 60Hz，1f = 16.7ms。
> 证据分级：**[实测]** 读过代码/跑过测试；**[推算]** 按常量推演；**[提议]** 本次新设计，待人类拍板。
> **v3 修订（2026-11-04，人类 m00159）**：符卡从「架势内格挡后自动反斩」改为「自动架刀 45f + 受击自动完美弹开 + 反斩」，见 §3.0。
> **v4 定稿（2026-11-04，人类 m00201 拍板）**：残心只删 HUD 显示；反斩伤害 10；45f 从**按 L 瞬间**起算且防御动画直接到末帧并保持；空放返还部分心流；玩家穿防符卡可穿透、**关底 BOSS 穿防不穿透**（防收割）；中文定稿「发动符卡」。见 §5。

---

## 0. 结论先行

| 项 | 方案 | 优先级 | 工时 | 需人类拍板 |
|---|---|---|---|---|
| 残心显示 | **v5 定稿**：HUD（含结算页）全部不再显示残心，机制保留 | P0 | ~0.5h | 已定 |
| L 键提示 | B1：操作行加符卡位，中文定稿「发动符卡」；B2：教程提示加「符卡可用」（等人类文案，本轮不做） | P0 | B1 0.5h | 英文文案待定 |
| 均衡符卡 | **v4 定稿**：按 L 瞬间进入防御末帧并保持，45f 自动架刀（L 起算）；受击自动完美弹开 + 反斩 10 伤穿防；空放返还 10 心流；玩家穿防可穿透、BOSS 穿防不穿透 | P1 | 3–4h | 剩余 4 项细节见 §5 |

不推荐的路线：只把 spell_a 的 amount 从 60 调到 30、或把 flow_cost 从 30 降到 20。原因是它仍是 0 伤害，**不改变击杀曲线**，问题不是「数值低」而是「没有规则级出口」（详见 §3.1）。

---

## 1. P0-1：删除残心显示

### 1.1 目标

玩家开局第一屏不再出现「残心」这个未解释术语；局间成长机制与所有 test_run_state 断言保持不变。

### 1.2 具体改法（4 步，均不改机制）

1. scripts/duel/duel_hud.gd:354-359：格式串与参数各去掉残心一段：

        _run_info.text = "%s %d/%d  %s %d" % [
            _tr("ui.run"), run.stage_index + 1, RunState.STAGE_COUNT,
            _tr("ui.gold"), run.gold,
        ]

2. localization/zh_CN.json:8、localization/en.json:8：保留 `ui.zanshin` 键（v5 后已无显示路径，但保留键位不删，避免文案清单回流）。
3. 顶部信息行宽度收窄后，_run_info 的 position.x 需按新的居中文本重新计算（:152 当前按固定 x 居中；删两段后建议改为 _run_info.position.x = (1280 - _run_info.size.x) / 2，或保持左对齐）。
4. 结算页**不加**残心行（v5）；同步 tests/integration/test_duel_hud.gd，断言局内与结算页任何 Label 都不含「残心」。

### 1.3 为什么不动机制

- 残心影响 start_flow / flow_floor / 受击心流损失 / 架窗与反斩加值（scripts/run/run_state.gd:157-170），删显示后收益仍会以「开局心流更高、掉得更慢」的形式被玩家感知，不会断链。
- tests/unit/test_run_state.gd 是机制契约，本轮不碰。

### 1.4 结算页（v5 定稿：也删）

- **只删显示，机制保留**；结算页**不再**出现「残心 +N」——人类 `m00653` 明确「结算页也不应该保留」，连局末回看也不给。
- `_result_detail` 整个 Label 删除，不新写文案、不动 `ui.zanshin` 键。
- **[实测]** tests/integration/test_duel_hud.gd 原断言「结算页显示残心 +2」已改为「任何可见 Label 都不含残心」。
- 机制（`run_state.gd` 的残心层数 → 开局心流/下限/受击损失/架窗）完全不变，`test_run_state` 未动。

### 1.5 验证

- 全量 GUT：预期 280/280 不变（无测试断言顶部残心文本）。
- 截图：1280×720 开局 HUD，确认顶部只剩两段、居中不歪。
- 手测：跑完一场，确认心流/受击数值与改动前一致（机制未动）。

### 1.6 风险

- 低。唯一的坑是 §1.4 选 B 时的测试断言与布局重排。

---

## 2. P0-2：L 键开符卡提示

### 2.1 目标

玩家在 HUD 上能直接看到「符卡键 = L」（改键后自动跟随），并且在教程提示里至少被提示一次「符卡可用」。

### 2.2 B1：底部操作行（推荐先做，0.5h）

1. duel_hud.gd:266-281 的 _controls_text()：在现有 %p 之后追加两次替换：

        text = text.replace("%s", KeyBindings.label(meta, &"spell_p1"))
        text = text.replace("%S", KeyBindings.label(meta, &"spell_p2"))

   %s / %S 大小写敏感，先替换 %S 也可以，互不干扰（%a 等不存在同前缀冲突）。
2. localization/zh_CN.json:9-11 三条文本加符卡位。**中文已定稿「发动符卡」**（人类 m00201）；英文待人类提供：
   - controls：「J 斩 / K 架 / L 发动符卡 / R 重开 / Esc 暂停 / 1–3 选心得」
   - controls_template：「P1 %a 斩 / %g 架 / %s 发动符卡　%r 重开　%p 暂停　1–3 选心得」
   - controls_versus_template：「P1 %a 斩 / %g 架 / %s 发动符卡　P2 %d 斩 / %f 架 / %S 发动符卡　%r 重开　%p 暂停」
3. localization/en.json:9-11 同步三条。

> 注意：ui.controls 是「无设备元数据」时的回退串，键盘默认值写死在文案里；模板串才走 KeyBindings.label()。两条都要改，否则手柄/键盘两种路径显示不一致。

### 2.3 B2：教程提示加「符卡可用」（1h，需人类文案）

> **v4 拍板：文案等人类提供，本轮不做**，保留触发点设计供后续接入。

现状 _tutorial_text()（duel_hud.gd:468-479）的优先级是：

    开局窗 → 对手 COMMIT（警告）→ 对手 RECOVERY/GUARD_REC（惩罚窗）→ P1 心流 ≤20 → 默认

建议插入位置：**默认之前、心流告警之后**，即「没有紧急警告、符卡还能用、玩家还没按过」时提示一次。

    # 伪代码
    if not _spell_used and p1.uses_left > 0 and p1.flow >= spell_cost and not opponent_busy:
        return "tutorial.spell"

- 只在第 1 场显示（run.stage_index == 0），避免整局唠叨。
- 新增文案键 tutorial.spell，值写 [占位]（人类撰写）；zh/en 两侧同步，test_i18n 的键集合校验会覆盖。
- 需要在 HUD 侧知道「本局是否按过符卡」：duel_sim 已有 spell_cast 信号与 uses_left，监听一次即可，不必新加状态。

### 2.4 可选：设置页符卡改键行

scripts/ui/settings.gd 目前只列攻击/格挡/暂停/重开（zh_CN.json:77-82）。KeyBindings 的读写/冲突检测**已支持** spell_p1 / spell_p2，加两行是纯 UI 工作（约 0.5h），但需要两条新文案。**本轮不建议做**：截止前优先保证可玩性与导出。

### 2.5 验证

- 定向：tests/integration/test_duel_hud.gd 加一例——默认键下操作行含 L（用 KeyBindings.DEFAULT_KEYS 断言，不硬编码字符串）；改键后（settings.keyboard.spell_p1 = KEY_H）操作行含 H。
- 全量 GUT、--import 退出码 0。
- 截图：键盘 HUD、手柄 HUD 各一张。

### 2.6 风险

- B1 风险极低，唯一坑是两条回退串都要改。
- B2 的坑是**提示优先级**：若放在对手出刀警告之前，会在最危险的帧刷出无效提示，反而干扰。

---

## 3. P1：均衡符卡重设计（v4 定稿：瞬发架刀 · 反斩）

### 3.0 修订记录

- **v2（初稿）**：60f 必完美，架势内首次格挡成功后自动反斩 10 伤穿防。
- **v3（2026-11-04，m00159）**：改为自动架刀 45f，受击自动完美弹开 + 反斩。
- **v4（2026-11-04，m00201 拍板定稿）**：反斩伤害 10；45f 从**按 L 瞬间**起算；按 L 立即把防御动画播到**最后一帧并保持**；窗口空放**返还部分心流**；玩家穿防符卡无视自动架刀，**关底 BOSS 穿防符文卡不无视**（防止「防收割」）；中文定稿「发动符卡」，教程提示与英文文案等人类提供。

### 3.1 问题量化（为什么必须重设计，而不是调数值）

**[实测]** 旧 spell_a：30 心流（开局净耗 25）、10f 蓄力、60f 必完美、0 伤害、1 次。

| 维度 | 旧设计 | 结论 |
|---|---|---|
| 击杀曲线 | 对 30HP 仍需 3 刀，符卡不减少刀数 | 不改变对局长度 |
| 资源经济 | 净收益上限 = 一次完美格挡的 +5 心流差；成本 25 心流 | 负收益（要 5 次完美才回本，60f 内最多 2 次架） |
| 防守增量 | 架窗 24–32f → 抬到 30f，CALM 档无提升 | 几乎为 0 |
| 反击入口 | 普通格挡同样给 30f counter_until_frame 顺势斩 | 符卡没有新增选项 |
| 风险 | 架势期间被砍中 → 驱散 + 12f 惩罚硬直 + hitstun | 比不开符卡更怕挨刀 |

> 一句话：旧设计**不改变击杀曲线、不改善资源、不新增防守选项，只增加被打断的代价**。

### 3.2 设计约束

- design.md §6.11：收益必须「规则级」，风险必须「明牌可读」；开局必须发得出。
- A 的定位是「均衡 / 守」：伤害低于 B、C，但必须有可兑现的进攻出口。
- 与 B/C/关底同构：都是「蓄力 → 落刀 → 穿防」。A 的差异只能是「触发条件不同」。
- 教学角色优先：操作越少越好。v4 下 A 的操作 = 按 L，全程零额外输入；且**没有前摇**，按下去立即有防御姿态的视觉反馈。
- v4 新增：**不能出现「开了防御符卡反而被 BOSS 穿防收割」**的局面（人类原话：防收割导致过难）。

### 3.3 方案演进

| 方案 | 做法 | 触发 | 判定 |
|---|---|---|---|
| S0 | 只调 amount / flow_cost | 无 | 否，仍是 0 伤害 |
| S1 | 格挡后 20f 内手动按斩反斩 | 需先架住 | 可选，但对新手是两段操作 |
| S2（v2） | 架势内首次格挡后自动反斩 | 需先架住 | 已被取代 |
| S2'（v3） | 自动架刀 45f，受击自动弹开 + 反斩 | 按 L | 已被 v4 细化 |
| **S2''（v4）** | **按 L 瞬间进入防御末帧并保持；45f 自动架刀；受击自动完美弹开 + 反斩 10 伤穿防；空放返还心流；BOSS 穿防不穿透** | 按 L | **人类拍板，定稿** |
| S3 | 45f 结束时无条件落刀 | 按 L | 备选，缺少防守联动 |

### 3.4 定稿规格：S2''「瞬发架刀 · 反斩」

**时序**

    L 按下（0f）
    ├─ 立即：进入 SPELL 状态，防御动画直接定位到最后一帧并停住
    ├─ 45f 自动架刀窗口（L 起算）
    │   ├─ 对手斩中 → 自动完美弹开 → 立即反斩 10 伤穿防 → 窗口结束
    │   ├─ 玩家按攻击 → 清窗口，转普通出刀（消耗不返还）
    │   └─ 45f 到 → 窗口失效，返还部分心流，回到 IDLE
    └─ 窗口外受击 → 正常掉血

**规则（v4 定稿）**

1. **无前摇**：按 L 的同一帧进入 SPELL；视觉上立即把防御动画（fangyu）定位到最后一帧并保持，整个 45f 内不动、不循环。实现上不再有原 10f 蓄力。
2. **窗口 45f 从 L 按下帧起算**：spell_auto_guard_until_frame = cast_frame + 45。
3. **窗口内受击**（自身不在出刀/受击/CLASH）：不扣血、不进 hitstun，按完美格挡结算——防守方 +12 心流（可被 perfect_gain 心得改）与连击加成、攻击方 -8 心流并进 blocked_recovery 28f。
4. **自动反斩**：弹开后立即反斩 **10** 伤穿防（spell_power_amount = 10、spell_unblockable = true），窗口立即结束；每场最多兑现一次。
5. **窗口内按攻击**：清窗口、转普通出刀；消耗不返还。
6. **窗口内按架**：照常进入普通架，不影响窗口。
7. **空放返还**：45f 内无人出刀 → 在窗口到期帧返还部分心流（默认 **10**，见 §5），回到 IDLE。
8. **穿防规则（v4）**：
   - 玩家之间：B/C 的穿防符卡**无视**对手的自动架刀（穿防语义优先）。
   - 关底 BOSS：其穿防符卡**不**无视玩家的自动架刀——看见玩家开盾就穿防会形成「防收割」，对 A 玩家过难。
   - 实现口径：拦截条件 = 窗口有效 and defender.state != SPELL and (not attacker.spell_unblockable or attacker.is_boss)。

**边界**

- clash 优先。
- BOSS 符卡被自动架刀拦截：**推荐按普通完美弹开 + 不触发反斩**（不让玩家用一个 A 白嫖 BOSS 终式 10 伤），伤害归零、攻方进收招。列为 §5 待确认；若选「弹开 + 反斩」，需重点看 BOSS 战强度。
- 见切（U06）是否抵消反斩：推荐可以。

**字段**

- SpellCardData：新增 auto_guard_frames = 45、counter_damage = 10、empty_refund_flow = 10；GUARD_STANCE 不再使用 amount / cast_frames。
- FighterState：新增 spell_auto_guard_until_frame = -1、spell_refund_pending = 0。

### 3.5 数值与对局影响

| 项 | 旧 spell_a | v4 定稿 | B | C | Boss |
|---|---|---|---|---|---|
| 直接伤害 | 0 | 10（穿防，受击触发） | 20 | 30 | 30 |
| 对 30HP 占比 | 0% | 33% | 67% | 100% | 100% |
| 心流成本（面板 / 开局净耗） | 30 / 25 | 30 / 25；空放返还 10 → 净 15 | 35 / 31 | 34 / 21 | 40 / 25 |
| 前摇 | 10f 蓄力 | **0f（瞬发）** | 8f | 20f | 14f |
| 窗口 | 60f 必完美（需按架） | 45f 自动架刀（L 起算） | — | — | — |
| 空放退款 | 无 | 10 心流 | 无 | 无 | 无 |

**相对 v3 的强度变化**：去掉 10f 蓄力 → 少一个被抢的窗口；空放退 10 → 实际成本从 25 降到 15；BOSS 不再穿防 → A 对关底有稳定价值。代价是每场仍只兑现一次，45f 内 AI 不出刀就只是「买 15 心流保险」。

**风险**：A 可能成为「对 BOSS 的最优解」。调参阶梯见 §3.8。

### 3.6 实现落点清单（本轮不改，仅列点）

| 文件 | 改动 |
|---|---|
| scripts/duel/spell_card.gd | 新增 @export var auto_guard_frames: int = 45、counter_damage: int = 10、empty_refund_flow: int = 10；_guard_stance() 改写为瞬发设置 |
| scripts/duel/fighter_state.gd | 新增 spell_auto_guard_until_frame: int = -1、spell_refund_pending: int = 0 |
| scripts/duel/duel_sim.gd | _cast_spell 的 GUARD_STANCE 分支改为瞬发（不置蓄力帧，直接设窗口与返还）；_apply_action 顶部处理按攻击打断；_resolve_slash 在 clash 后、match 前拦截（含 BOSS 例外）；_do_block 加 forced_perfect；新增 _trigger_spell_counter()、_expire_spell_window()；_clear_spell_charge 清窗口与返还 |
| scripts/duel/spine_fighter_profile.gd + resources/spine/*.tres（8 份） | animation_map 增 "SPELL": "fangyu"（现状 SPELL 无映射 → 回退 zhanli，观感不对） |
| scripts/duel/spine_fighter_view.gd | 新增「定位到动画末帧并暂停」能力：set_animation(anim, false) → track.set_time(duration) → set_time_scale(0)；由视图在 SPELL 状态调用 |
| tests/unit/test_spell_cards.gd | 改写 1 例、新增 5 例（见 §3.7） |
| tests/integration/test_duel_hud.gd | 局内与结算页都不出现残心（可见 Label 扫描） |
| docs/dev-example/design.md §6.11 | 符卡表更新 |
| docs/dev-example/balance-pass-06.md（新） | 落地后写 sim 数据 |

**关键实现细节**：

- _resolve_slash 拦截点：clash 之后、match defender.state 之前；条件见 §3.4 规则 8。
- BOSS 判定不要硬编码「对手是 BOSS」，优先复用 FighterData/档案里已有的 boss 标识；实现前先查。
- 「防御动画末帧」只在进入 SPELL 的那一帧设一次；窗口到期、反斩、按攻击打断时恢复正常播放。
- 空放返还只在窗口**自然到期**时执行；被反斩兑现、按攻击取消、按架打断都不返还。
- _clear_spell_charge 现状把 SPELL 视为「蓄力中」；改为：只有 B/C 的蓄力算蓄力，A 的窗口不算。

### 3.7 测试计划（GUT）

1. **新增** test_spell_a_instant_guard_pose：按 L 当帧 state == SPELL、窗口 = 45；Spine 视图 current_animation == "fangyu" 且 time_scale == 0（末帧保持）。
2. **新增** test_spell_a_auto_guards_on_hit：窗口内 P2 出刀 → P1 HP 不变、P2 HP 30→20、P1 反斩中、P2 处于 blocked_recovery、窗口结束。
3. **新增** test_spell_a_window_expires_and_refunds：45f 后无人出刀 → state 回 IDLE、心流 +10。
4. **新增** test_spell_a_attack_cancels_window：窗口内按攻击 → 窗口清空、不返还；随后 P2 出刀命中 P1。
5. **新增** test_spell_a_boss_unblockable_is_guarded：关底穿防符卡在窗口内 → 被拦截，P1 不掉血。
6. **新增** test_spell_a_player_unblockable_pierces：P1 窗口内 P2 放 B 符卡 → P1 掉血（玩家穿防仍穿透）。
7. **改写** test_hit_interrupts_spell_charge_with_penalty：A 已无蓄力期，改为验证 B 的蓄力打断仍吃 12f。
8. 回归：test_spell_b / test_spell_c / test_duel_hud / 视图测试全绿。
9. 全量：预期 280 → 约 286。

### 3.8 监测与回滚

- tools/sim_balance：A vs 5 个对手各 100 局，记录胜率、符卡触发率（期望 > 60%）、因 A 符卡少吃的刀数。
- 回滚：SPELL_AUTO_GUARD_ENABLED 常量开关；关闭后 GUARD_STANCE 回退为旧「60f 必完美、0 伤害」。
- 阶梯：counter_damage 10→8；empty_refund_flow 10→0；BOSS 符卡是否允许反斩（§5）。

### 3.9 待确认（v4 后仅剩 4 项细节）

1. **空放返还数值**：10（推荐）/ 15 / 成本的一半。
2. **BOSS 符卡被拦截时是否反斩**：推荐不反斩（只弹开、伤害归零），避免白嫖终式。
3. **见切是否抵消反斩**：推荐可以（保持心得一致）。
4. **结算页残心**：v5 定稿——也删（人类 `m00653`）。

---

## 4. 排期（截止 2026-11-07 10:00，建议 09:40 前提交）

| 时间 | 事项 | 负责人 |
|---|---|---|
| 11-05 上午 | P0-1 残心显示（0.5h）+ P0-2 B1 操作行（0.5h） | 开发 |
| 11-05 上午 | 人类定稿：操作行文案、教程符卡提示文案 | 人类 |
| 11-05 下午 | P1 S2'' 瞬发架刀实现 + 1 改写 5 新增 GUT（3–4h） | 开发 |
| 11-05 晚 | sim_balance 抽样 + 人类试玩 A 符卡 | 人类/开发 |
| 11-06 上午 | B2 教程触发（若文案到位）+ 全量 GUT | 开发 |
| 11-06 下午 | 多分辨率/非开发机验证、导出、截图 | 开发 |
| 11-06 18:00 | **功能冻结** | — |
| 11-07 09:40 | 提交 | 人类 |

> 若时间不足，砍 B2 与 §2.4 设置页改键，保 P0-1、P0-2 B1、P1 S2''。

---

## 5. 拍板结果（v4 定稿）与剩余细节

> **v5 修订（2026-11-04，人类 `m00653`）**：结算页也删除「残心 +N」，全 HUD 不再显示残心；底部「剩余细节 4」相应作废。其余拍板不变。

**已定（2026-11-04，人类 m00201）**：

1. **残心**：显示全删（顶部 HUD 与结算页都不出现），机制保留。`m00201` 原定「结算页保留 +1」，`m00653` 改为也删。
2. **L 键操作行**：中文定稿「发动符卡」；英文文案待人类。
3. **教程符卡提示**：等人类文案，本轮不做。
4. **反斩伤害**：10。
5. **45f 起算点**：按 L 瞬间起算；防御动画直接到末帧并保持。
6. **空放**：返还部分心流。
7. **穿防**：玩家 B/C 符卡无视自动架刀；关底 BOSS 穿防符卡不穿透自动架刀。

**剩余细节（落代码时可直接取默认值，不等回复）**：

1. 空放返还数值：默认 10 心流。
2. BOSS 符卡被拦截时是否反斩：默认不反斩。
3. 见切是否抵消反斩：默认可以。
4. 结算页残心：不显示（`m00653` 已定）。

---

## 6. 验收清单

- [ ] 顶部 HUD 与结算页都不再出现「残心」；
- [ ] 键盘/手柄 HUD 都能看到符卡键，中文「发动符卡」，改键后跟随；
- [ ] 按 L 当帧进入防御末帧并保持，45f 从按下帧起算；
- [ ] 窗口内受击自动完美弹开并反斩 10 伤穿防，攻方进 blocked_recovery，自己不掉血、不进 hitstun；
- [ ] 玩家 B/C 符卡可穿透该窗口；关底 BOSS 符卡不会穿透；
- [ ] 窗口内按攻击可打断；45f 空放返还 10 心流；
- [ ] 窗口过期后受击正常掉血；每场只兑现一次；
- [ ] 全量 GUT 全绿、--import 退出码 0、1280×720 与至少一种非开发分辨率目视通过；
- [ ] CHANGELOG.md / docs/dev-example/balance-pass-06.md / ai-disclosure.md 已更新。

---

## 附 A：本方案引用的关键常量

| 常量 | 值 | 位置 |
|---|---|---|
| PERFECT_BLOCK_FLOW_GAIN | 12 | duel_sim.gd:31 |
| BLOCK_FLOW_GAIN | 7 | duel_sim.gd:30 |
| PERFECT_BLOCK_WINDOW | 3 | duel_sim.gd:32 |
| PERFECT_STREAK_BONUS / CAP | 3 / 9 | duel_sim.gd:33-34 |
| GUARD_COUNTER_WINDOW | 30 | duel_sim.gd:36 |
| GUARD_COUNTER_COMMIT_BONUS | -6 | duel_sim.gd:37 |
| SPELL_STANCE_GUARD_FRAMES | 30 | duel_sim.gd:53 |
| SPELL_INTERRUPT_PENALTY | 12 | duel_sim.gd:55 |
| A 架窗（base + 档位） | 24 / 28 / 32 | fighter_data.gd + duel_types.gd:41-49 |
| 开局心流 A/B/C | 40 / 46 / 36，下限 15 | fighter_data.gd |
| SPELL_AUTO_GUARD_FRAMES / COUNTER_DAMAGE / EMPTY_REFUND_FLOW | 45 / 10 / 10 | spell_card.gd（新增） |
| 自动架刀窗口起算 | 按 L 按下帧（0f 前摇） | duel_sim.gd（v4 定稿） |

---

## 7. 实现落地记录（2026-11-04）

代码已按 §3 落地。以下为与方案文本的差异与取舍，均已在代码注释或本节留痕：

1. **窗口状态口径**：§3.2 原写「`defender.state != SPELL`」，与「45f 内保持 `SPELL`」自相矛盾。实现取 `defender.state == SPELL and _spell_window_active(defender)`——A 的窗口就是 `SPELL` 状态本身，`spell_auto_guard_until_frame` 只用于计剩余帧与到期判定。
2. **窗口内按架**：`_apply_action` 的 `SPELL` 分支改为忽略 `GUARD`，保持自动姿态，避免玩家误按架把自动架刀顶掉。
3. **窗口内按斩**：`_apply_action` 顶部先 `_end_spell_window(fighter, false)` 再 `_enter_commit(fighter)`——放弃保险、不退心流。
4. **弹开后清架势**：`_do_spell_auto_guard` 在 `_do_block(..., true)` 后把 `counter_until_frame = -1`，防止「反斩后还能按架再完美格挡」叠加；随后立即 `_trigger_spell_counter`。
5. **关底例外**：`_is_boss_fighter()` 判 `data.spell_id == &"spell_boss"`；BOSS 穿防被弹开时只 `_end_spell_window(false)`，不反斩。
6. **HUD 显示**：窗口期符卡行改为 `名称 ×1 ▶剩余帧`（紫），比 §3.4 多一个窗口态；具体文案仍是 `[占位]`。
7. **Spine**：8 份档案补 `SPELL→fangyu`；窗口内 `set_track_time(动画时长)` + `time_scale = 0`，窗口结束按剩余帧重定时回待机。
8. **测试**：289/289、1111 asserts、35 脚本、退出码 0；新增/改写用例见 `test_spell_cards.gd`、`test_duel_hud.gd`、`test_spine_fighter_view.gd`。
9. **v5 追加（`m00653`）**：删除结算页 `_result_detail`「残心 +N」；`test_duel_hud.gd` 改为扫描 HUD 全部可见 Label，局内与结算页都不含「残心」，并断言 `run.zanshin` 仍记数。

未做：人类文案替换（`tutorial.spell`、`spell_a.desc`、英文三条 controls）、非 16:9 分辨率目视验证、实机手感确认。

