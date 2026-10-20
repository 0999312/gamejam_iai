# M4 状态说明（局外成长 / 设置 / 暂停 / 角色 / 音频）

> 日期：2026-10-20 ｜ 状态：代码完成，GUT 81/81 ｜ 性质：内部工程记录
> 设计依据：`docs/dev-example/design.md` v0.9 §8.3 / §9 / §10 / §11

## 1. 本次完成

| 模块 | 内容 |
|---|---|
| 角色 B/C | 快剑 B（前摇 16f、判定 4f、收招快、开局心流 46）；重剑 C（前摇 21f、判定 6f、HP 4、开局心流 36）；主菜单可选，未解锁时锁定 |
| 局外商店 | 角色 B 40 金币、角色 C 70、起始心得槽 50、困难模式通关后免费；金币来自 `MetaSave.gold` |
| 困难模式 | 对手 HP +1、`COMMIT` −1f；AI 反应 −2f、攻击欲 +0.1、虚招率 +0.05；商店内开关 |
| 起始心得槽 | 解锁后每局开局随机带 1 个心得（避免与三选一重复） |
| 设置页 | 主音量 / 音效 / 环境音量、静音、全屏；写入 `MetaSave.settings` 并立即应用 |
| 暂停 | 对局中 Esc 打开暂停层：继续 / 重开 / 主菜单；暂停时 `DuelSim` 与 AI 不推进 |
| 角色镜像双人 | P2 复制 P1 所选角色数据，各取该角色 HP |
| 音频 | 战斗音效、环境风声、UI 点击音；来源见 `assets/audio/CREDITS.md` |

## 2. 关键文件

| 文件 | 作用 |
|---|---|
| `scripts/core/meta_save.gd` | 存档：金币、解锁、设置、统计；损坏回退 |
| `scripts/core/unlocks.gd` | 商店目录与购买/困难模式开关 |
| `scripts/core/game_bootstrap.gd` | 注册表/I18N/存档/音频总线/设置应用 |
| `scripts/run/run_state.gd` | 角色选择、困难模式、起始心得槽、结算 |
| `scripts/duel/fighter_data.gd` | A/B/C 帧数据与 `for_character()` |
| `scripts/ui/menu.gd` / `scenes/menu/menu.tscn` | 主菜单：角色、单人、双人、商店、设置、退出 |
| `scripts/ui/shop.gd` / `scenes/ui/shop.tscn` | 商店 |
| `scripts/ui/settings.gd` / `scenes/ui/settings.tscn` | 设置页 |
| `scripts/ui/pause_menu.gd` / `scenes/ui/pause_menu.tscn` | 暂停层 |
| `scripts/duel/duel_controller.gd` | 模式切换、暂停、角色数据、音频绑定 |
| `localization/zh_CN.json` | 全部玩家可见文本（`[占位]`） |

## 3. 操作

- 主菜单：鼠标点击；角色下拉框切换；回车/空格触发当前焦点按钮。
- 单人：J 斩 / K 架；1–3 或鼠标选心得；R 重开；Esc 暂停。
- 本地双人：P1 J/K；P2 小键盘 1/2（或 I/O）；Esc 暂停。
- 设置：拖动滑条即时生效；返回主菜单自动保存。

## 4. 存档字段

`user://meta_save.json`：

```json
{
  "version": 1,
  "gold": 0,
  "unlocks": ["char_a"],
  "settings": {
    "volume_master": 0.8,
    "volume_sfx": 0.8,
    "volume_ambient": 0.7,
    "mute": false,
    "fullscreen": false,
    "hard_mode": false,
    "screen_shake": 1.0
  },
  "stats": {"runs": 0, "clears": 0, "best_index": 0}
}
```

## 5. 验证

- GUT：81/81，15 个脚本，269 asserts（headless）。
- 场景：`menu.tscn` / `duel.tscn` headless 120 帧退出码 0；无 ERROR/SCRIPT ERROR。
- 语言：`Language [zh_CN] loaded successfully with 95 entries`。
- 测试覆盖：角色数据、商店购买/解锁、设置默认/往返、暂停冻结/恢复、菜单按钮、HUD 三选一、存档损坏回退。

## 6. 已知限制

- 手柄未接；改键未做。
- 无背景音乐；环境风声为单层循环。
- 音效为 Kenney/OGA CC0 第一版，**待人类试听替换**；受击音偏卡通。
- 无正式美术/动画/文案；角色与对手均为几何体，文本全为 `[占位]`。
- 暂停只冻结模拟，已在播放的音效会自然结束。
- 困难模式数值未经过人类试玩校准。

## 7. 运行

```powershell
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --path .
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

## 8. 下一步

1. 人类试玩：难度、音效、暂停与商店手感。
2. 替换 `[占位]` 文本、角色/对手名、立绘与封面。
3. 导出 Windows 构建，在非开发机验证。
4. 更新 README、AI 披露与提交清单。
