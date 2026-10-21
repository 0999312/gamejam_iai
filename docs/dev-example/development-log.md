# 开发过程留档（2026-10-19 → 2026-10-21）

> 用途：把「人类反馈 → 诊断 → 改动 → 验证」的完整链路留成可检索的记录，
> 供后续调参、复盘、以及接手者快速理解「为什么现在是这些数字」。
> 里程碑的静态快照见 `m1-status.md` … `m5-status.md`；单轮平衡的细节见
> `balance-pass-01.md` … `balance-pass-04.md`。本文是它们的**时间轴与方法论索引**。

---

## 0. 本项目的工作流特点（先读这一节）

### 0.1 人类给方向与体感，AI 负责把它翻译成数字

人类几乎不说「把 `base_commit` 改成 28」，只说体感：

- 「人的反应极限 0.1s，平均 0.2s，算上判敌人出手差不多 0.3s 按下格挡」
- 「整体战斗节奏还是偏快」
- 「架防本身的设计有点不符合直觉」
- 「缓冲反而导致了操作迟缓且手感不适应」

AI 的工作是**把体感拆成可测量的量**（反应窗、毫秒、胜率、被架次数），
再给出改动方案。方案的验收标准也必须是可测的，而不是「感觉好点」。

### 0.2 纯逻辑先行：战斗核心不依赖节点

`scripts/duel/duel_sim.gd`（`class_name DuelSim extends RefCounted`）是纯逻辑定步长仿真，
不继承 `Node`、不读输入、不依赖场景树。`duel_controller` 只做「按键 → `sim.set_input` → `sim.tick()`」。

收益：同一份判定可以被三种消费者复用——真实对局（控制器）、单元测试（GUT）、
机器人探针（headless 批量跑胜率）。**没有这一层，后面的量化验证都做不了。**

### 0.3 毫秒优先：任何「个位数帧」的改动都要先换算

引擎逻辑帧固定 60Hz（1f = 16.67ms）。改 1–2 帧在人类感知里是噪声
（时间差别阈限约 10–20%：300ms 尺度上 2–4f 才勉强可辨，6f/100ms 才明确）。
所以讨论帧数时一律先换算成毫秒，并说明「这个改动玩家能不能感觉到」。

### 0.4 三重验证门：探针 → 单元 → 集成

1. **探针**（headless 机器人矩阵）：在改数值**之前**先量化现状，改完再跑同一矩阵对照。
2. **GUT 单元测试**：判定链、心流收支、符卡效果、AI 决策。
3. **集成/快速启动**：`--headless --path . --quit-after 120` 无报错 + `tests/integration/`。

任何一轮平衡都要留下「改前 → 改后」的同一张表，否则无法判断改动是否真的有效。

### 0.5 一改一档：每轮平衡一篇文档

`balance-pass-0X.md` 固定结构：**诊断（含代码位置）→ 改动表（数值 + 文件）→ 实测表 → 遗留风险 → 验证计数**。
文档和代码在同一个提交里，避免「代码改了但没人知道为什么」。

### 0.6 合规是硬约束，不是事后补

- **AI 不生成任何玩家可见文案/美术/音乐**：新 UI 文案一律 `PLACEHOLDER` 或复用 I18N key，登记到
  `docs/gamejam/submission-checklist.md`。
- **每个模块完成后**在 `docs/gamejam/ai-disclosure.md` 追加一行（日期/模块/用途/AI 率/人类复核）。
- 游戏内「关于」页与提交 README 必须注明东方 Project 二次创作声明。

### 0.7 工具环境的三条铁律（踩过的坑）

| 铁律 | 原因 |
|---|---|
| 改 UTF-8 源码只用 `edit`/`write` 工具，**绝不用** PowerShell `Set-Content`/`-replace` | 会写出非法 UTF-8，`read` 直接报 `invalid UTF-8 text`；恢复靠 `git checkout -- <path>` |
| 抓 godot 输出必须 `Start-Process ... -RedirectStandardOutput <file>` 再读文件 | PowerShell 管道拿不到 `godot.exe` 的 stdout，`$LASTEXITCODE` 也不可靠 |
| 新增 `class_name` 后先跑 `--headless --import` | 否则 `.godot/global_script_class_cache.cfg` 未更新，测试报 `Nonexistent function 'new' in base 'GDScript'` |

