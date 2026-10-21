# 平衡调整记录 02（2026-10-21）

> 触发：第三方试玩反馈 5 条（反应窗口不足 / 节奏偏快 / 角色不平衡 / 需要多角色基础 / 开局待机不该涨心流）。
> 方案经人类审核，按批复（`m00251`）实施：前摇用 v2、架窗差异化、反斩作为增强、快剑不加血、HP 改血条、路径 A 与连斩惩罚同时上、多角色代码基础现在就打好。
> 方案原文见 `docs/dev-example/balance-pass-02-plan.md`；本文记录**实际落地的数值、机制与验证**。数值集中在 `FighterData` / `AiProfile` / `DuelSim`，本文只做索引。

## 1. 时间基准（60Hz 整数帧，1f ≈ 16.7ms）

**可挡区间 = `[T−G+1, T−2]`**，T = 对手前摇（commit_total），G = 我方架窗时长。上限只由 T 决定，架窗 G 只决定「按早了会不会空架」与区间宽度。那 2f 是 1f 输入延迟 + 1f `guard_startup`。

| 角色 | 前摇 T | 架窗 G（CALM / 无档位时） | 可挡上界 | 玩家侧说明 |
|---|---|---|---|---|
| 均衡 char_a | 18f (300ms) | 20f (CALM 24f) | 16f (267ms) | 标准节奏 |
| 快剑 char_b | 15f (250ms) | 18f (CALM 22f) | 13f (217ms) | 快，但被架惩罚最短 (24f) |
| 重剑 char_c | 21f (350ms) | 22f (CALM 26f) | 19f (317ms) | 慢，但一刀 15 伤 |

| 对手 | 前摇 T | 可挡上界 (T−2) |
|---|---|---|
| 1 教学 | 30f | 28f = 467ms |
| 2 急性 | 28f | 26f = 433ms |
| 3 老练 | 29f | 27f = 450ms |
| 4 虚实 | 28f | 26f = 433ms |
| 5 关底 | 28f | 26f = 433ms |

**结论**：识别 200–250ms + 判断 50–100ms + 按键生效 33–50ms ≈ 300–400ms，全部落在 433–467ms 以内；「0.3s 才按」不再必吃刀。
架窗下界随角色不同（50–117ms），心流只影响下界（`GUARD_TIER_OFFSET`），**上界与心流档位无关**——心流低不再等于「反正防不住」。

## 2. 角色数值（HP ×10，伤害微调）

| 角色 | HP | 伤害 | 前摇 | 架窗 | 空挥 | 被架 | 受击 | 心流消耗 | 连斩惩罚 | 起始心流 |
|---|---|---|---|---|---|---|---|---|---|---|
| char_a 均衡 | 30 | 10 | 18f | 20f | 20f | 32f | 24f | 4 | +8f | 40 |
| char_b 快剑 | 30 | 7 | 15f | 18f | 16f | 24f | 24f | 4 | +4f | 46 |
| char_c 重剑 | 40 | 15 | 21f | 22f | 24f | 36f | 36f（破势 +12） | 5 | +10f | 36 |

- 快剑按批复**不加强生命**，补偿放在「最短前摇 / 最短被架硬直 / 最高自然恢复 (22f) / 最低连斩惩罚 (4f)」。
- 符卡数值同步 ×10：A 架势不变（60f 安全区），B 疾风连斩 20 伤，C 崩山 30 伤，关底 30 伤。
- 心得 U07 追击改为 `PURSUIT_BONUS_DAMAGE = 10`（原 +1）。

## 3. 五个对手 = 五个角色（多角色代码基础）

- `FighterData.ALL_IDS` 八人：`char_a/b/c` + `opponent_1_teaching` … `opponent_5_boss`；每个都有 `persona_id`。
- `stage_enemy_id(stage)` 是**唯一**的「场次 → 角色」绑定表；`opponent_for_stage()` 只是它的委托。
- `AiProfile.for_persona(persona_id, tier)` 以性格索引，`for_stage()` 走 `persona_id`，**不再有按场次硬编码的分支**。
- `RunState.roster()` / `select_character()` 按解锁状态给出可选角色；`build_match()` 产出 `MatchSetup`（p1/p2 数据 + AI profile + 场次 + 难度档），`swapped()` 可互换视角。
- 后续「收服敌人当可操作角色」只需把对手的 id 加进 `roster()`，数据与 AI 已解耦。

## 4. 机制改动

