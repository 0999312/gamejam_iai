# 雨夜背景与战败表现（程序化 shader）

> 状态：**已接入**（2026-11-04）。对局背景改为 shader 实时生成的雨夜；主菜单使用同一场景、单独复制材质，
> 地平线压低到 0.96 并关闭脚下湿反光。战败由 Spine 的 `siwang` 动画接管，骨架之外不再叠旧灰盒「倒地小人」。
> 全程序化，无外部背景贴图；雨线算法仅参考 `temp_assets/shader.txt` 的分格思路。

## 1. 结论摘要

| 项 | 结论 |
|---|---|
| 需求 | 删除战败后仍显示的灰盒占位小人；把背景换成「看不清四周的雨夜」，可借鉴 `temp_assets/shader.txt` |
| 背景 | `resources/shaders/rainy_night.gdshader` + `scenes/duel/rainy_night.tscn`，对局与主菜单共用 |
| 画面 | 夜空渐变、远/近两层雨、fbm 雨雾、地面湿地反光、重暗角；中心保留角色可读性，四周压暗 |
| 接线 | `DuelView` 在 `_ready()` 先建 1280×720 背景层（`z_index=-1`、`show_behind_parent`、鼠标穿透），再把 `ground_y/focus_left/focus_right` 对齐场地常量；`Menu` 在 `_build_ui()` 清空后先建同一场景，duplicate 材质后设 `ground_y=0.96`、`pool_strength=0` |
| 战败 | `DOWN` 且档案有 `siwang`：播完停末帧、保持可见，不画灰盒；Spine 未接管或没有 DOWN 动画：回退 `_draw_down()` 剪影 |
| 测试 | 全量 GUT **280/280（1077 asserts，35 脚本，退出码 0）**；背景/战败 5 例 28 asserts，主菜单背景 1 例 24 asserts |
| 验证 | `docs/dev-example/rainy-night-preview.png`（对局中）、`rainy-night-defeat.png`（P1 战败）与 `theme-menu.png`（主菜单雨夜） |

## 2. 需求与取舍

用户要求两件事：**① 战败后不要再出现灰盒占位小人；② 背景改成「看不清四周的雨夜」**。
旧背景是一块 `#0b0e13` 纯色 + 一条地平线 + 21 根刻线；旧 `DOWN` 分支无条件画
`_draw_down()` 的 140×26 矩形 + 圆头。Spine 五动作版接入后，`siwang` 已经能把角色画成
单膝跪地，灰盒矩形反而成了叠在人物上的「影子」。

设计取舍：

- **程序化而不是贴图**：没有采购/生成背景图，全部由 `canvas_item` shader 实时算；颜色、
  雨量、暗角都能在材质面板直接调，不增加美术资产。
- **中心可读、四周吞没**：雨夜不等于全黑。角色所在的中央区域保留地平线水光与脚下湿反光，
  边缘靠 `edge_darkness` 压到接近黑，形成「看不清四周」的封闭感。
- **两层雨**：远雨更密、更慢、更细；近雨更长、更快、更亮。单层雨会像一张静止的网点，
  两层才有纵深。
- **背景层不参与输入**：`ColorRect.mouse_filter = MOUSE_FILTER_IGNORE`，避免以后加鼠标操作时
  被全屏背景挡住。

## 3. Shader 结构

文件：`resources/shaders/rainy_night.gdshader`

### 3.1 可调参数

| uniform | 默认值 | 作用 |
|---|---:|---|
| `sky_top` | `(0.010, 0.016, 0.030)` | 夜空顶部颜色 |
| `sky_horizon` | `(0.055, 0.075, 0.100)` | 地平线附近的冷灰 |
| `fog_color` | `(0.085, 0.105, 0.130)` | 低频雨雾颜色 |
| `rain_color` | `(0.62, 0.72, 0.82)` | 雨线颜色（冷白） |
| `rain_amount` | `150.0` | 横向雨线密度（屏宽内约 150 格） |
| `rain_speed` | `0.60` | 下落速度 |
| `rain_slant` | `0.20` | 雨线倾斜 |
| `rain_alpha` | `0.55` | 近雨不透明度；远雨再乘 0.6 |
| `fog_amount` | `0.48` | 雨雾混合强度 |
| `edge_darkness` | `0.94` | 四周暗角最大压暗量 |
| `ground_y` | `0.75` | 地面线，归一化 y；`DuelView` 写入 `540/720` |
| `focus_left` | `0.336` | P1 脚下湿反光中心；`DuelView` 写入 `430/1280` |
| `focus_right` | `0.664` | P2 脚下湿反光中心；`DuelView` 写入 `850/1280` |
| `pool_strength` | `1.0` | 脚下湿反光强度；主菜单复制材质后设 `0.0`，避免空台面出现两团无主反光 |