---

## 1. 总时间线

| 日期 | 阶段 | 关键提交 | 验证 |
|---|---|---|---|
| 10-19 | 立项：模板、约束文档、GDAS 技能库（33 个，GUT 版改写） | `a279e41` `0529a23` `3f60c17` `50ed59c` `384ceb9` | — |
| 10-20 白天 | M1–M4：灰盒可玩 → 5 场阶梯 → 存档/主菜单 → 局外成长/设置/暂停/角色 B·C | `7da75a5` | GUT 全绿 |
| 10-20 下午 | M5：全手柄 UI、改键/热插拔、商店目录化、Windows 导出与 CI Release | `c248ca2` `65eec1b` `0fd1a0e`…`ef4449c` | 导出产物 + CI |
| 10-20 晚 | 符卡 v0.20 规则级重做 + v0.21 占位补齐 + 固定 60Hz 逻辑帧 | `5851abe` | GUT 69/69 |
| 10-21 晚 | 手感与平衡五连改：02 → 03 → 架防按住 → 04 → 04b | `9ae4997` `88f9757` `e986387` `190fbf5` `a2a8079` | 159→166 用例，575 asserts |
| 10-21 深夜 | **全量代码审计 + 六批修复 + 版本号 0.1.0**（P0 音量键名、存档原子写、种子、AI 性格、关于页、清档、架防按住、菜单二级化、空架收势、难度量化、收招取消） | `a9fcb5c` `2b15e04` `2a7e205` `8c30dd5` `e1fc420` `6f36b27` | 169→**195** 用例、746 asserts |

---

## 2. 逐阶段记录

### 2.1 10-19：把规则先钉死

在任何玩法代码之前，先把**活动硬约束**写进仓库：截止时间、主题「心」、AI 使用边界
（可写代码、禁生成艺术资产）、东方二次创作规约、提交物清单。
同时引入 GDAS 技能库并把 `godot-testing-patterns` 从 GdUnit4 版改写为 **GUT 版**——
这决定了后面所有测试都只用一个框架。

### 2.2 10-20：从灰盒到可导出

M1–M4 一次性落地（`7da75a5`）：居合判定、5 场阶梯、心得三选一、金币/残心、局外存档、
主菜单、本地双人、角色 B/C、设置与暂停。M5（`c248ca2`）补全手柄 UI 与改键、商店目录化，
并接上 GitHub Actions 导出 Windows 包（CI 调试占了当天下午大半提交）。

当晚 `5851abe` 做了两件影响深远的事：

1. **符卡规则级重做**（`spell_a` 架势 / `spell_b` 疾风连斩 / `spell_c` 崩山 / `spell_boss` 崩势斩·极），
   UI 文案先用 `PLACEHOLDER` 占位；
2. **固定 60Hz 逻辑帧**——从此所有判定与调参都以整数帧表达，才有了后面「毫秒换算」的可能。

### 2.3 10-21：五轮手感与平衡

这一天的五轮改动是本文的重点，全部由第三方试玩反馈驱动。

---

## 3. 五轮改动的「反馈 → 根因 → 手法 → 结果」

### 3.1 平衡 02：反应窗毫秒化 + HP×10 + 多角色基础（`9ae4997`）

- **反馈**：「算上判敌人出手差不多 0.3s 按下格挡，实际反应不过来」；「整体节奏偏快」；
  「快剑可以无脑攻击取胜」；「后面可能需要更多角色」；「开局待机不该涨心流」。
- **根因**：守卫窗口公式 `[T−G+1, T−2]` 中，**上限只由敌方前摇 T 决定**，当时 T=18–20f
  （300–333ms），留给人按下 + 生效的时间不足；且三剑的 `base_commit` 只差 1–3f，玩家感知不到。