| 机制 | 规则 | 目的 |
|---|---|---|
| 反斩 | 对手处于空挥/被架硬直时出刀，前摇 `riposte_commit_bonus`（对手 -10f，玩家 `-4 - 2×残心`，最多 -10f） | 让「被架」真的会挨刀，成为玩家的高风险高回报选择 |
| 连斩惩罚 | 距上一次出刀 ≤ `REPEAT_WINDOW_FRAMES`(60f) 时，每次 +`repeat_commit_penalty`（8f），最多叠 2 层 | 连点攻击的边际收益递减；快剑惩罚最低 |
| 确定反 | AI 在每个硬直窗口只掷一次 `counter_chance`，命中就立刻出刀，**不受决策节拍限制** | 修复「惩罚刀永远来不及落下」，让无脑连砍付代价 |
| 起构安全 | AI 在对手 COMMIT/SLASH/CLASH/GUARD 时不落构；对手待机满 120f 才允许主动开口 | 长前摇（467–500ms）不能当明牌白送 |
| 礼让心流 | `_passive_flow` 增加 `frame >= opening_lock_frames` 门；礼让期内不自然恢复、不计「无输入惩罚」 | 反馈 5：开局 3 秒站着不动不再白涨心流 |
| 难度双档 | NORMAL：aggression×0.8、decision −4f、post_hit −20f、guard +0.15、counter = 1.0；HARD：旧数值 + 旧帧数表（`HARD_COMMIT` / `HARD_GUARD`） | 反馈 2：把原节奏当困难模式 |
| HP 血条 | `duel_view._draw_hp_pips` 改为连续血条（150×8，每 10 血一道刻度） | 反馈 3 的显示要求，30–40 血不再溢出视口 |

## 5. 验证

### GUT

`159/159` tests，`556` asserts，headless 全绿（`-gdir=res://tests -ginclude_subdirs -gexit`）。

新增/重写的关键回归：
- `test_opening_lock_grants_no_flow`：礼让期内心流不涨，结束后正常恢复。
- `test_riposte_shortens_commit_in_foe_recovery` / `test_commit_without_riposte_keeps_full_startup`：反斩只在硬直窗口生效。
- `test_repeat_commit_is_penalized` / `test_repeat_penalty_caps_at_two_stacks`：连斩惩罚与层数上限。
- `test_guard_roll_resets_while_ai_is_busy`：读招骰子不会粘住（见 §6 勘误 1）。
- `test_ai_counters_whiffed_guard` / `test_ai_waits_before_opening_against_idle_foe`：确定反与起构安全。
- `test_opponents_are_characters_too` / `test_build_match_wires_both_characters`：多角色基础。

### 机器人回归（临时探针，未入库）

三剑 × 三场（教学/老练/关底）× 3 seed，每场上限 30s。机器人三种：连砍（每帧按攻击）、读招架（见构后延迟 d 帧按一次架）、读招+罚。

| 机器人 | char_a | char_b | char_c |
|---|---|---|---|
| 连砍（修复前） | 100% | 100% | 100% |
| 连砍（修复读招骰子后） | 67% | 33–67% | 67–100% |
| 连砍（最终 NORMAL 档） | **0%** | **0%** | 67–100% |
| 读招+罚（最终） | 100% | 67–100% | 67–100% |

- 连砍对 A/B 已从「必胜」降到 0%，无脑攻击不再能赢。
- char_c 仍偏高：15 伤 × 2 刀即杀 30 血对手，属数值必然（批复指定 15 伤）。它的约束在**人类**侧——350ms 前摇 + 36f 被架硬直 + 10f 连斩惩罚，慢到能被读。
- 「读招+罚」是熟练玩家上限，赢是对的。

## 6. 勘误（方案文档里的偏差）

1. **AI 读招骰子会粘住**（实施中发现）：`_guard_planned` 原先只在「AI 处于 IDLE 且对手不在构」时清零；AI 被砍中/收招时会提前 `return`，于是**一次失败的骰子会粘住整场**——AI 再也不架。这是 02 之前「无脑连砍」的真正主因，修复后才谈得上调参。
2. **连斩窗口 500ms → 1000ms**：连砍自身周期约 38f（633ms），500ms 窗口永远不触发，等于没做。
3. **开场心得窗口**：`u09 opening_commit` 原先判 `frame < 180`，而礼让期内按键会被 `set_input` 直接丢弃，心得等于不存在。改为「礼让结束后的 5 秒」（`OPENING_COMMIT_WINDOW = 300`）。
4. **HARD 档保留旧帧数**：`HARD_COMMIT` / `HARD_GUARD` 把前摇与架窗回滚到 18–20f / 11–14f，HARD 是「旧版难度」，不是「新数值 + 更凶的 AI」。

## 7. 待人类处理 / 待观察

- **文案**：`docs/gamejam/submission-checklist.md` 与 HUD 说明里「2 伤 / 3 伤」等符卡描述已过期（现为 20 / 30），需人类改写；`AiProfile.display_name` 仍是 `PLACEHOLDER`。
- **只守不攻**：探针里「全程只架不还手」的机器人会把对局拖到 30s 上限（AI 打不进去，玩家也不赢）。关底有符卡破局，中段可能变成互相瞪眼——若试玩出现，优先给中段 AI 一个「架住后连击」的答案，而不是降架窗。
- **重剑连砍**：见 §5，若人类试玩仍觉得无脑，优先加 `repeat_commit_penalty`（10 → 12/14），不要降伤害（会破坏符卡数值刻度）。
- **NORMAL 档 guard +0.15**：教学关的 AI 架住率随之上升（0.30 → 0.45），若新手觉得「砍不动」，单独给 `persona_1_teaching` 降回 0.35。
- **`docs/dev-example/design.md` §6.3 / §6.7 的旧帧数表已过期**（18f/300ms、3–4 HP），以本文为准；design.md 的整表重写留到美术/流程定稿时一起做。