### 3.2 雨线

`rain_layer(uv, amount, speed, slant, length, width, seed)`：

1. 按 `cell = 1.0 / amount` 在 x 方向分格；
2. `offset = uv.x - uv.y * slant + seed`，用 `mod(offset, cell)` 得到格内位置；
3. `fract(sin(...)) ` 给每格一个固定随机数，决定雨线相位、长度抖动、亮度；
4. `head = fract(uv.y + rnd - TIME * speed * ...)` 让雨线循环下落；
5. `smoothstep(1.0 - streak_len, 1.0, head)` 画出拖尾；
6. `center_dist = abs(remainder / cell - 0.5) * 2.0`，`slim = 1.0 - smoothstep(0.0, width, center_dist)`
   把一格内只留中间一条细线。**`width` 是格宽比例，不是像素**；首版把它当像素用
   （`step(remainder * amount, width)`），结果整格都亮，屏幕变成一根根粗竖条。

远雨：`rain_amount * 0.68`、`rain_speed * 0.72`、长度 `0.10`、宽度 `0.060`、alpha `*0.60`；
近雨：全量密度/速度、长度 `0.28`、宽度 `0.10`、alpha 全额。两层都叠加到同一个 `col`。

### 3.3 环境层

- **夜空**：`mix(sky_top, sky_horizon, smoothstep(0.04, 0.72, uv.y))`，再在地平线附近加一层
  `exp(-pow((uv.y - 0.70) * 5.2, 2.0))` 的冷光。
- **雨雾**：4 octave `fbm`，随时间缓慢漂移；`smoothstep(0.34, 0.78, fog)` 保留团块感，
  越靠下越重（`fog_band`）。
- **地面**：从 `ground_y - 0.004` 到 `+0.035` 用 `smoothstep` 压暗；`focus_left/right` 处各加一片
  `exp(-pow((uv.x - focus) * 7.0, 2.0)) * exp(-pow((uv.y - ground_y) * 20.0, 2.0)) * pool_strength` 的湿反光。
- **地平线水光**：`exp(-abs(uv.y - ground_y) * 520.0)` 的极薄亮线，把脚底和背景分开。
- **暗角**：`p = uv * 2 - 1`，`p.x *= 0.92`，`edge = smoothstep(0.34, 1.20, length(p))`，
  `col *= mix(1.0, 1.0 - edge_darkness, edge)`。四角到 1.0，顶部中央也接近 1.0，所以画面边缘
  基本沉入黑色；中央 `edge≈0`，保留人物可读性。

> 参考文件 `temp_assets/shader.txt` 为 Brian Smith 的 MIT 示例，只借了「x 分格 + y 方向
> fract 下落 + 拖尾」的思路；本 shader 的雾、暗角、地面反光与两层雨为独立实现。
> 若后续直接复制其代码，需在仓库补 MIT 许可文本与署名。

## 4. DuelView 接线

文件：`scripts/duel/duel_view.gd`

- 第 27 行：`const BG_SCENE := preload("res://scenes/duel/rainy_night.tscn")`
- 第 37 行：`var _background: ColorRect`
- `_ready()`（第 52 行起）：先 `_build_background()`，再建 Spine、FX；背景先入树，保证
  `z_index=-1` 的层级稳定。
- `_draw()`（第 182 行起）：只在 `_background == null` 时画旧 `COLOR_BG` + `_draw_floor()`，
  作为背景场景加载失败的回退；正常时底色/地平线/地面全交给 shader。
