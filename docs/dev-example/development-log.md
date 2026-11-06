# 开发过程留档（2026-10-19 → 2026-11-04）

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

## 12. 补记：雨夜背景与战败去灰盒（2026-11-04）

**需求**（人类原话，`m00525`）：「删除战败后还会显示的占位小人，将背景改为用 shader 生成出来的
『看不清四周的雨夜』，`temp_assets/shader.txt` 是用于下雨效果的 shader，可以借鉴。」

**战败灰盒不是「多画了一笔」，而是两套表现层没对齐**。旧 `DuelView._draw_fighter()` 在 `DOWN` 分支
无条件画 140×26 矩形 + 圆头；旧 `SpineFighterView` 又在 `DOWN` 时把骨架隐藏。五动作版让 `siwang`
保持可见后，灰盒矩形就成了叠在单膝跪地人物上的「影子」。修法是让 `DOWN` 只走一条路：
`_draws_graybox(fighter)` 为真才画旧剪影。这个判断不能只看「Spine 是否激活」——档案没有 DOWN 映射时，
骨架会隐藏，若灰盒也判 false，战败后**两边都不画**。所以 `SpineFighterView` 新增公开
`has_animation_for_state(DOWN)`，把「显式映射 + 动画存在」暴露给 `DuelView`；回退测试用
「复制 `char_a.tres` 并删掉 DOWN 键」锁住这条边界。

**雨夜先定「读什么」，再调数值**。要的不是「下雨特效」，而是「看不清四周」：中心保留人物轮廓与
脚下水光，边缘压到近黑。shader 分四层——夜空渐变、4 octave fbm 雨雾、远/近两层雨、地平线水光 +
双人脚下湿反光；最后用 `p = uv * 2 - 1`、`p.x *= 0.92`、`smoothstep(0.34, 1.20, length(p))` 做重暗角
（`edge_darkness=0.94`）。近雨长而亮（len 0.28 / width 0.10 / alpha 0.55），远雨密而细
（amount×0.68 / speed×0.72 / len 0.10 / width 0.060 / alpha×0.60），两层叠出纵深。

**首版雨线是一根根粗竖条**。把 `rain_layer` 的 `width` 当像素用了：`step(remainder * amount, width)`
在整格内都返回 1，屏幕成了竖条纹。正确做法是先算格内中心距
`center_dist = abs(remainder / cell - 0.5) * 2`，再 `slim = 1 - smoothstep(0, width, center_dist)`；
`width` 是**格宽比例**。改完才是细线。这个坑和 §11 的 `tail_span` 是同一类：**shader 看起来不对，
先怀疑参数与几何的量级关系**。

**背景层放在 `DuelView` 的第一位**：`ColorRect` 1280×720、`z_index=-1`、`show_behind_parent`、
鼠标穿透；`DuelView` 先建它，再建 Spine 与 FX。`ground_y/focus_left/focus_right` 不写死在
shader 默认值里，而由 `_apply_background_focus()` 从 `GROUND_Y/P1_X/P2_X` 换算——否则改站位后
湿反光会漂到人物旁边。背景为空时才回退旧纯色/地平线，保证无 shader 环境仍可跑。

**截图坑**：第一次只等 58 个 `process_frame` 就拍，`siwang` 还停在起始姿态，看起来像站立。
改为取 `p1._anim_state`，直接 `state.get_track(0).call("set_track_time", 0.8333)` 再等 3 帧，
才稳定拍到单膝跪地末帧。非 headless 渲染仍走 `await RenderingServer.frame_post_draw` 后
`root.get_texture().get_image().save_png()`。

**验证**：全量 GUT **269/269（1005 asserts，33 脚本，退出码 0）**，本轮新增 5 例 28 asserts
（背景 4 例 23 asserts + 无 DOWN 映射回退 1 例 5 asserts）；`--import` 退出码 0；
截图 `docs/dev-example/rainy-night-preview.png`（对局中）与 `rainy-night-defeat.png`（P1 战败，
无灰盒小人），均 1280×720。

**限制**：雨线是屏幕空间，固定 1280×720；无地面溅射/闪电/设置开关；未做低端机性能剖析。
美术 0% AI：背景由自写 shader 实时生成，无外部贴图；参考 `temp_assets/shader.txt`（Brian Smith，
MIT）只借分格思路，若直接复用代码需补许可文本。

## 13. 补记：CC0 雨声与无边框雨夜主题（2026-11-04）

**需求**（人类原话，`m00800`）：「不使用原来的风声作为背景氛围音效，使用 temp_assets 里的
`Ambiance_Rain_Calm_Loop_Stereo.wav`，该音效为 CC0 协议。然后重做游戏的 theme，使其和背景能很好
融合在一起且必要信息高度可读。」随后补充（`m01037`）：「注意：减少 AI 风格，考虑主题和游戏类型。
考虑无边框设计。」

