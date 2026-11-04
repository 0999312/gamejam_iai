# 试玩反馈 07：防御特效与看破可读性（2026-11-04）

> 记录人类试玩反馈（`m00720`）与处理结论。本轮只改表现层，不改判定与数值。

## 反馈原文

1. 「防御效果不是从白转黄而是直接黄色渲染，导致了看破这个心得实际上变得没有用了起来。这样即便有放大效果也没有直观的显示。」
2. 「希望光效不只是纯粹的半透明，希望能有类似发亮光的混合模式（可以尝试使用着色器实现）」

## 判定

| # | 判定 | 依据 |
|---|------|------|
| 1 | 成立 | `duel_view.gd` 的 `_update_charge_fx()` 在 `imminent` 时整环硬切 `CHARGE_GOLD`，白→金渐变被压成「一亮就金」；看破（`hint_lead=6`）只让环提前 6f 出现，颜色上没有额外线索 |
| 2 | 成立 | 所有粒子/切块用 `CanvasItemMaterial(blend_mode=ADD)`，只有叠加亮度，没有白芯与「发光」感 |

## 处理

- 蓄力环：`charge_color()` 统一插值（白段保留到中段），临刀只 70% 向金 + alpha 呼吸；头顶点同步渐变。
- 看破：`_commit_state()` 暴露 `lead/span`，环外画冷白预读弧（仅 `hint_lead > 0`）。
- 发光：新增 `glow_add.gdshader`（`blend_add` + 白芯 + 1.35 提亮），`DuelFx` 统一材质。
- 判定与数值未动；`hint_lead` 仍为 6f。

## 验证

- 全量 GUT 292/292、1123 asserts、退出码 0；新增 `test_charge_color_keeps_a_white_phase_before_gold`、`test_block_burst_and_charge_use_glow_shader`。
- 截图：`duel-fx-charge.png`（左白右金）、`duel-fx-read.png`（P2 环外冷白弧、P1 无）、`duel-fx-preview.png`（命中白芯）。
- 待人类实机确认：白段长度、预读弧粗细、发光强度。
