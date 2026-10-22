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

**当前**：版本 **`0.1.0`**；GUT **212/212（811 asserts，29 个测试脚本）**；headless 冒烟 240 帧无错误；
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

---

## 8. 补记：粒子素材入库与临时素材区隔离（2026-10-23）

第一天做美术素材时踩到的工程问题，记下来避免以后重复。

**任务**：把 `temp_assets/kenney_particle-pack`（Kenney Particle Pack 1.1，CC0）里适合本作的贴图挑进
`assets/`，同时别让这个 195 文件的临时包污染工程。全流程只加载了 `godot-project-foundations`
（`.gitignore` + `.gdignore` + 资源目录规范）；粒子系统实现未做，所以没载 `godot-particles`。

**坑一：`.gitignore` 不等于 Godot 看不见。** 只加 `/temp_assets/` 时，git 不再跟踪，但 Godot 依然会把
160 张 512×512 PNG 逐个导入成 `.ctex`，FileSystem 面板里也照样列出来。正解是在该目录放一个
**`.gdignore`**（空文件即可，内容不参与解析），Godot 见到就整目录跳过——不导入、不列出、不进导出。

**坑二：`.gdignore` 不入库，所以要写进文档。** `temp_assets/` 整个被 gitignore，里面的 `.gdignore` 自然
也不会被跟踪；别人克隆仓库后不会有这个文件。因此 `AGENTS.md` §4 与 `docs/particle-assets-plan.md`
都写清了「临时素材目录需要手动补 `.gdignore`」，而不是假设它会跟着仓库走。

**坑三：验证要查「没被导入」，不能只数「导入了多少」。** `temp_assets/` 里 `*.import` 计数为 0 只能证明
那里没有生成文件；真正的证据是拿**包里没被选中的 25 个代表文件**（`flame_01`、`muzzle_01`、`window_01`、
`symbol_01`、`scratch_01`、`smoke_01`、`dirt_02`、`circle_01`、`star_01`、`spark_03`、`scorch_02`、
`trace_01`、`magic_04` …）反查 `.godot/imported/`，确认**查无对应 `.ctex`**。

**选型口径**：80 张里取 36 张，按**用途**分目录（`slash` 7 / `impact` 10 / `guard` 3 / `spell` 6 /
`dust` 7 / `glow` 3），不按形状分；文件名保留 Kenney 原名，换图时删旧添新即可回查。
明确不取的 44 张（枪口焰 `muzzle_*`、烛火 `flame_*`、UI 网格 `window_*`、心形 `symbol_01`、
爪痕 `scratch_01` 等）理由写在 `docs/particle-assets-plan.md` §7——「多收一点备用」反而会让后面挑图更难判断。

**规格决定用法**：这批图是 **512×512、纯白图案 + alpha**，不是成品彩色特效。颜色必须运行时给，
而且现有调色板已经够用（`COLOR_P1/P2`、`COLOR_FLOW_LOW/MID/HIGH`、`COLOR_SPELL_P1/P2`），
所以没有为粒子新增任何颜色，双方也不用各存一套贴图。

**工具使用坑**：用 `godot ... | Select-Object -Last 30` 取日志尾巴时，`$LASTEXITCODE` 会变成 1，
看起来像导入/测试失败；直接 `& godot ... | Out-Null` 取值才是 0。判断成败要看 Godot 自己的
`All tests passed!` / `reimport | DONE`，不要只看管道退出码。

**验证**：`--headless --import` 重导 36 步无报错，36 个 `*.png.import` + 对应 `.ctex` 齐全；
GUT **195/195（746 asserts，退出码 0）**，与改动前一致（本次未改 `.gd` 代码）。

**遗留**：贴图**未接入**任何场景，`DuelView` 仍是纯 `draw_*` 灰盒；接入方案（`duel_fx.tscn` + `one_shot`
复用、按事件传色、暂停/重开清理）见 `docs/particle-assets-plan.md` §6，待人类拍板。→ 已于同日接线，见 §9。

---

## 9. 补记：粒子接线（命中 / 对刀 / 架防，2026-10-23）