**第一版主题走错了方向**：深蓝玻璃卡片、圆角、阴影、整圈金色焦点——每个按钮都像一块独立面板，
截图一眼就是「通用 SaaS / AI 生成 UI」。居合对决的信息本来就少，卡片会把「文字与留白」的节奏切碎。
第二版改成三条硬约束：① 按钮 normal 全透明，没有圆角/阴影，只有 hover 钢色 7% 与 pressed 淡金 13%；
② 文字优先，Label 近白 + 4px 深描边；③ 焦点只留底边 2px 刀鞘金，像夹在纸页里的刀镡。
调色板压在墨蓝黑（`#060a10` / `#0a111a`），主文字 `#e9f0f7` 对比度 17.26:1，弱文字 `#8b9bac` 6.97:1，
金色焦点 8.18:1。

**焦点样式被运行时覆盖**：主题里明明写了下划线，菜单第一项还是整圈圆角金框。根因是 `scripts/ui/ui_focus.gd`
在 `focus_entered` 时新建 StyleBoxFlat（3px 整圈、圆角、金色）并覆盖 `focus`。只改主题不够，
必须把运行时焦点环一起改成 `border_width_bottom = 2`、`border_color = #c8a063`、圆角 0、背景透明。
另一个小坑：第一版下划线画在左边（`border_width_left`），视觉上离文字太远；改到底边后才贴住按钮文字。

**设置页开关不在基线**：CheckButton 原本带整行底色，像两个孤立胶囊。把 `alignment` 改左、
`custom_minimum_size=(0,42)`、`size_flags_horizontal=SIZE_SHRINK_BEGIN`，主题 CheckButton margin 左侧归零，
「静音 / 全屏」才和「主音量」同一条 x=170 基线。

**HUD 不能只靠描边**：雨线是屏幕空间高频细节，直接压在 24px 血量与 16px 操作提示上会「字里有雨」。
`DuelHud` 在 `HudRoot` 下加顶 190px / 底 120px 两层 `GradientTexture2D` scrim（alpha 0.66 → 0、鼠标穿透、
位于 `_reward_dim` 之前），只压 HUD 带，不挡中间角色。文字描边仍保留，scrim 只做减噪。

**雨声先试转码，失败后直接用 WAV**：素材为 2 声道 / 24-bit / 48 kHz / 30.0 s / 8,640,784 B。
用 Python/soundfile 把整段转 OGG 时进程 exit 127 静默退出，只得到半成品；删掉半成品与临时脚本，
直接入库 WAV。`DuelAudio` 先 `duplicate()` 再设 `LOOP_FORWARD`、`loop_begin=0`、
`loop_end=int(round(get_length()*mix_rate))`；不能直接改 `load()` 缓存资源，否则污染其他引用。
播放走 `SoundManager.play_ambient_sound(_rain, 2.0)`（第二个参数是 2 秒淡入，不是音量），
播放器 `volume_db=-17`；停止走 `stop_ambient_sound(_rain, 0.3)`。`immediate` 分支只 `stop()` 不置空 stream，
避免 SoundManager 池回收时对 null 取 `resource_path`。headless 下不启动环境音，GUT 不残留 playback。

**验证**：全量 GUT **277/277（1050 asserts，35 脚本，退出码 0）**，本轮新增 8 例 45 asserts
（主题 5 例 17 asserts / 音频 2 例 10 asserts / HUD scrim 1 例 18 asserts）。三张 1280×720 截图
`theme-menu.png`、`theme-settings.png`、`theme-duel-hud.png` 已目视：无边框、焦点是底边金线、
HUD 雨线被压住、中心角色仍通透。

**限制**：UI 仍按 1280×720 写死；CheckButton 图标仍是 fallback 小圆点，`icon_max_width` 不能把 16px
内置图标放大；雨声循环接缝/整体音量尚未人耳终混；主题由 `tools/build_rain_night_theme.gd` 生成，
手改 `rain_night.tres` 会被下次生成覆盖；雨声原始下载页 URL 待人类补齐。美术/音频资产 0% AI。

## 14. 刀光外移与形变、主菜单雨夜、心流核查（2026-11-04）

**需求**（人类原话，`m01346`）：①「斩击特效稍微离刀身远一些，并根据出刀的效果进行一定形变」；
②「主菜单也应用上雨夜背景」；③「心流现在长时间待机反而会自然下跌至低水平……检查并确认是否为 BUG。
如果不是，告诉我当前设计以及原因」。

