# M1 状态（灰盒可玩）

> 日期：2026-10-19｜状态：**已完成**（灰盒闭环核心）｜下一阶段：M2（心流档位调优 + AI 性格 + 音效接入）
> M2 已完成，见 `docs/dev-example/m2-status.md`。
> 本文件是内部工程记录，不是玩家文案；所有玩家可见文字仍为 `PH_` 占位。

## 1. M1 范围

- 1 位玩家（内部代号 A，均衡型）对 1 位教学对手（HP 3、前兆 20f、攻击欲 0.35、虚招 0.05、反应 320ms、开场礼让 180f）。
- 固定间距、无移动；斩 / 架 / 不动；前兆、虚招、完美格挡、刃鸣、心流三档、HP。
- 灰盒表现：胶囊角色、刀光线、心流光环、HP 短杠、HUD、命中闪白。
- GUIDE 输入接入（J 斩 / K 架 / R 重开）。
- GUT 测试：29 项（22 判定 + 4 AI + 3 场景输入）。

## 2. 文件

| 文件 | 职责 |
|------|------|
| `scripts/duel/duel_types.gd` | 枚举、心流档位偏移、状态名 |
| `scripts/duel/fighter_data.gd` | 帧数据 Resource；玩家 A / 教学对手 |
| `scripts/duel/fighter_state.gd` | 单方运行时状态、心流、缓冲 |
| `scripts/duel/duel_sim.gd` | 纯逻辑判定核心（RefCounted，60Hz 内在帧） |
| `scripts/duel/ai_profile.gd` | 对手「剑型」参数 |
| `scripts/duel/duel_ai.gd` | 教学对手决策（不读玩家输入） |
| `scripts/duel/duel_view.gd` | 灰盒绘制 |
| `scripts/duel/duel_hud.gd` | HUD（`PH_` 占位） |
| `scripts/duel/duel_controller.gd` | GUIDE 输入 → Sim → AI → 表现 |
| `scenes/duel/duel.tscn` | 主场景（`run/main_scene`） |
| `tests/unit/test_duel_sim.gd` | 判定/心流/缓冲单测 |
| `tests/unit/test_duel_ai.gd` | AI 行为单测 |
| `tests/integration/test_duel_input.gd` | GUIDE 注入输入的集成测试 |

## 3. 运行

```powershell
# 正常游玩（Windows）
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --path .

# 无头冒烟（90 帧）
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --path . res://scenes/duel/duel.tscn --quit-after 90

# 全部 GUT
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

操作：**J 斩 / K 架 / R 重开**。键位目前硬编码在 `duel_controller.gd` 顶部常量，M2 迁到 GUIDE 重映射配置。

## 4. 验证结果

- `godot --version`：`4.7.2.stable.mono.official.ed1daf0bf`。
- 全部 GUT：**29/29 通过**（headless，2026-10-19）。
- 场景无头运行 90 帧：退出码 0，无脚本错误。
- 窗口运行 + 视口截图目视：背景、角色、HUD、心流光环、教学提示均正常；AI 在礼让结束后会主动进攻。

## 5. 已知限制 / M2 待办

- 只有 1 位玩家 + 1 位对手；无阶梯、心得三选一、局外解锁、双人。
- 无音效接入（候选已在 `assets/audio/_sources/`，待人类试听选型）。
- 无正式美术/文案；HUD 与提示全为 `PH_`。
- AI 仅教学型；虚招与惩罚窗已实现，但难度曲线未调。
- 玩家输入缓冲、完美格挡、刃鸣已有单测，但**手感**需人类试玩调参。
- `project.godot` 的 `GUIDE` autoload 当前手工写入；若编辑器插件重写 autoload 段，需确认该行仍在。
- 目前无主菜单/暂停/结算界面；R 直接重开。

## 6. 下一步（M2）

1. 人类试玩，确认斩/架/心流手感与教学节奏。
2. 接入 M2 内容：5 场阶梯、10 个心得、金币/残心结算、关底二阶段。
3. 音频：从候选清单选 4 个核心音（斩/刃鸣/被架/受击）+ 风声 loop，接入 `sound_manager`。
4. 视觉：人类提供角色剪影/背景后替换灰盒；保留 `DuelView` 接口。