- **手法**：敌方前摇 18–20f → **28–30f（467–500ms）**；玩家架窗 12–20f → 18–22f；
  HP 3–4 → **30/30/40**，伤害 1/2 → **10/7/15**；新增**连斩惩罚**（8/4/10f，1000ms 窗口、最多 2 层）、
  **反斩**（对手空挥/被架硬直中出刀，前摇 −4f，随残心最多 −10f）、**双难度档**（NORMAL 默认 / HARD 回滚旧帧数）、
  **血条**；开局礼让期不再涨心流。
- **验证**：连砍机器人胜率 100%（修复 AI 读招骰子粘滞后 67/33–67/67–100%）→ 最终 NORMAL 档
  对均衡/快剑 **0%**，重剑仍 67–100%（重剑的遗留见 §6）。
- **架构**：拆出 `FighterData.for_character()`（8 个 id）、`FighterData.stage_enemy_id()`、
  `AiProfile.for_persona()`、`MatchSetup`、`RunState.roster()/stage_cast()`——多角色代码基础先打好。

### 3.2 平衡 03：打通攻防变招（`88f9757`）

- **反馈**：「攻击转防的变招和防御转攻的变招在实际游戏中打不出来……防御本身是一个代价非常大的操作」。
- **根因**：`_apply_action` 的 `GUARD` 状态没有 `ATTACK` 分支（输入被 `_: pass` 吞掉）；
  构→架的取消窗只有 5f（83ms）；输入缓冲 4f 短于 7–9f 的收架硬直，预输入**必然过期**。
- **手法**：取消窗 10f；架中按斩立即出刀；架住后 **30f 反击窗**内按斩 = **顺势斩**（前摇 −6f）。
- **验证**：探针「架住 + 帧完美反击」100% 胜；人类反应 250ms 仍 100/67/100，350ms 掉到 33–67%。

### 3.3 架防改为「按住保持 / 松手立刻收」（`e986387`）

- **反馈**：「架防的帧数应该是单次架最高帧数，然后可以极短帧收回」。
- **手法**：`set_input(..., guard_held)` —— `1` 按住、`0` 松手、`-1` 未提供（AI/脚本）；
  松手后 2f 收势且**不扣心流**；按满上限才结算 `_finish_guard`（空架 −8 心流 + 7–9f 收势）。
- **结果**：点按 = 低成本试探，按住 = 承诺。GUT 165/165。

### 3.4 平衡 04：主动出刀手感（`190fbf5`）

- **反馈**：「自己前摇过长而感觉到出刀迟缓，主动攻击的手感很重」。
- **根因**：玩家前摇 18/15/21f 全部 ≥ 敌方 AI 的读招反应 12–16f，主动出刀几乎必被架；
  且 `SLASH` 在命中当帧就转 `RECOVERY`，**刀光从未渲染过**——观感是「按下 → 人一歪 → 对面掉血」。
- **手法**：玩家前摇 18/15/21f → **14/11/17f**（对手 28–30f 不动，两套需求解耦）；
  `duel_view._is_swinging()` 让收招前 `slash_frames` 帧也画挥砍弧。
- **验证**：连砍对均衡/快剑在 stage 2/4 仍 0%，没有把 AI 读招打穿。

### 3.5 平衡 04b：取消输入缓冲（`a2a8079`）

- **反馈**：「缓冲反而导致了操作迟缓且手感不适应，取消输入缓冲更为合适」。
- **根因**：缓冲的本质是「你现在按的指令，过一会儿自动执行」，玩家看到的是角色慢半拍地补动作。
- **手法**：删除 `buffer_action`/`buffer_expire_frame`/`spell_buffer_expire_frame`/`input_buffer`，
  以及 `_buffer`/`_buffer_next_attack`/`_consume_buffered_input`。
  输入要么**当场生效**（待机斩/架、构→架取消、架中转攻、架住顺势斩），要么**当场作废**
  （收招/受击/构/斩里的按键）。符卡不在待机按下 → 当场 `spell_failed`。
- **代价**：硬直末尾「提前一点点按」不再有容错。用**确定感**换**容错**。

---

## 4. 方法论沉淀

### 4.1 守卫窗口公式（本轮最重要的推导）