**刀光先解决「贴着刀身」**：旧月牙的亮带弧心正好在 122 半径，与旧 `draw_arc` 判定弧重合，读起来像刀身长出一条白边。
把 `SLASH_RADIUS` 提到 136，亮带落在 117–155，月牙离开刀身约 14px，又不至于脱开刀路变成独立光环。
形变不能靠 Sprite2D 的整体旋转：用 `whip = sin(progress * PI)` 做包络，中段 `scale.x` 最大 1.13、`scale.y` 最小 0.93、
`skew = 0.10`，起手/收刀自动回原形。位置、旋转、alpha 与刀光 shader 的 `progress` 都不动，所以判定与扇形消失不受影响。
**没把半径拉得更远**：再远会读成「刀外另有一道月牙」，而不是刀的轨迹；14px 是让白边离开刀身、又保持因果关系的折中。

**主菜单不能直接改共享材质**：`Menu` 的 `_build_ui()` 每次重建都会清空子节点，所以背景必须在清空后先建。
更关键的是 `rainy_night.tscn` 里的 `ShaderMaterial` 与 `DuelView` 共用：若直接写 `ground_y`，对局的地面线会被菜单改成 0.96。
做法是 `bg.material = bg.material.duplicate()` 后再写 `ground_y=0.96`、`pool_strength=0`；删除原纯色 `ColorRect`，
保留场景缺失时的纯色回退。`pool_strength` 是这轮新加的 uniform：菜单没有角色，两团脚下湿反光会变成无主亮斑。

**心流不是 BUG**：`_passive_flow()` 在 IDLE 且最近 180 帧有操作时每 24 帧 +1；超过 180 帧无输入后每 20 帧 -1，下限 15。
起手 40/46/36，先涨到 47，再以 -3/秒跌到 15，总约 13.7 秒。设计意图是防止「龟缩等对手出刀」成为最优解，
让心流成为用进废退的主动资源；依据在 `docs/dev-example/design.md` 与 `tests/unit/test_duel_sim.gd` 的 400 tick 断言。
唯一改动是把 `duel_sim.gd` 里过时的「每 30f -1（约 -2/秒）」注释改成实际数值，行为未改。

**验证**：全量 GUT **279/279（1068 asserts，35 脚本，退出码 0）**；刀光定向 21/21、83 asserts，菜单定向 4/4、24 asserts；
`--import` 退出码 0。截图 `theme-menu.png`（雨夜菜单）、`duel-fx-slash.png` 与 `duel-fx-sweep.png`（刀光外移/形变）均 1280×720。

**限制**：刀光偏移与形变幅度是首版，待人类实机手感确认；主菜单背景同样写死 1280×720 与地平线 0.96；
未加「刀光强度/雨量」设置项。美术 0% AI：未绘制新贴图，刀光仍是既有 `twirl_03`，雨夜仍是自写 shader。

## 15. P2 蓝色衣装图集（2026-11-04）

**需求**（人类原话，`m01605`）：「使用 …`skeleton_p2.png` 作为 2P 的贴图（复制文件至目录并修改 2P
骨骼绑定的贴图）」。

**为什么不是改角色档案**：本地双人（`duel_controller.gd:278`）是 `DuelSim.new(p1_data, p1_data, ...)`，
双方同角色镜像。若把 `char_b.tres` 的 `atlas_file` 改成 P2 图集，`char_b` 站 P1 时也会变蓝；而 2P 本质是
「席位」，不是角色 id。最终把换装放在 `DuelView` 的表现层：`_profile_for_side(profile, P2)` 克隆档案，
只换 `atlas_file`，按原档案 `instance_id` 缓存。`SpineFighterView._shared_data()` 的键包含 atlas 的
`instance_id`，所以同角色 P1/P2 会命中两份不同的 `SpineSkeletonDataResource`，P1 不会被污染。

**图集只改文本**：新 `skeleton_p2.atlas` 以 `skeleton.atlas` 为模板，仅首行页名改 `skeleton_p2.png`，
26 个 region 坐标完全保留；`skeleton_p2.png` 由人类提供（1323×1537，蓝色衣装），AI 未改像素/拓扑。
图集缺失或导入失败时 `_resolve_p2_atlas()` 返回 `null`，回退原图集，不阻断开局。

**验证**：`tests/integration/test_duel_view_spine.gd` 新增 1 例——双方同选 `char_a`，断言 P1 仍是
`skeleton.atlas`、P2 是 `skeleton_p2.atlas`、两者不是同一 Resource、P2 贴图页为 `skeleton_p2.png`，
动作映射与原档案一致；定向 8/8。全量 GUT **280/280（1077 asserts，35 脚本，退出码 0）**，
Spine 子集 37 例；`--import` 退出码 0。`rainy-night-preview.png` 重拍后 P1 棕、P2 蓝，已目视。