- `_build_background()`（第 494 行起）：实例化 `rainy_night.tscn`，设 `name="RainyNight"`、
  `position=ZERO`、`size=1280×720`、`mouse_filter=IGNORE`、`show_behind_parent=true`、
  `z_index=-1`，`add_child()` 后调用 `_apply_background_focus()`。
- `_apply_background_focus()`（第 510 行起）：把 `GROUND_Y / 720.0`、`P1_X / 1280.0`、
  `P2_X / 1280.0` 写进 shader 的 `ground_y/focus_left/focus_right`。

当前常量：`GROUND_Y=540`、`P1_X=430`、`P2_X=850`。因此三个 uniform 实际为
`0.75 / 0.3359375 / 0.6640625`。**改站位或改分辨率时，`_apply_background_focus()` 必须同步改**，
否则湿反光会漂到人物旁边；这也是新增测试锁住的三项。

### 4.1 层级

```
CanvasLayer（DuelHud，layer=10）
DuelView（Node2D，自绘判定提示层）
  RainyNight（ColorRect，z_index=-1，show_behind_parent）
  SpineP1 / SpineP2（Node2D）
  DuelFx（粒子/刀光/蓄力环）
```

背景在 `DuelView` 自绘层之后、Spine 与 FX 之前；HUD 在独立 CanvasLayer 上，不会被背景遮住。

### 4.2 主菜单接线

主菜单与对局共用 `rainy_night.tscn`，但**不共用材质**：`Menu` 在 `_build_ui()` 清空子节点后先实例化背景，
再 `bg.material = bg.material.duplicate()`，把 `ground_y` 压到 `0.96`、`pool_strength` 设为 `0.0`。
原因：

- 菜单没有角色，两团脚下湿反光会变成无主亮斑；关闭 `pool_strength` 只保留地平线水光。
- 菜单内容整体偏上，地平线压到 0.96 后，底部提示仍在地面之上，不会被水光切字。
- 若直接改场景里共享的 `ShaderMaterial`，对局的 `ground_y=0.75` 与湿反光会被一起改掉；duplicate 是必须的。

背景在 `Menu` 中设 `PRESET_FULL_RECT`、`show_behind_parent`、`z_index=-1`、`mouse_filter=IGNORE`；
场景加载失败时回退纯色 `#0b0e13`。细节与测试见 `tests/integration/test_menu.gd`（4 例 24 asserts）。

## 5. 战败表现

旧逻辑：`_draw_fighter()` 的 `DuelTypes.State.DOWN` 分支无条件 `_draw_down()`，
而 `SpineFighterView` 在 `DOWN` 时隐藏骨架——所以旧版要么看到灰盒小人，要么两者都不对。

现在的两条路径：

| 条件 | 表现 |
|---|---|
| Spine 已接管，且档案/骨架有 `DOWN → siwang` | `SpineFighterView` 播 `siwang`（0.8333s），停末帧并保持 `visible`；`DuelView._draws_graybox()` 返回 `false`，不叠灰盒 |
| Spine 未接管（无扩展/无档案） | `SpineFighterView` 不激活；`_draws_graybox()` 返回 `true`，走旧 `_draw_down()` 剪影 |
| Spine 接管但档案没有 DOWN 动画 | 骨架隐藏；`_draws_graybox()` 返回 `true`，回退旧剪影（避免「两边都不画」） |

关键代码（`scripts/duel/duel_view.gd` 第 387 行起）：

```gdscript
func _draws_graybox(fighter: FighterState) -> bool:
    if not _is_spine_active(fighter.side):
        return true
    var view := _spine_p1 if fighter.side == DuelTypes.Side.P1 else _spine_p2
    return view == null or not view.has_animation_for_state(DuelTypes.State.DOWN)
```

`SpineFighterView.has_animation_for_state(state)`（第 118 行）是 `_has_state_animation()` 的公开
包装：检查档案显式键、动画名非空、骨架里确实存在该动画。没有它，`DuelView` 只能判断
「Spine 是否激活」，无法区分「有 siwang」与「旧档案没有 DOWN」，会把灰盒剪影一起吞掉。

## 6. 测试与验证