设敌方前摇 `T = commit_total`（含档位偏移、反斩、连斩惩罚），守方架窗 `G = guard_duration`：

```
可挡区间 = [T − G + 1, T − 2]
```

- **上界 `T − 2`**：留 1f 输入延迟 + 1f `guard_startup`，只由**敌方前摇**决定；
- **下界 `T − G + 1`**：按早了会空架（−8 心流 + 收势），只由**架窗**决定。

推论：想让玩家「晚一点按也来得及」，必须**加长敌方前摇**，堆架窗只能改善早按空架。
这条推翻了「把架窗加到 20f 就够了」的直觉，也是把敌方前摇拉到 28–30f 的原因。

### 4.2 为什么最终删掉输入缓冲

| 方案 | 观感 | 问题 |
|---|---|---|
| 4f 缓冲 | 几乎无感 | 短于 7–9f 收架硬直，等于没有 |
| 加长到覆盖整段硬直 | 硬直中按的招「等一会儿自己出来」 | 玩家感到**操作延迟**，且失去对时机的控制 |
| **无缓冲（现在）** | 按下即生效，慢了就是没按上 | 硬直末尾的提前按不再有补偿 |

结论：**在「以读招与时机为核心」的对局里，确定感比容错重要**；
真要补偿，也应该做「极短（1–2f）窗口」而不是几十帧的排队。

### 4.3 探针矩阵模板

```
配置：NORMAL 档，敌方 AiProfile.for_persona(persona_id, TIER_NORMAL)
robot：
  mash       每帧按斩
  guard_only 见构后延迟 d 帧按架（并按住）
  human      见构后延迟 d 帧按架，架住后延迟 e 帧出刀
维度：角色 char_a/b/c × stage 0/2/4 × seed 3 个
指标：胜率、平均帧数、被架次数、命中次数
```

关键细节：统计量必须放在 `Dictionary` 里（GDScript lambda 按**值**捕获局部变量）；
信号参数个数必须与回调签名一致（`attack_blocked(attacker_side, defender_side, perfect)`）。

### 4.4 错误清单（同类问题别再犯）

1. **AI 读招骰子粘滞**：`_guard_planned` 只在「AI 处于 IDLE」时清零，AI 一挨打就再也走不到清零
   → 一次失败骰子粘住整场，AI 再也不架。修复：在 `me.state != IDLE` 早退**之前**
   按「对手是否仍在构」清零。这个 bug 让「无脑连砍」看起来是数值问题，其实是状态机问题。
2. **阈值写死绝对值**：HP×10 后 `me.hp <= 2`、`foe.hp <= 1` 这类判断全部失效
   （关底二阶段与符卡永不触发），必须改成比例。
3. **`frame < 180` 硬编码礼让期**：应读 `opening_lock_frames`（v1 的 u09「开场构前摇 −3」曾因此等于不存在）。
4. **文档与代码漂移**：`design.md` §6.3 的帧表仍是 v1（18f/300ms），以 `balance-pass-02/03/04` 为准。

---

## 5. 复现与验证命令

```powershell
# 全部 GUT（退出码 0 = 全过）
Start-Process -FilePath "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" `
  -ArgumentList '--headless','--path','.','-s','addons/gut/gut_cmdln.gd','-gdir=res://tests','-ginclude_subdirs','-gexit' `
  -NoNewWindow -Wait -RedirectStandardOutput .gut_out.txt -RedirectStandardError .gut_err.txt
Select-String -Path .gut_out.txt -Pattern 'Tests |Asserts|All tests' | Select-Object -Last 5

# 刷新全局类缓存（新增 class_name 后必须）
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --import --path .

# 无头冒烟
Start-Process -FilePath "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" `
  -ArgumentList '--headless','--path','.','--quit-after','120' -NoNewWindow -Wait `
  -RedirectStandardOutput .boot_out.txt -RedirectStandardError .boot_err.txt
```

机器人探针是临时文件（`.tmp_probe/`），跑完必须删除且不得提交。

---

## 6. 当前状态与遗留