**限制**：`p2_atlas_file` 是可选覆盖，默认走约定路径；若将来要「同一角色多套衣服」，应把 P2 图集
并进档案/皮肤表，而不是继续加席位特判。P2 换装不改变动作映射与缩放，素材必须与主图集同尺寸/同 region。
美术 0% AI：贴图由人类提供，AI 只复制文件、改 atlas 页名文本与接线。

## 16. 试玩反馈 06 记录与方案（2026-11-04）

**需求**（人类原话，`m00001`）：①「建议删除残心的显示，减少玩家入门游玩的门槛」；②「占位提示加上L键位开符卡的提示」；③「均衡的符卡设计没有实际意义，建议根据其他三个符卡的表现进行重新设计」。
指令同时明确「**不改代码**」，因此本轮只做记录、诊断与方案，代码/场景/资源/本地化零改动，测试基线仍是 280/280。

**记录**：`docs/dev-example/playtest-06.md`（新）——原文、现象、落点、判定、证据索引。

**方案**：`docs/dev-example/balance-pass-06-plan.md`（新）——结论先行表、三项改法、排期、拍板项、验收清单。

**三条落点与判定**：
- 残心显示：唯一写入点是 `duel_hud.gd:354-359`（「第 N/5 场　金 X　残心 Y」）；机制在 `run_state.gd:157-170`，与显示解耦，删显示零机制风险；`test_run_state` 的机制断言不动。
- L 键提示：`duel_hud.gd:266-281` 的 `_controls_text()` 只替换 attack/guard/restart/pause，**没有 spell**；`zh_CN.json:9-11` 三条操作行也没有符卡位；教程提示 `duel_hud.gd:468-479` 没有「符卡可用」分支，`tutorial.*` 仍是 T-12~T-16 占位。
- 均衡符卡：`spell_a` 30 心流（开局净耗 25）、10f 蓄力、60f 必完美、**0 伤害**；对照 B 20 伤、C 30 伤、关底 30 伤。量化结论：净收益上限只是一次完美格挡的 +5 心流差（`PERFECT_BLOCK_FLOW_GAIN` 12 vs `BLOCK_FLOW_GAIN` 7），要回本需 5 次完美而 60f 内最多两次架；A 自己的架窗已有 24–32f，抬到 30 只对 SPREAD 档有意义；且 `_has_spell_charge()` 把 `spell_perfect_until_frame > frame` 算作蓄力，架势期间被砍中会**驱散 + 12f 惩罚**——风险与收益倒挂。人类说「没有实际意义」在数值上成立。

**方案要点**：残心显示删（HUD 整行只留场次/金币，可选结算保留「残心 +1」）；操作行加 `%s`/`%S` 替换与三条模板（文案由人类定稿），教程加「符卡可用」触发点（新键 `tutorial.spell` 占位）；符卡推荐 S2「架势 · 反斩」——保留 60f 必完美与打断风险，架势内首次格挡成功即自动反斩 10 伤穿防，触发即结束架势，复用 `spell_power_amount`/`_enter_slash` 路径，回滚开关 `counter_damage = 0`。

**未做**：任何代码改动；B2 教程触发与设置符卡改键需人类文案后再排。

**v3 修订（同日，`m00159`）**：人类要求「反斩改为自动架刀＋反斩，窗口期45F，输入攻击打断或者受击直接自动完美弹开+反斩」。方案改为 S2'「自动架刀 · 反斩」：10f 蓄力后 45f 自动架刀窗口；窗口内受击不扣血，直接完美弹开（+12 心流 / 攻方 -8、进 28f 收招）并立即反斩 10 伤穿防，窗口随即结束；窗口内按攻击则清窗口转普通出刀；clash 优先，穿防符卡是否无视列为待确认。旧 S2「首次格挡后自动反斩」被取代；`balance-pass-06-plan.md` §3 全节重写（11600 字符），§3.9 留 4 项待确认、§5 扩为 7 项拍板、附 A 增 SPELL_AUTO_GUARD_FRAMES/COUNTER_DAMAGE 45/10。
（v4 已去掉 10f 蓄力与「蓄力可被打断」路径，改为按 L 瞬间进入窗口。）



**v4 定稿（`m00201`，人类逐项拍板）**：残心只删 HUD、机制保留（结算页保留「残心 +1」）；反斩伤害 10；45f 从按 L 瞬间起算，按 L 立即把防御动画播到末帧并保持（现状 SPELL 无动画映射会回退 zhanli，故需给 8 份档案补 "SPELL": "fangyu" 并在视图加「定位末帧并暂停」）；空放返还 10 心流；穿防分两档——玩家 B/C 符卡穿透自动架刀，关底 BOSS 符卡不穿透（防收割）；操作行中文「发动符卡」，英文与教程提示等人类文案。`balance-pass-06-plan.md` 升到 v4（11910 字符），§3 全节重写、§5 改为「已定 + 剩余 4 项默认值」、§6 验收清单同步。

