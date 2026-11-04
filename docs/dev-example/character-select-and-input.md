# 角色选择与双人输入方式

> 2026-11-05。对应需求：角色选择从主菜单抽离；双人各自选角色；双人可选一人键鼠一人手柄，且必须支持双方手柄；中途接入手柄默认归 P1。实现与验证数据以本节为准。

## 1. 流程

```
主菜单「开始游戏」
  → 模式选择（单人阶梯 / 本地双人）
  → 角色选择面板（CharacterSelectPanel）
      单人：只显示 P1 角色
      双人：P1/P2 各一行角色 + 各一行输入方式
  → 开始对决 → scenes/duel/duel.tscn
```

- 主菜单不再有角色下拉框；`menu.gd` 只负责打开模式面板。模式确认后关闭模式面板，把 `mode` 传给角色面板：`UIManager.open_panel(PanelIds.character_select(), {"mode": mode})`。
- 角色面板确认后发出 `character_confirmed`，主菜单关闭面板并切换场景。
- 返回键调用 `UIManager.back(UILayer.NORMAL)`，回到主菜单；再次「开始游戏」可重选模式与角色。

## 2. 面板行为

文件：`scripts/ui/character_select.gd`、`scenes/ui/character_select.tscn`。

- **单人**：只创建 P1 角色下拉，列表来自 `Unlocks.character_ids(GameBootstrap.meta)`，显示文本为 `menu.<角色 id>`；不显示输入方式（单人仍是键鼠 + 手柄并存）。
- **双人**：创建 P1/P2 两个角色下拉和两个输入方式下拉。角色默认沿用 `GameBootstrap.pending_character` / `pending_character_p2`，输入方式默认沿用 `pending_input_p1/p2`（初值均为 `keyboard`）。
- **输入自由组合**：下拉选项 metadata 为 `&"keyboard"` / `&"gamepad"`。P1/P2 独立选择，**允许双方同时选手柄**；不再有互斥回退。双方手柄时 P1 用第一只手柄、P2 用第二只。
- **确认**：写入 `GameBootstrap.pending_character`；双人再写 `pending_character_p2`、`pending_input_p1`、`pending_input_p2`；单人把两个输入字段重置为 `keyboard`，避免上一次双人的手柄选择影响单人。随后 `emit character_confirmed`。
- 面板**不检测手柄是否接入**：未接手柄也能预先选「手柄」，等中途插入后生效。

## 3. 输入槽位规则

实现在 `InputGuide.build_remap_config(context, meta, versus, p1_gamepad, p2_gamepad)`。只有双人模式重排六个玩家动作；`restart` / `pause` / `offer_1..3` 仍走原逻辑。

| 组合 | 手柄方 | 键鼠方 | 说明 |
|---|---|---|---|
| 单人 | P1 可用手柄（同时保留键鼠） | — | 旧逻辑不变，P1 三动作同时有键、鼠标、手柄槽 |
| 双人：P1 键鼠 / P2 手柄 | P2 | P1 | 手柄方三动作只保留 `index 0` 手柄；P1 保留原键槽与鼠标槽 |
| 双人：P1 手柄 / P2 键鼠 | P1 | P2 | P1 三动作只保留 `index 0` 手柄；P2 键槽 + 借用原 `joy1` 槽 `index 2` 绑鼠标 |
| 双人：双方键鼠 | — | P1 + P2 | 两人各自键槽；鼠标只绑给 P1，避免一个鼠标同时控制两边 |
| 双人：双方手柄 | P1 + P2 | — | P1 三动作只保留 `index 0` 手柄（`joy_index = 0`），P2 三动作只保留 `index 0` 手柄（`joy_index = 1`） |

- 手柄槽统一为 `GUIDEInputJoyButton`。只有一方手柄时 `joy_index = 0`（第一只已连接手柄）；双方手柄时 P1 = 0、P2 = 1。
- 键鼠方键位仍来自 `KeyBindings.get_keys()`，顺序占原键槽（P1 的 `J/K/L`，P2 的 `KP1+I` / `KP2+O` / `KP3+P`），支持设置页改键。
- 鼠标按键按动作沿用资源默认：斩左键、架右键、符卡中键；只绑一次，不会同时给两人。
- `restart` / `pause` 始终保留键盘 `R` / `Esc` 与已接入手柄的对应键，任何一方都能暂停/重开。选心得仍是键盘 `1/2/3`。
- HUD 操作行通过 `DuelHud.set_input_methods(p1_gamepad, p2_gamepad)` 切换键名：手柄方显示 `label_joy`，键鼠方显示 `label`；暂停/重开仍显示键盘键。

