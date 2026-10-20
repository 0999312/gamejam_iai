# M2 状态（5 场阶梯 + 心得三选一 + 金币/残心）

> 日期：2026-10-19｜状态：**核心闭环完成**（可跑 5 场）｜下一阶段：M3（局外存档/解锁、音频、主菜单、双人）
> 内部工程记录，不是玩家文案；玩家可见文字全部为 `[占位]` 文本，集中在 `localization/zh_CN.json`，由人类替换。

## 1. M2 范围（已完成）

- 5 场阶梯：教学 → 急性 → 老练 → 虚实 → 关底；HP 3/3/4/4/5，前兆 20/14/15/13/12f。
- 金币：每胜 10 + 剩余 HP×2 + 无伤 10 + 关底 30；失败不扣。
- 残心：每胜 +1 层、无伤再 +1、上限 3；每层下一场开局心流 +8；失败/重开清零。
- 心得池 10 个，每胜三选一（不重复）；U01–U10 已接入帧数据或 `DuelSim.mods`。
- HP 跨场：每胜回复 1（U10 回复 2，不超上限）。
- 关底二阶段：HP ≤2 时攻击欲/虚招率上升、反应与决策间隔缩短。
- HUD：阶段/金币/残心、双方 HP/心流、三选一按钮、胜负结果。
- 操作：J 斩 / K 架 / R 重开 / 1–3 选心得。
- 数据/I18N：心得用 MSF `RegistryManager` 注册（`UpgradeData`），HUD/心得文本用 `I18NManager` 查 `zh_CN.json` 键；不再在代码里硬编码 `PH_` 键名。

## 2. 新增/修改文件

| 文件 | 职责 |
|------|------|
| `scripts/run/run_state.gd` | 局内阶梯、金币、残心、HP、心得池、三选一、结算（纯逻辑） |
| `scripts/run/upgrade_data.gd` | 心得静态数据 Resource（id / I18N 键 / effect / amount） |
| `scripts/core/game_bootstrap.gd` | autoload：注册 10 个心得、加载 `zh_CN.json` |
| `localization/zh_CN.json` | 47 条 `[占位]` 文本（UI/状态/教程/心得） |
| `scripts/duel/duel_controller.gd` | 把 RunState 接入对局：每场创建 Sim、结算、三选一、重开 |
| `scripts/duel/duel_hud.gd` | 阶段/金币/残心、三选一按钮与结果文本（`PH_`） |
| `scripts/duel/fighter_data.gd` | `opponent_for_stage()`：5 位对手 HP/前兆 |
| `scripts/duel/ai_profile.gd` | `for_stage()`：5 种剑型参数 |
| `scripts/duel/duel_ai.gd` | 关底二阶段、晚架逻辑 |
| `scripts/duel/duel_sim.gd` | 心得运行时 mods（U03/U06/U07/U08/U09） |
| `tests/unit/test_run_state.gd` | 金币/残心/HP/三选一/心得数据 |
| `tests/unit/test_upgrades.gd` | 心得对判定的影响 |
| `tests/integration/test_duel_hud.gd` | HUD 三选一/结果文本 |
| `tests/integration/test_duel_run.gd` | 胜利→三选一→下一场；失败→R 重开 |
| `tests/unit/test_game_data.gd` | 注册表 10 条、I18N 文本为 `[占位]` |

## 3. 验证

- GUT：**53/53 通过**（headless，2026-10-19）。
- `duel.tscn` 无头冒烟：退出码 0，无脚本错误。
- 覆盖：初始状态、判定矩阵、心流、缓冲、虚招、刃鸣、5 场参数、金币/残心、三选一、失败重开、HUD 奖励按钮、注册表/I18N。
- UI 已用 1280×720 视口截图目视：中文用 MiSans，`[占位]` 文本正常显示；奖励界面排版仍需人类试玩确认。

## 4. 已知限制 / M3 待办

- 无局外存档与解锁 UI（金币目前只在单次运行内累计；`user://` 存档、角色 B/C、困难模式未接）。
- 无主菜单/暂停/设置；启动直接进第 1 场。
- 无音效接入（候选见 `docs/audio-assets-plan.md`，待人类试听）。
- 无正式美术/文案；HUD、心得名/描述、结果均为 `[占位]`，待人类改写 `localization/zh_CN.json`。
- 无本地双人。
- 三选一目前只支持鼠标点击与 1/2/3，无手柄导航。
- B/C 角色数据未实现；当前仅 A。
- 手感（出刀 18f、被架 32f、AI 晚架）需人类试玩确认。