## 17. 实现落地：A 符卡瞬发自动架刀（2026-11-04）

**触发**（`m00261`）：「现在开始实现。」——解除 `m00001` 的「不改代码」，落地 v4。

**改动**：
- `spell_card.gd`：`SpellCardData` 加 `auto_guard_frames` / `counter_damage` / `empty_refund_flow`；`_guard_stance()` 改瞬发（`cast_frames = 0`、`amount = 0`、45 / 10 / 10），心流 30 不变。
- `fighter_state.gd`：加 `spell_auto_guard_until_frame`、`spell_refund_pending`，`reset_for_duel()` 清零。
- `duel_sim.gd`：`tick()` 在 `_advance` 后跑 `_update_spell_window`，并在两轮 slash 结算后再补一轮（同帧反斩）；`_cast_spell` 的 `GUARD_STANCE` 置窗口并进 `SPELL`；`_apply_action` 顶部「窗口内 ATTACK → 清窗口、出刀」，`SPELL` 分支忽略 `GUARD`；`_resolve_slash` 在 clash 之后、受击分支之前拦截自动架刀；新增 `_do_spell_auto_guard` / `_trigger_spell_counter` / `_end_spell_window` / `_update_spell_window` / `_is_boss_fighter`；`_do_block` 加 `forced_perfect`；`_do_hit` 扣血前清窗口（穿防打破）；`_clear_spell_charge` 补清窗口。
- `duel_hud.gd`：删顶部残心段；~~结算页新增 `_result_detail`（「残心 +N」）~~（v5 已整行删除）；操作行加 `%s` / `%S`；窗口期符卡行 `▶剩余帧`；开局 6 秒教程提示 `tutorial.spell`。
- `spine_fighter_view.gd`：窗口内 `fangyu` 定位末帧 + `time_scale 0`，结束按剩余帧恢复；8 份 `.tres` 补 `"SPELL": "fangyu"`。
- 本地化：`zh_CN` 操作行 / 教程 / `spell_a.desc` 更新；`en` 同步 `[PLACEHOLDER]`。

**踩坑**：
- JS 模板字符串行尾反斜杠吞换行，导致 `edit` 的 `old_string` 失配两次；含续行一律改 `String.raw`。
- 方案 §3.2 写 `defender.state != SPELL`，与「45f 内保持 `SPELL`」矛盾；实现取 `== SPELL + 窗口有效`，并在 plan §7 记录为笔误。
- 测试先 287/289：心流断言写成 `== 30`（窗口内按斩实际 26，另扣出刀 4）、BOSS 血量写 30（实为 40，应断 `data.max_hp`）；修正后全绿。

**验证**：GUT **289/289、1111 asserts、35 脚本、退出码 0**；`--import` 退出码 0。**未做**：人类文案替换、非 16:9 目视、实机手感确认。

**v5 修订（同日，`m00653`）**：人类要求「结算页也不应该保留『残心 +N』小字，只保留机制不变」。删除 `_result_detail` 整个 Label 及其创建/刷新分支；`test_duel_hud.gd` 的用例改为 `test_zanshin_is_hidden_everywhere_in_hud`——用 `find_children` 扫 HUD 全部可见 Label，断言局内与结算页都不含「残心」，并断言 `run.zanshin` 仍为 2（机制照常记数）。重跑全量 GUT 复核。

## 18. 心流待机恢复：反转“用进废退”（2026-11-04）

**需求**（人类原话，`m01751`）：「我意识到心流待机下跌实际上是不合适的游戏设计 —— 因为实际上玩家的心流资源恢复手段太差，如果用进废退实际上是将心流资源直接无效化了。同时这个设计也影响到了符卡决策问题 —— 无论是玩家还是AI都实际上无法主动使用符卡了。建议仍然恢复为待机恢复心流（开局前待机时间不算）。」

**为什么反转**：旧实现 IDLE 180f 内每 24f +1，超过 180f 每 20f -1、下限 15。符卡成本 30–40；出刀 -4、中刀 -15、被架/空架 -8。中局只要出过几刀、挨过一刀，心流就会跌到 15 附近，而待机只会继续扣——符卡从“每场一次的关键资源”变成“只有开局能用的资源”。AI 同理：`_try_spell` 只检查 `me.flow >= card.flow_cost`，没有恢复路径就不可能在关底中段发动。

