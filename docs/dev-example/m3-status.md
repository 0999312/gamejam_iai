# M3 状态：局外存档、主菜单、本地双人基础

> 状态：2026-10-19 完成；灰盒可玩。M3 按 `docs/dev-example/design.md` §8.3 / §10 / §16.1 推进。
>
> 2026-10-20 追加平衡调整 01（心流自然恢复/出刀消耗/难度下调），见 `docs/dev-example/balance-pass-01.md`。

## 1. 本阶段交付

- **局外存档 `MetaSave`**：金币、解锁、设置、统计写入 `user://meta_save.json`；损坏/缺字段回退默认值，不阻塞游戏。
- **金币持久化**：金币从 `MetaSave` 带入 `RunState`，每场结算后写回；失败、退出、重开都不丢失。
- **主菜单**：单人阶梯 / 本地双人 / 退出；显示局外金币。
- **本地双人基础**：同一 `DuelSim`、AI 关闭、双方各 3 HP、镜像同角色；P1 J/K，P2 小键盘 1/2（或 I/O）。
- **返回菜单**：对局中 Esc 回主菜单；R 在失败/通关后重开。

## 2. 文件

| 文件 | 作用 |
|---|---|
| `scripts/core/meta_save.gd` | `MetaSave`：JSON 读写、默认值、扣费、解锁、统计 |
| `scripts/core/game_bootstrap.gd` | 启动时加载 `MetaSave`；持有 `pending_mode`（run / versus） |
| `scripts/run/run_state.gd` | 金币从存档带入 / 结算写回；失败/通关记录统计 |
| `scripts/ui/menu.gd`、`scenes/menu/menu.tscn` | 主菜单与入口 |
| `scripts/duel/duel_controller.gd` | run / versus 两种模式；P2 输入；Esc 回菜单 |
| `scripts/duel/duel_hud.gd` | 双人 HUD（隐藏阶梯信息、显示「本地双人」与 P1/P2 胜负） |
| `localization/zh_CN.json` | 菜单/双人键（`[占位]`） |

## 3. 操作

| 场景 | 按键 |
|---|---|
| 菜单 | 鼠标点击 / 回车；方向键切换焦点 |
| P1 | J 斩 / K 架 |
| P2 | 小键盘 1 斩 / 小键盘 2 架（或 I / O） |
| 通用 | R 重开（结算后）、Esc 返回菜单、1–3 选心得（单人奖励） |

## 4. 存档格式

```json
{
  "version": 1,
  "gold": 0,
  "unlocks": ["char_a"],
  "settings": {"volume_master": 0.8, "screen_shake": 1.0, "hint_level": 1},
  "stats": {"runs": 0, "clears": 0, "best_index": 0}
}
```

- 金币为局外钱包；`unlocks` 为后续 B/C 角色、起始心得槽、困难模式预留。
- 存档路径：`user://meta_save.json`；测试用临时路径，不污染玩家存档。

## 5. 验证

- GUT：**67/67 通过**（12 个脚本，214 asserts，headless）。
- 场景冒烟：`menu.tscn`、`duel.tscn` headless 均 exit 0；语言加载 59 条。
- 主菜单截图：`docs/dev-example/m3_menu.png`（占位文本，仅内部验收）。
- 双人：P2 提交 `COMMIT`、HP 3、R 重开；单人：胜利结算/三选一/失败重开保持金币。

## 6. 已知限制（M4 处理）

- 无局外解锁商店 / 角色 B/C / 困难模式入口；`MetaSave.unlocks` 与金币已就绪。
- 无暂停菜单；Esc 直接回主菜单（中途放弃不发奖励）。
- 双人仅镜像角色 A，无角色选择、无手柄。
- 无音频接入、无正式美术/文案；所有玩家可见文字仍为 `[占位]`。
- 奖励界面只做结构测试，未做像素级排版验收。

## 7. 运行

```powershell
# 主菜单（默认主场景）
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --path .

# 全部 GUT
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```
