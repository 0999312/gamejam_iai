# 平衡与手感调整 05：架防按住不生效 + 主菜单二级化

> 日期：2026-10-21
> 触发：人类试玩反馈两条（`m00819`）
> 影响模块：`duel_sim.gd`、`menu.gd`、`mode_select.gd`（新）、`settings.gd`、`panel_ids.gd`、`game_bootstrap.gd`

## 1. 现象：「敌人准备攻击时架防无反应」

玩家原话：*单人模式在敌人准备攻击时我竟然感知到无法架防（架防无反应）*。

先排除的假设：

- 不是输入没采到：`duel_controller.gd` 的 GUIDE 动作与手柄兜底都在采样，`test_duel_gamepad.gd` 覆盖；
- 不是架窗太短：NORMAL 的架窗 18–22f（300–367ms），远长于人类反应 + 按键延迟；
- 不是 `release_guard` 的 2f 收势：那只会让架势闪一下，不会「按住也没反应」。

## 2. 根因：起架只认「按下那一帧的边沿」

判定层把输入切成两类：一次性动作（`guard_pressed` 之类的边沿）与持续状态（`guard_held`）。起架的**唯一入口**是边沿：

```gdscript
# duel_sim.gd::_apply_pending_input（修复前）
if action == DuelTypes.Action.NONE:
    return
_apply_action(fighter, action)
```

`guard_pressed` 只在「这一帧从没按变成按下」时产生。以下三种情况边沿会被丢弃，而之后一直按住也**不会**再产生新边沿：

| 情况 | 边沿去哪了 |
|---|---|
| 礼让期（`opening_lock_frames = 180f`）内就按住防 | `_apply_pending_input` 开头 `if frame < opening_lock_frames: return` 直接丢帧 |
| 硬直 / 构 / 架中按下并按住 | `_apply_action` 的非 `IDLE` 分支不接受 `guard`，边沿被静默丢弃 |
| 架满上限自动收架回 `IDLE` | 手仍按着，没有新的上升沿 |

玩家的真实操作序列恰好落在这三种里：想在对刀前先架好，就在礼让期或对手起手前**提前按住**——而这正是最不产生边沿的操作。表现就是「按住防御，敌人一刀砍下来，什么都没发生」。

反过来，「偶尔能架住」的情况是玩家**松开再按一次**，制造了一个新的上升沿。

## 3. 修法：按住防御在 `IDLE` 时补一次起架

```gdscript
# duel_sim.gd::_apply_pending_input（修复后，节选）
if action == DuelTypes.Action.NONE:
    # 按住防御键是「持续意图」，不能只在按下那一帧（上升沿）生效。
    if _guard_held[fighter.side] == 1 and fighter.state == DuelTypes.State.IDLE:
        action = DuelTypes.Action.GUARD
```

### 为什么只补 `IDLE`

- **构（`COMMIT`）中不补**：构里按防是「取消出刀、转架」，这是一个明确的战术选择，必须给一次新的按下，否则玩家按住防御键就永远出不了刀——那是比原 bug 更严重的操作死角。
- **斩 / 收招中不补**：那两段是硬直，任何动作都该等硬直结束；补了等于取消硬直。

## 4. 没有采用的做法

- **加宽架窗**：架窗本身够长，问题不在长度，加宽只是让「乱按」更容易蒙中，会加剧「只架不攻」的龟缩问题。
- **只在 HUD 上加反馈**：会变成「看得见但依然架不住」，从「不知道为什么」变成「知道但做不到」，更糟。
- **给 `SLASH` 前摇加起架宽容**：会让「看到刀光再按」也成立，等于把反应窗口拉长到接近无敌，需要重新平衡全部帧数，本轮不做。

## 5. 主菜单二级化

六个入口竖排（开始 / 双人 / 商店 / 设置 / 角色 / 退出）在 720px 高度下与标题、副标题重叠。按人类指示：

- 「本地双人」并入新面板 `mode_select`（单人阶梯 / 本地双人 / 返回），主菜单的「开始游戏」打开它；
- 「关于」从主菜单移入设置页底部的动作行（清档 / 关于 / 返回）。

主菜单入口由 6 个降为 4 个，竖排高度回到标题以下的可用区。

## 6. 验证

- 新增 3 个用例（`tests/unit/test_duel_sim.gd`）：
  - `test_holding_guard_through_opening_lock_enters_guard`：礼让期按住，礼让结束后自动起架；
  - `test_holding_guard_after_attack_enters_guard`：攻击收招后仍按住，回到 `IDLE` 即起架；
  - `test_holding_guard_reenters_after_expiry`：架满上限收架后仍按住，下一帧重新起架。
- `tests/integration/test_menu.gd`：主菜单只有 4 个一级入口；`mode_select` 发出 `mode_chosen`；面板含三个按钮。
- GUT 全量 **190/190（731 asserts，退出码 0）**；headless 冒烟 240 帧无 `SCRIPT ERROR`；本地化 151 keys × 2 语言。
- **待人工复核**：按住防御在 `IDLE` 自动起架后，「先架住再找机会出刀」是否变得过强。

## 7. 遗留

- 「只架不攻对 NORMAL AI 仍 100% 胜」未解决，本轮改动可能小幅加剧（按住即架降低了架防的操作成本）。若下一轮要调，方向是给持续架防加资源惩罚（例如架中缓慢流失心流），而不是削起架判定。