**实现**：
- `duel_sim.gd`：删除 `NO_INPUT_GRACE`、`NO_INPUT_PENALTY_INTERVAL` 与 `_passive_flow()` 的惩罚分支；`set_input()` 不再记录 `last_input_frame`。
- `_passive_flow()` 现为：`unlocked := frame >= opening_lock_frames`；`unlocked && state == IDLE` 时每 `flow_regen_interval`（24f）`_add_flow(+1)`，否则计时清零。礼让期内不累计，礼让结束后从 0 开始——即“开局前待机不算”。
- `fighter_state.gd`：删除 `last_input_frame` 与 `reset_for_duel()` 里的复位。
- 对手“处于构时你保持不动 +1/20f、上限 +15”保持不变，仍由 `_passive_flow()` 的后半段处理。

**验证**：
- `test_opening_lock_grants_no_flow`：礼让期 179f 仍 40；结束后 30f >40 且 <48；再 140f >=41。
- `test_idle_recovers_flow_without_penalty`：400f 后 56（16 次 +1），>40。
- `test_idle_recovery_makes_spell_available_again`：20 心流待机 480f 后 >=40，按 L 进 SPELL，付 30 后被 `flow_floor` 夹到 15，次数归零。
- 定向 `duel_sim` 47/47、138 asserts；`spell_cards` 22/22、90 asserts；全量 GUT **290/290、1115 asserts、35 脚本、退出码 0**。

**限制**：待机 24f/点意味着从 15 回满 100 要约 34 秒，长于多数单场；正式节奏仍待实机确认。未改 AI 决策，也未新增“调息”按钮。旧 CHANGELOG/balance-pass 中的“用进废退”保留为历史记录，本轮明确反转。

## 19. 防御特效白→金、看破预读弧与加法发光（2026-11-04）

**需求**（人类原话，`m00720`）：「防御效果不是从白转黄而是直接黄色渲染，导致了看破这个心得实际上变得没有用了起来。这样即便有放大效果也没有直观的显示。」以及「希望光效不只是纯粹的半透明，希望能有类似发亮光的混合模式（可以尝试使用着色器实现）」。

**诊断**：看破（U05，`hint_lead=6`）的唯一可视化是收束环提前 6f 出现；但 `_update_charge_fx()` 在 `imminent` 时把整环硬切成纯金，早期/中期/临刀三个阶段颜色几乎没有可读差异，6f 提前量在视觉上被抹平。同时所有粒子用 `BLEND_MODE_ADD`（只叠亮），亮部没有白芯。

**实现**：
- `duel_view.gd` 新增 `charge_color(progress, imminent, pulse)`：白段保留到中段（`warm=smoothstep(0.12,1.0,p)`），临刀只向金 `lerp 0.7` + alpha 呼吸；头顶进度点同步 `CHARGE_WHITE.lerp(CHARGE_GOLD, progress)`。
- `_commit_state()` 增加 `lead`/`span`；`_draw_fighter()` 的 COMMIT 分支在环外加冷白预读弧（`lead/span` 比例、`lerpf(20,132,p)+12`、24 段、`Color(0.86,0.94,1.0,0.55)`）。
- 新增 `resources/shaders/glow_add.gdshader`（`blend_add` + 白芯 `smoothstep(0.35,0.95,alpha)*core` + `glow` 提亮）；`duel_fx.gd` 用 `_make_glow_material()` 统一材质，删除 `CanvasItemMaterial` 分支。

**踩坑**：
- 第一版 `capture_fx_preview.gd` 拍 read 图时背景变棕：`DuelView._flash` 被控制器 tick 清成 1.0，并覆盖手动设置的 COMMIT。先 `scene.set_physics_process(false)`，再 `view.set("_flash", 0.0)`，最后手动 `queue_redraw()`。
- 截图里 HUD 状态文本可能停留上一帧缓存，以画面中的环/弧为准。

**验证**：全量 GUT **292/292、1123 asserts、35 脚本、退出码 0**；`test_charge_color_keeps_a_white_phase_before_gold`（起手 b≈r、中段 b>0.7、末段 b<r-0.25）、`test_block_burst_and_charge_use_glow_shader`（`ShaderMaterial` + `shader == DuelFx.GLOW_SHADER`）通过。截图 `duel-fx-charge.png` / `duel-fx-read.png` / `duel-fx-preview.png` 重拍。

**限制**：发光强度（`glow=1.35`）与白芯（`core=0.5`）为首版，待人类在实机与不同分辨率目视；`alpha_gain` 尚未接设置页「特效强度」。

## 20. 角色选择抽离、双人输入方式与可见 key 补全（2026-11-05）