**任务**：人类拍板先接核心三类事件（`hit_landed` / `clash_happened` / `attack_blocked`），并特别点出
「注意分辨率和游戏内大小的问题」与「不要忘记粒子上色」。本轮加载 `godot-particles` 技能，按其硬规则落地。

**分辨率与尺寸是同一个问题**：设计画布 1280×720（`stretch/mode="canvas_items"`），角色只有 46×150，
而贴图 512×512。1:1 会占 72% 屏高，所以尺寸必须按「设计像素最长边 / 512」换算成 `scale`：
命中 110 / 对刀 140 / 架住 170 / 完美 220。**更关键的是 mipmaps**：`trace_*`/`spark_*` 这类细线在 512 里
只有约 10px，缩到 0.2 倍只剩 2px，不开 mip 就是满屏闪烁噪点。36 张 `.import` 全部改 `mipmaps/generate=true`，
节点配 `TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`——两者少一个都不起作用。

**上色**：贴图是纯白图案 + alpha，颜色只能运行时给。人类选定「攻击方制」：命中=出刀方色、架住=防守方色、
对刀=暖白 `#fff3c4`、完美格挡=心流青 `#9ff0d0`，全部取自 `duel_view.gd` 既有调色板，没有为粒子新增颜色。
读法也顺手：火花是「谁的刀」，护罩是「谁在架」。

**one-shot 的坑（技能里写死的那条）**：`finished` 之后再置 `emitting = true` 会吃到 GPU 侧异步状态，
整发可能不显示。正确做法是**只调 `restart()`**，`finished` 回调仅把 `emitting` 归零；池化复用，
12 个节点（4 类 × 3）一次性建好，战斗帧内零分配。
另外 `local_coords = false` 必须开——节点每次爆发都会被挪到新位置，局部坐标会让上一发的火星跟着跑。

**暂停要手动冻结**：本作的「暂停」是控制器里的 `_paused` 标志，没有 `get_tree().paused`，
GPU 粒子完全不受影响。所以 `_open_pause_panel()` / `_close_pause_panel()` 里显式
`view.set_paused()` → 每个节点 `speed_scale = 0/1`；暂停期间的新爆发直接丢弃，避免解冻瞬间补放一串。

**尺寸是看截图改出来的，不是算出来的**：写了 `tools/capture_fx_preview.gd`（`--windowed -s`）把四类特效
并排拍成一帧，三轮迭代：
1. 对刀 26 颗 / 190px → 加色混合叠成一团纯白，轮廓全丢；架住 `circle_02` 的环线在 170px 下太细，被角色身体吃掉一半；
2. 对刀砍到 10 颗 / 150px、架住换厚双环 `circle_03` 并放大到 170；
3. 对刀再降到 7 颗 / 140px、初速提到 320–700，八角星轮廓才可辨。
结论：**加法混合下，「数量 × 单颗尺寸」的平方效应远大于线性直觉**；环类贴图要看环线宽度，不能只看整体边长。

**测试坑**：`assert_no_new_orphans()` 不能放 `after_all`——GUT 的 orphan 计数器只在「当前测试」期间有效，
放外面报 `Nonexistent function 'size' in base 'Nil'`（`addons/gut/test.gd:2085`）。改为单测内部调用，
覆盖「爆发后无孤儿」。

**工具坑（同一个兔子洞踩第二次）**：`& godot ... | Select-String` 会让 `$LASTEXITCODE` 变 1，
`$out = & godot ...` 在本机拿到空数组；可靠写法是
`Start-Process -FilePath $godot -ArgumentList @(...) -Wait -PassThru -NoNewWindow -RedirectStandardOutput ... -RedirectStandardError ...`
再读 `$p.ExitCode`。§8 记过一遍，这次又踩，已写进 §5 的复现命令。

**验证**：GUT **212/212（811 asserts，退出码 0）**，新增单测 10 例 + 集成 7 例（信号→贴图、`bind()` 清空、暂停透传）；
`docs/dev-example/duel-fx-preview.png` 四类并排截图；headless 240 帧冒烟无 `ERROR`。