## 4. 中途接入手柄

`DuelController` 监听 `Input.joy_connection_changed`（GUIDE 自身也会刷新设备序号）：

- 席位由 `_resolve_gamepad_assignment(p1_wants, p2_wants, pad_count)` 计算：双人双方都选手柄时，2 只 → `(1,1)`、1 只 → `(1,0)`、0 只 → `(0,0)`；只选一方时，有至少 1 只才启用该方。**手柄不足时先回退键鼠，第二只插入后自动补齐 P2**。
- 双人模式、当前**双方都没有选择手柄**、且新手柄接入：P1 = 手柄、P2 = 键鼠，写回 `GameBootstrap.pending_input_p1/p2`，然后重建输入上下文。对应「中途插入手柄默认给 1P」。
- 已显式选择手柄（含双方手柄）时尊重选择，不强行改给 P1；新手柄只用于补足尚未满足的席位。
- 双方手柄拔掉一只：若剩下的设备原本属于 P2，保留 P2 席位，避免把剩下的手柄错绑给 P1；无手柄时双方暂时回键鼠，重新插入后恢复偏好。
- 单人模式保持旧行为：P1 键鼠 + 手柄并存，热插拔只重建上下文。
- raw 手柄事件兜底按**实际设备**分席：P1 手柄→slot 0，P2 手柄→slot 1；松手只清对应席位的架子，不会互相清空；双方键鼠时玩家动作不接，但 pause/restart 仍处理。

## 5. 本地化

中英各新增 13 个键（现各 165 键，键集一致）：

- `menu.char_select_title` / `menu.char_select_hint_solo` / `menu.char_select_hint_versus`
- `menu.p1_character` / `menu.p2_character` / `menu.p1_input` / `menu.p2_input`
- `menu.input_keyboard` / `menu.input_gamepad` / `menu.start_duel`
- `settings.key_spell_p1` / `settings.key_spell_p2`（设置页「使用符卡」两行）
- `state.unknown`（HUD 状态兜底）

这些均为功能性 UI 标签；按活动规约，AI 未生成剧情、对白、旁白、美术或音频，文案待人类最终确认，已登记在 `docs/gamejam/ai-disclosure.md`。

## 6. 验证

- 全量 GUT：**311/311、1270 asserts、37 脚本、退出码 0**。
- 相关测试：
  - `tests/integration/test_character_select.gd`：单人/双人布局、双方可同时选手柄、确认写回（6 例）。
  - `tests/unit/test_input_guide.gd`：四种双人组合（含双方手柄）的槽位类型与 index，单人保留鼠标槽，全局暂停键（6 例）。
  - `tests/integration/test_duel_versus.gd`：P2 独立角色与 HP、席位 resolver、双方手柄偏好保留。
  - `tests/integration/test_duel_gamepad.gd`：raw 分席、松手互不影响、热插拔重建（7 例）。
  - `tests/integration/test_duel_hud.gd`：操作提示跟随输入方式。
  - `tests/unit/test_i18n.gd`：新增 13 键中英齐全。
- `godot.exe --headless --path . --import` 退出码 0；`--quit-after 240` 冒烟退出码 0、stderr 为空。
- 测试预期警告仅：Spine 缺动画、MetaSave 损坏档隔离、字体 UID duplicate。

## 7. 已知边界

- 真实手柄热插拔、双手柄手感与改键尚未实机复测，当前以模拟 `InputEventJoypadButton` 与 `joy_connection_changed` 覆盖。
- 双方键鼠时鼠标只给 P1；这是刻意限制，避免一个鼠标同时驱动两边。
- 双方手柄需要两只已接入手柄：面板不检测数量，只选了一只/未插入时该席位先回退键鼠，第二只插入后自动补齐；暂停/重开始终可用键盘。
- GUIDE 的 `joy_index` 是「当前已连接手柄的枚举序号」而非固定设备 id；设备顺序变化时 GUIDE 会自行刷新，控制器的 raw 路由在每次热插拔后重建。