**需求**（人类原话，`m00002`）：①「将选择角色的功能单独抽离出来，要求选择游戏模式后单人只选玩家角色，双人需要各自选择角色」；②「补全没有本地化的可见key，例如设置页面的使用符卡」；③「允许双人对战一人使用键鼠一人使用手柄，在选择角色界面时选择输入方式。不用判断当前手柄是否接入，游戏中途插入手柄默认给1P玩家（此时键鼠为2P玩家）」。

**实现**：
- 新增 `CharacterSelectPanel`（`scripts/ui/character_select.gd` + `scenes/ui/character_select.tscn`）并注册 `PanelIds.character_select()`；主菜单删掉角色下拉框，模式确认后关闭模式面板 → 打开角色面板；单人只建 P1 角色行，双人建 P1/P2 角色行 + 两个输入方式下拉；确认写 `pending_character` / `pending_character_p2` / `pending_input_p1/p2` 后发 `character_confirmed`，菜单收到后进对局。
- `GameBootstrap` 增加 `pending_character_p2`、`pending_input_p1/p2`（默认 `keyboard`）与角色面板注册；`DuelController._start_versus()` 改用 `pending_character_p2` 生成 P2 数据，HP/初始心流取该角色。
- `InputGuide.build_remap_config()` 增加 `versus / p1_gamepad / p2_gamepad`：手柄方六动作只保留 `index 0` 的 `GUIDEInputJoyButton`（`joy_index=0`），其余槽 `_unbind`；键鼠方按 `KeyBindings.get_keys()` 占原键槽，鼠标只绑给键鼠方（P1 键鼠用原鼠标槽；P1 手柄时 P2 键鼠借 P2 原 `joy1` 槽 `index 2`）。全局 `restart/pause/offer` 仍走旧逻辑。
- `DuelController` 按 `pending_input_*` 决定 raw 手柄事件路由和 HUD 提示；`joy_connection_changed` 时，双人且双方都未选手柄则把新接入的手柄给 P1、键盘留 P2 并写回字段；唯一手柄拔掉则双方回键鼠；单人保持旧行为。
- `DuelHud.set_input_methods()` 让操作行按手柄/键鼠切换 `label_joy` / `label`，并纳入 refresh 签名。
- 中英各补 13 个键：角色面板 10 个、`settings.key_spell_p1/p2`、`state.unknown`；两语言各 165 键。

**踩坑**：
- GUIDE 的 `GUIDERemappingConfig` 只能覆盖动作已有的 `input_mappings` 槽位，不能新增槽；P2 键鼠在 P1 手柄时必须借用 P2 原有 `joy1` 槽 `index 2` 放鼠标，否则鼠标映射不会生效。
- 单人重映射有意不写鼠标槽（保持资源默认），所以断言不能只看 `config.remapped_inputs`；要回到 `context.mappings` 检查 `mapping.input_mappings[1].input` 仍是 `GUIDEInputMouseButton`。
- 菜单删角色行后 `test_menu.gd` 的按钮数从 5 改为 4；`test_duel_gamepad.gd` 原先直接设 `_raw_p1_device/_raw_p2_device`，改为设 `_p1_uses_gamepad/_p2_uses_gamepad` 才能测到新分席逻辑。
- HUD 操作行原先只按键盘键名渲染；双人时手柄方键盘槽已解绑，必须把输入方式纳入 `set_input_methods()` 和 refresh 签名，否则提示会指到不存在的键。

**验证**：全量 GUT **305/305、1235 asserts、37 脚本、5.08 s、退出码 0**；`--import` 退出码 0；`--quit-after 240` 无头冒烟退出码 0、stderr 为空；中英键集一致、`_tr/get_text` 字面 key 无缺失。

**限制**：真实手柄热插拔/手感/改键未实机复测；双方键鼠时鼠标只给 P1；角色面板不检测手柄数量；双方手柄需要两只已接入手柄，不足时先回退键鼠（第二只插入后自动补齐；暂停/重开始终可用键盘）。

### 补充：双方手柄支持（2026-11-05，m00500）

人类追加要求「双方手柄也应该做支持——你不能否定且必须支持多手柄输入」，因此废止初版「输入方式互斥」：