**遗留**：挥砍弧（`draw_arc`，半径 122）与符卡爆环**保持原样**——「替换弧与爆环」是人类的原话，
但本批范围只有三类，留到「刀光 + 符卡」批次一起换，避免一次改动同时动渲染层与判定提示；**已在 §10 完成**。
扬尘、空架、收刀、心流氛围仍未接线，贴图已备。

## 10. 补记：刀光与符卡爆环（2026-10-23，第三批）

**任务**（人类原话）：「挥砍弧使用 twirl_03 替换，但是如何替换本身就需要考量一下。符卡爆环使用
circle_02 且使用紫色。」——难点不在调用，而在「固定形状的贴图怎么摆到一段参数化的弧上」。

**先量再摆**：`twirl_03` 看着像一团白雾，肉眼看不出朝向。写了段 System.Drawing 统计
「alpha > 96 的像素」的极坐标分布，得到：亮带半径 **175–231 / 512**（中位 203）、张角 **-80°…+28°**
（中心 -26°、跨度 108°）。旧弧是 ±51.5°（跨度 103°）、半径 122、线宽 6 的白线——两者跨度几乎一致，
于是「替换」变成纯几何对位：

| 要对的量 | 做法 |
|---|---|
| 半径 | 缩放 `122 / 203 ≈ 0.60`，亮带落到半径 105–139，正好压住旧弧 |
| 朝向 | 贴图带中心 -26°，旋转 **+26°** 对齐到 0°（P1 朝右）；P2 再加 180° |
| 弧心 | 沿用 `(cx, top + 70)`；`cx`/`top` 用 `_swing_center()` 复用 `_draw_fighter()` 的 lean/crouch，刀光才不会飘离刀身 |

**为什么不是粒子**：挥砍不是一瞬事件，而是持续 4–6 帧的连续态（`slash_frames` = 5/4/6，
`_is_swinging()` 连收招头几帧也算）。用 `GPUParticles2D` one-shot 每帧重发，既贵又会在慢帧上断档；
改成一枚 `Sprite2D`，每帧由 `DuelView._process()` 调 `pose_slash()` 摆位——零分配、帧率无关。
时间轴上，旋转从 -0.17 扫到 +0.12 rad（约 17°）读作「刀在走」，alpha `0.85 × (1 - p² × 0.85)`
让收刀前淡出，最后一帧仍留 0.13 残光，不会啪地消失。

**颜色**：刀光保持白色，不吃攻击方色。理由是要和第一批的染色读法分工——「命中火花按出刀方」表示是谁
打中的，刀光则是「同一把刀的轨迹」，染成方色会让两种语义打架。符卡环按人类指定统一用紫色
`#b79bff`（既有 `COLOR_SPELL_P1`），双方共用；被打断时强度乘 0.6，读作「没放出来」。

**符卡环的尺寸同样是量出来的**：`circle_02` 的环外缘在 172 / 512，所以缩放系数 = 目标半径 / 172
（不是 / 256）。内外两枚按 0.72 倍套，半径 36 → 366 用 ease-out 推开，时长 0.62s（对齐旧
`_spell_flash` 的 1.6/s 衰减），alpha `(1-t)^1.4 × 0.75`。

**截图坑（新）**：第一版截图里**刀光根本没出现**。原因是截图用的 sim 还在待机，而
`DuelView._process()` 每帧都会调 `_update_slash_fx()`，待机即 `hide_slash()`——手动摆上的月牙在下一帧
就被收走了。修法：截图工具先 `view.set_process(false)` 再摆位。这类「表现层由状态机驱动」的效果，
截图脚本必须先把驱动停掉，否则拍到的永远是空帧。

**验证**：GUT **224/224（847 asserts，退出码 0）**（`test_duel_fx.gd` 10 → 18 例、
`test_duel_view_fx.gd` 7 → 11 例）；新截图 `docs/dev-example/duel-fx-slash.png`；headless 240 帧冒烟
无 `ERROR`；`duel_sim.gd` / `fighter_data.gd` 零改动。

**遗留**：连斩第 2 段起换 `twirl_01/02`、符卡蓄力法阵、被打断的火星+烟、扬尘/空架/收刀/心流氛围都未接；
`set_strength()` 仍未进设置页。

## 11. 补记：扇形消失与蓄力环（2026-10-23，第三批反馈）