新增 `tests/integration/test_duel_view_background.gd`（4 例、23 asserts）：

1. 背景层存在、父节点正确、1280×720、`show_behind_parent`、`z_index<0`、鼠标穿透；
2. 材质引用 `rainy_night.gdshader`，且 `ground_y/focus_left/focus_right` 与场地常量一致；
3. 直接实例化 `rainy_night.tscn` 也是全屏、鼠标穿透、`z_index=-1`；
4. `DOWN` 时 P1 播 `siwang`、可见、`_draws_graybox()==false`。

另在 `tests/integration/test_duel_view_spine.gd` 增加 1 例（5 asserts）：
复制 `char_a.tres`、删掉 `animation_map["DOWN"]`，断言骨架隐藏且 `_draws_graybox()==true`，
锁住「没有 DOWN 动画时回退灰盒」的边界。

主菜单背景在 `tests/integration/test_menu.gd` 增加 1 例（24 asserts）：背景是根节点第 0 个子节点、
1280×720、`show_behind_parent`、`z_index<0`、鼠标穿透，shader 路径为 `res://resources/shaders/rainy_night.gdshader`，
`ground_y=0.96`、`pool_strength=0`，且不与对局共享材质。

命令与结果：

```powershell
& "E:/godot_learning/Godot_v4.6.2-stable_mono_win64/godot.exe" --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
```

- 全量：**280/280 passed，1077 asserts，35 脚本，退出码 0**。
- 背景定向：4/4、23 asserts；主菜单背景定向：4/4、24 asserts；Spine 接线定向：7/7。
- 仅预期 warning：缺动画测试、坏档测试；SpineSprite 的 orphan（33 槽位对象/颗）为既有问题。
- 预览图：`docs/dev-example/rainy-night-preview.png` 与 `rainy-night-defeat.png`，均 1280×720；前者随 P2 蓝色衣装图集重拍，画面为 P1 棕 / P2 蓝。
  战败图由 `tools/capture_rain_preview.gd` 在非 headless 下渲染；直接设
  `state.get_track(0).call("set_track_time", 0.8333)` 后等 3 帧，稳定停在 `siwang` 末帧。

## 7. 已知限制与后续

- **固定 1280×720**：背景尺寸与 `ground_y/focus_*` 都按当前舞台常量写死；主菜单也写死 1280×720、`ground_y=0.96`。
  换分辨率或改 `P1_X/P2_X/GROUND_Y` 时要同步改 `_apply_background_focus()`、`menu.gd` 常量与场景 `offset_right/offset_bottom`。
- **屏幕空间雨**：雨线不随相机/角色移动，也没有地面溅射、积水涟漪、闪电；当前是氛围层，
  不是可交互天气系统。
- **未做性能剖析**：4 octave fbm + 两层雨在 1280×720 下开销很小，但未在低端机测过；
  若需要，优先降 `fbm` octave 或 `rain_amount`。
- **无开关**：背景常驻，没有设置项；若玩家需要高对比度，可后续加「降低雨量/暗角」选项。
- **授权**：背景为自写 shader，无第三方贴图；参考文件仅借鉴算法思路，MIT 署名见 §3.3 注。

## 8. 文件清单

```
resources/shaders/rainy_night.gdshader      # 程序化雨夜（含 pool_strength）
scenes/duel/rainy_night.tscn                # 1280×720 ColorRect + ShaderMaterial
scripts/duel/duel_view.gd                   # 背景层、uniform 对齐、DOWN 灰盒回退
scripts/ui/menu.gd                          # 主菜单背景层、材质 duplicate、地平线 0.96
scripts/duel/spine_fighter_view.gd          # has_animation_for_state() 公开查询
tests/integration/test_duel_view_background.gd  # 4 例背景/战败
tests/integration/test_duel_view_spine.gd      # +1 例无 DOWN 映射回退
tests/integration/test_menu.gd                  # +1 例主菜单雨夜
tools/capture_rain_preview.gd               # 非 headless 预览截图工具
docs/dev-example/rainy-night-preview.png    # 对局中
docs/dev-example/rainy-night-defeat.png     # P1 战败
docs/dev-example/theme-menu.png             # 主菜单雨夜
```