- `character_select.gd` 删除 `_enforce_single_gamepad()` 与 `_select_input()`；P1/P2 独立选择键鼠或手柄，允许双方同时选手柄；`_on_start_pressed()` 不再把 P2 手柄降级。
- `duel_controller.gd` 增加「面板偏好」与「实际席位」两层：`_p1_wants_gamepad/_p2_wants_gamepad` 记录玩家选择，`_resolve_gamepad_assignment(p1_wants, p2_wants, pad_count)` 按当前手柄数算出 `_p1_uses_gamepad/_p2_uses_gamepad`（双方手柄 + 2 只 → `(1,1)`，只有 1 只 → `(1,0)`，0 只 → `(0,0)`）。不足时先回退键鼠，第二只插入后自动补齐，不把玩家选择丢掉。
- `_sync_raw_devices()` 在双方手柄时把 `pads[0]` 给 P1、`pads[1]` 给 P2；`_input()` 新增 `_raw_slot_for_device(device, claim)`，按设备精确分席，松手只清对应席位的 `_guard_held/_p2_guard_held`。这修掉了旧实现「所有手柄事件都给 P1」的串台。
- `_on_joy_connection_changed()` 保留「双方都未选手柄时，中途插入默认归 P1」；已显式选择手柄时尊重选择。双方手柄拔掉一只时，若剩下的设备原本属于 P2 则保留 P2 席位，避免错绑。
- `_rebuild_input()` 显式复位 `_guard_held/_p2_guard_held`：重建后旧手柄的「按住架」已收不到松手事件，不复位会让新席位继承旧按压。
- `InputGuide._remap_versus_action()` 无需改逻辑，双方手柄时 P1 `joy_index=0`、P2 `joy_index=1`；只更新注释。设置页手柄行只显示连接数，不再暗示固定的「P2 手柄 2/键盘」。
- 本地化只改写既有 `menu.char_select_hint_versus`、`settings.gamepad_hint`、英文 `menu.mode_hint`，未新增 key，中英仍各 165 条。

**验证**：新增/改写 6 例——选人面板「双方可同时选手柄」「双方选择写回」、输入槽位「双方手柄 joy 0/1」、raw「双设备分席」「松 P1 手柄不清 P2 架子」、席位 resolver「0/1/2 只」与「双方偏好保留」。全量 GUT **311/311、1270 asserts、37 脚本、退出码 0**；`--import` 退出码 0。真实双手柄仍未实机复测。


## 21. 工作流开发经验文档（2026-11-05，m00002）

**背景**：人类要求「针对本工作区的开发经过、经验教训和工作区会话记录，总结出工作流开发经验，记录成开发文档」。此前经验是分散的：`docs/dev-contract.md` 讲规矩，`development-log.md` 讲过程，`balance-pass-*.md` 讲数值，CHANGELOG 讲交付——没有一份文档横向回答「这套工作流为什么成立」。

**做法**：
- 通读 `docs/dev-contract.md`、`development-log.md`（723 行）、`design.md`（806 行）、`CHANGELOG.md`、`docs/audit/code-audit-2026-10-21.md`、`balance-pass-01..06`、`playtest-06/07`、`ai-disclosure.md` 等。
- 解析 18 个 DSH 会话文件：按 zstd 魔数 `28 B5 2F FD` 切帧（Node 的 `zstdDecompressSync` 只解第一帧），2844 帧全部解压成功，得到约 2100 万字符 JSONL；再按事件类型统计会话数、turn 数、人类消息数、工具调用分布，导出到 `.tmp-analysis/` 供写作引用。
- 把经验抽象为两条轴：**经验 E01–E10**（是什么、为什么、怎么做、判据）与**案例 C01–C20**（真实症状 → 根因 → 处理 → 数字）；再补分阶段手册、反模式、模板、取数方法、度量体系与迁移清单。
- 文档本身按项目契约留痕：ai-disclosure 追加一行、CHANGELOG 追加一节、本节记录过程。

**产出**：`docs/workflow-development-experience.md`（1059 行，11 章 + 附录 B）。

**踩坑**：
- 用 `run_code` 写长文时，JS 双引号字符串里出现英文双引号会解析失败（`Expected ',' got ident`）；模板字符串里出现反引号会提前结束（`Expected ';', '}' or eof`）。最终改用「整段模板字符串 + ``` 占位再 `replaceAll` 回反引号」，并且内容里一律用中文引号「」。
- 用 `edit` 往 Markdown 大表格插入一行时，拿「下一行行首」当 `old_string` 会把相邻两行合并（本次在 ai-disclosure 上真的发生了：新增行与「双方手柄」行被粘成一行）。教训：表格插入要选**行尾唯一片段**作锚点，插完必须 `read` 回读校验；本次靠回读发现并修回。
- 文档里所有行号/数字都回原文核对（如 `duel_hud.gd:354-359`、`run_state.gd:157-170`、`about_panel.gd:16`），避免「总结出来的事实」再次漂移。

**验证**：GUT **311/311、1270 asserts、37 脚本、退出码 0**；`--headless --import` 退出码 0；`--quit-after 240` 无头冒烟退出码 0、stderr 无 ERROR（仅既有 WARNING）。

**限制**：文档中的「人类反馈」引用为消息编号（如 `m01481`），需在会话文件里检索原文；`.tmp-analysis/` 为临时产物，已删除。