**人类的三点反馈**：① 「符卡粒子应该是 circle_02，为什么看着像 circle_03？」② 「斩击特效能否有一阵
扇形消失的感觉，随挥刀方向逐渐消失。」③ 「攻击前摇也应该有一个圆形特效件。」并在下一轮补充：
「star_03 是代替原来的攻击蓄力环，不是叠在角色身上」「素材确实偏暗，可以换成 light_03」。

**第①点先证伪再修**：`Get-FileHash` 比对 `assets/particles/guard/circle_02.png` 与源包
`PNG (Transparent)/circle_02.png`，MD5 都是 `8634C6D0…`、43,380 B —— 用的确实是 `circle_02`。
看起来像 `circle_03` 的真因是**同一张贴图叠了两枚**（外环 + 0.72 倍内环）再走加法混合，视觉上被读成
「一道厚环」。改法是把内环删掉，只留单枚，并把半径改成 30 → 250、时长 0.55s 补偿视觉密度。教训：
**贴图身份正确 ≠ 观感正确**，叠加层数本身会改变「这是哪张图」的判断。

**第②点：静态贴图做不出「扫过的部分消失」**。`twirl_03` 是一整条月牙，Sprite2D 只能整体旋转/缩放，
想只抹掉刀锋后的角度，就必须在片元里按角度裁剪。于是新建 `resources/shaders/slash_sweep.gdshader`：
UV 换极坐标得角度 `ang`，`head = mix(head_from, head_to, progress)` 是刀锋角，
`fade = 1 - smoothstep(-0.06, tail_span, head - ang)` 让「刀锋后方」直接归零，`COLOR.a *= fade`。

首版 `tail_span = 1.35`（77°）**比月牙总张角 108° 还宽**，等于永不塌陷——肉眼只看到整体在淡，
完全不是「扇形消失」。靠三格裁切 + 逐格亮像素统计（1079 / 3093 / 2663 / 318）才发现，收到
`tail_span = 0.16`（9°）后，连拍才出现「0% 全弧 → 35% 上端消失 → 70% 半截 → 100% 收尾」。
教训：**shader 的「看起来没变化」要先怀疑参数与几何的量级关系**，不是混合模式。

**第③点：是替换，不是叠加**。第一次理解错了，把蓄力环当成「角色身上多一件光效」，结果和自绘的
收束弧同时在场上。人类指正后，把 `_draw_fighter()` 里两道 `draw_arc`（主弧 + 临刀白弧）整段删除，
只留头顶进度圆点，环交给 `DuelFx.pose_charge()`。

选贴图试了五个：`magic_02`（八圆点在 120px 上散成气泡）、`magic_03`（四菱形芒压扁后变穿腿长刺）、
`circle_02` + `circle_05` 双层（发虚）、`star_03`（等比缩放确实是正圆，但最大 alpha 只有 73/255，
太暗），最后定 `light_03`（亮带外缘 208 / 512、maxAlpha 235）。这也说明**「圆形」不等于「环」**：
`light_03` 是实心径向光，压到 0.82 alpha 才不把角色洗掉。

数值口径经两轮人类修正：初版「越接近出刀越紧」（96 → 52）被指「应该是从小逐渐变大」，改为 20 → 132
线性生长；颜色由「金黄 + 临刀换白」改为「`#fffdf7` → `#ffc94a` 由白转亮金，临刀只让 alpha 呼吸」，
因为掺白会把金洗成米色。圆心也从 `(x + 14, 466)` 改成 `_draw_aura()` 的 `(x, GROUND_Y - 90)`——
前一版既吃了 COMMIT 的前倾（±14）又比心流环低 16px，两个圆不同心。

**共同坑**：截图工具里凡是由状态机驱动的效果，都要先 `view.set_process(false)` 再手动摆位，否则下一帧
就被 `_update_*_fx()` 收走（刀光那轮已经踩过一次，这轮换蓄力环又验证了一遍）。

**验证**：GUT **229/229（871 asserts，退出码 0）**；新截图 `docs/dev-example/duel-fx-sweep.png`（四格连拍）与
`duel-fx-charge.png`；headless 240 帧冒烟无 `ERROR`。