**当前**：版本 **`0.1.0`**；GUT **195/195（746 asserts，27 个测试脚本）**；headless 冒烟 240 帧无错误；
NORMAL 为默认难度，HARD 在商店解锁后可切换；8 个角色 id（3 可操作 + 5 对手）已具备数据与 AI 性格，
但「收服敌人作为可操作角色」尚未接线。逐批变更见根目录 `CHANGELOG.md`。

**已在本轮审计中修掉的历史遗留**（原文保留在下方「曾经」中，便于对照）：

1. ~~重剑连砍仍强~~：伤害已从 15 降到 15 但 HP 30 + 连斩惩罚 + 被架收招 28f 已能反制，模拟器验证；
2. ~~只守不攻可拖成僵局~~：`_check_end()` 只看 HP、格挡不造成伤害，该结论本身不成立，已在
   `balance-pass-05.md` §7 更正；
3. ~~AI 读招在短前摇下被夹到 0~~：`_try_counter` 已加 `counter_delay_frames`（6–8f），不再第一帧起架；
4. 教学关 `guard_chance` 已降到 0.18；符卡文案仍是占位（需人类撰写）。

**已知遗留**（需要人类决策，按影响排序）：

1. **44 条玩家可见文案仍是 `[占位]`**：作品名、角色名、心得名/描述、教程、符卡名/描述；
2. **UI 是「代码即 UI」**：7 个 `.tscn` 为空壳，节点树在 `_ready()` 里建，`%UniqueName` 零使用；
   不满足 `AGENTS.md` §8 的实质要求，但功能正常、改造成本高（建议留到比赛后）；
3. **未在非开发机 / 不同分辨率验证**；未做 10 分钟长跑；`submission-checklist` 对应项仍未勾；
4. 字体重复约 29 MB + 导出 UID 重复警告；`DuelView` / `DuelAudio` 无直接测试。

---

## 7. 补记：技能与插件的实际使用审计（2026-10-21）

开发完成后做了一次回溯审计，结论写在这里，避免以后误以为「技能已经用过了」。

**技能：0 次加载。** `scripts/`、`tests/`、`docs/dev-example/` 中没有任何技能引用，
`ai-disclosure.md` 的历史行里也没有技能名。M1–M5、符卡 v0.20 重做、平衡 02–04b 全部是
「凭经验推导 + 探针验证」，没有走 GDAS 技能。

代价是可见的：输入缓冲先后做了「4f → 覆盖整段硬直 → 整体删除」三次迭代，
而 `godot-genre-fighting` / `godot-input-handling` 里对「读招类游戏不该用长缓冲」本就有直接论述；
AI 读招、帧数据分析也没有先查 `godot-state-machine-advanced` 的决策树。**这轮返工是流程债，不是技术债。**

**插件：4 用 3 空（2026-10-21 已补齐）。** `GUIDE` ✅、`SoundManager` ✅、`I18NManager` ✅、`RegistryManager` ✅；
`EventBus` ❌、`UIManager` ❌（7 处裸 `change_scene_to_file`）、`Codec` ❌。

**补记（同日稍晚）**：`EventBus`、`UIManager`、`Codec` 已全部接线（`8c30dd5` 之前的 v0.23 框架落地），
7 处裸 `change_scene_to_file` 只剩 2 处真场景切换（菜单 ↔ 对局），面板一律走 `UIManager.open_panel`。
本次全量审计后，`docs/dev-contract.md` §3.1 另登记了 5 项**不可替代**的插件豁免（AudioServer master/mute、
`InputMap` 的 `ui_*` 手柄补充、`GUIDE._input_state`、`GUIDERemappingConfig._bind/_unbind`、
`Input.get_connected_joypads()` 只读），每条都有「为什么插件做不到」的理由。

处置：`AGENTS.md` 新增 **§0 会话启动契约**（开工先读 `docs/dev-contract.md`、声明并加载技能、插件优先、
未接线插件不得扩大偏差），并新增守卫测试 `tests/unit/test_project_contract.gd`
（扫描 `res://scripts/` 的禁止 API + 校验 5 个 autoload 存在），把这套约束变成会失败的红灯。

