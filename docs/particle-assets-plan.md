# 粒子贴图素材计划（Particle Assets Plan）

> 版本 v0.2（文档修订号，不是发布版本；发布版本见根目录 `CHANGELOG.md`）
> 2026-10-23 · 性质：**内部工程/选型 + 接线记录**，不是玩家可见文档。
> 目标：把「居合剑斗」实际会发生的表现事件，对应到一组**已入库、可直接 `load()`** 的 CC0 粒子贴图，避免后期缺图或临时找图；第一批（命中 / 对刀 / 架防）已于同日接线，见 §6。
> 来源与许可见 `assets/particles/CREDITS.md`；风格约束见 `docs/dev-example/design.md`。

---

## 1. 边界

- **AI 不生成美术**：本计划只做「读素材包 → 按用途挑选 → 复制归档 → 写清对应关系 → 写接线代码」。贴图是 Kenney 的第三方 CC0 素材，AI 未绘制、未改像素、未做滤镜加工；接线只改节点与参数，不改贴图本身。
- **AI 不提前编写玩家可见文案**：本文件是工程文档，不进游戏。
- **接线范围由人类拍板**：第一批只做命中 / 对刀 / 架防三类（§6）；`duel_view.gd` 的其余 `draw_*` 灰盒（挥砍弧、符卡爆环、气环、预警环）暂时保留。
- 临时素材统一放 `temp_assets/`（已 `.gitignore` + `.gdignore`：Godot 不扫描、不入库、不进导出）；成品只放 `assets/`。

## 2. 许可与入库结论

| 项 | 结论 |
|---|---|
| 许可 | CC0 1.0，可商用、可修改、可再分发，署名非必需 |
| GameJam 合规 | 可用（主办方允许合法授权的第三方素材；CC0 无需额外授权文件，仍保留来源记录） |
| 是否入库 | **入库**（36 张，约 2.2 MB），与音频不同——音频原始库因体积与许可杂项留在 `_sources/`，粒子包只取子集且许可统一 |
| 署名 | 游戏内 credits 由人类撰写；`assets/particles/CREDITS.md` 已记录来源，提交前可直接抄一行「Particle effects: Kenney (CC0)」 |

## 3. 目录约定

参考索引图：`docs/particle-pack-sheet.png`（把原包 80 张缩略图按文件名拼成一张，**仅用于挑图**，不进游戏资源）。

```
assets/particles/
  slash/    刀光、回旋、剑气拖尾
  impact/   命中、对刀、火花、爆闪
  guard/    架防环、完美格挡
  spell/    符卡法阵、蓄力光柱、发动爆闪
  dust/     落地/收刀/冲刺扬尘与碎屑
  glow/     心流光晕与光点散粒（常驻氛围）
  CREDITS.md
```

- 目录按**用途**分，不按贴图形状分；同一张图只入库一份，跨用途时在 §5 表里注明复用。
- 文件名保留 Kenney 原名（不改名、不重编号），回查来源最省事；需要换图时删旧添新即可。

## 4. 贴图本身的规格（影响用法）

- 全部 **512×512 PNG，纯白图案 + alpha**，不是彩色图。
- 因此**颜色一律由运行时给**：`modulate`（Sprite2D/TextureRect）或粒子的 `color` / `color_ramp`。
  这正好对上现有的调色板，不用新增颜色：
  - P1 青 `Color("#6fc3ff")`、P2 珊瑚 `Color("#ff8a72")`（`duel_view.gd` 的 `COLOR_P1` / `COLOR_P2`）
  - 心流档位 灰 `#55606f` / 金 `#d8b45a` / 青绿 `#9ff0d0`（`COLOR_FLOW_LOW/MID/HIGH`）
  - 符卡 P1 紫 `#b79bff`、P2 粉 `#ff9bd0`（`COLOR_SPELL_P1/P2`）
- 图案本身是「柔边光效」，**加色混合（additive）比默认 mix 更像光**；烟雾/尘土则相反，用默认 mix + 低 alpha。
- 512×512 在 1280×720 画面里通常要缩到 40–200 px，缩放比大时会出现闪烁；若接入后看到闪烁，再对该贴图开 mipmaps（见 §5 末）。

## 5. 游戏事件 → 贴图对照

信号名取自 `scripts/duel/duel_sim.gd` / `duel_view.gd` 现有信号，事件描述与当前灰盒表现一致。

| 游戏事件 | 现有灰盒表现 | 建议贴图 | 用法要点 |
|---|---|---|---|
| 出刀（`SLASH` / `RECOVERY` 前 `slash_frames` 帧，`_is_swinging()`） | 原 `draw_arc` 半径 122、宽 6 的白色弧 | `slash/twirl_03`（**已接入**） | 月牙贴图的亮带对到 122 半径上，进度的**前扫**由 `slash_sweep.gdshader` 负责（第三批）；细节见 §6.5 / §6.6 |
| 连续斩/大回旋（连击第 2 段起） | 同上（单弧，第二批仍只用 `twirl_03`） | `slash/twirl_01` `twirl_02` | 比 `twirl_03` 更长/更短的扫尾，留给连斩或符卡斩；旋转方向随角色朝向翻 |
| 剑气/刀身残光 | 无 | `slash/trace_05` `trace_07`（旋转 90°） | 细长光带，做「收刀后残心」或空中残影；低 alpha，寿命 6–10f |
| 命中（`hit_landed`） | 全屏暖白闪 `_flash` | `impact/star_06` `star_07` `flare_01` | 命中点为原点、one_shot；`star_06/07` 做中心爆点，`flare_01` 做四角小尖；**按出刀方颜色上色**（人类拍板「攻击方制」，第一批用的是 `star_07`） |
| 对刀（`clash_happened`） | 0.8 强度闪白 | `impact/magic_03` + `impact/spark_01` `spark_02` | `magic_03`（带环的八角星）当「对刀大爆」；两簇电弧从交点向两侧甩。第一批先落地单簇 `star_09`（暖白 ×7），双簇电弧留待「刀光」批次 |
| 被架（`attack_blocked`，`perfect == false`） | 0.25 强度闪 | `guard/circle_02` + `impact/spark_07` | 架防环自防守方身上张开 + 一道横向电火花；环用 `COLOR_P2/P1` 淡色。第一批用更厚的 `circle_03` 单环（`circle_02` 在 512→170px 时环线太细） |
| 完美格挡（`attack_blocked`，`perfect == true`） | 0.45 强度闪 | `guard/light_02` + `impact/star_09` | `light_02` 是「带薄雾的环」，比 `circle_02` 更亮更贵气，正好区分完美 / 普通 |
| 架防持续（`GUARD`） | 双环 + 剩余弧长 | `guard/circle_03`（常驻）+ 现有 `draw_arc` | 常驻环只做 1 个低 alpha 的 `circle_03` 缓慢呼吸，**不要**每帧重发粒子 |
| 空架（`guard_whiffed`，扣 8 心流） | 无独立表现 | `dust/smoke_07`（小、低 alpha） | 收势带起一小团尘，给「白按了一下」一个可见反馈 |
| 符卡蓄力（`SPELL`，8–20f） | 脚下光柱 + 双环旋转 | `spell/magic_01` `magic_02`（法阵）+ `spell/light_03`（径向环）+ `spell/trace_05`（光柱） | 法阵贴地缓慢自转（`rotation` 或 `angular_velocity`），`light_03` 由外向内收，进度感比纯 `draw_arc` 更强 |
| 符卡发动（`spell_cast`） | 原 `draw_arc` 扩散环 36→366 | `guard/circle_02`（**已接入**，紫色 `#b79bff`） | **单枚**环由内向外推开（双环叠在一起会被读成 `circle_03` 的厚环），与 §6.5 同一套时间轴 |
| 符卡被打断（`spell_interrupted`） | 0.5 强度闪 | `impact/spark_01` `spark_02` + `dust/smoke_06` | 火星四散 + 一缕散掉的烟，读作「蓄力崩了」 |
| 落地 / 踏地 / 冲刺起步 | 无 | `dust/smoke_04` `smoke_09`（环形尘）+ `dust/dirt_01` `dirt_03` | `smoke_09`（环状）做冲击波方向；`dirt_*` 做碎屑抛物线 |
| 收刀（进入 `IDLE`） | 无 | `dust/smoke_07` + `slash/trace_07` | 一小团尘 + 一丝刀身余光，居合的「残心」感 |
| 心流档位氛围（`_draw_aura` 的气环） | `draw_arc` 半透明气环 | `glow/light_01` `glow/circle_05` `glow/star_05` | 常驻 `GPUParticles2D`，发射域小、寿命长（1–2s）、`amount` 低（8–16）；颜色随 `_flow_color()` 切档 |
| 心流低档 / 体力告急 | 气环变灰 | `glow/circle_05`（灰 `#55606f`，alpha 更低） | 不要新增颜色，直接复用档位色 |

### 导入设置（现状与建议）

- 现状（2026-10-23 起）：36 张贴图**已全部开出 Mipmaps**（`mipmaps/generate=true`），粒子节点配 `CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS`；`light_02` 的 `.ctex` 因此从约 40 KB 涨到 121 KB。
- 两者必须配对：只开 mipmaps 不配 `Linear Mipmap` 过滤、或反过来，都仍然会闪。
- 光效类贴图（`impact/` `spell/` `glow/`）：粒子材质 `blend_mode` 用 **Add**；`dust/` 用默认 Mix。
- 贴图本身已带 alpha，**不要**再开 `premultiplied_alpha`（Kenney 是直通 alpha）。

## 6. 接入实现（第一、二批已落地，2026-10-23）

人类拍板：范围＝**命中 / 对刀 / 架防三类**、节点＝`GPUParticles2D`、贴图＝512 + Mipmaps、尺寸＝下表、染色＝「攻击方制」、暂停＝冻结 + 换局清空 + 0–1 强度开关。

### 6.1 落地结构

- `scripts/duel/duel_fx.gd`（`class_name DuelFx extends Node2D`）+ `scenes/duel/duel_fx.tscn`；由 `duel_view.gd` 的 `_ready()` 实例化并 `add_child`，`z_index = 1`（盖住自绘角色、低于 HUD）。
- 池：`enum Kind { HIT, CLASH, BLOCK, PERFECT }` × `POOL_PER_KIND = 3` = 12 个 `GPUParticles2D`，一次性建好；`play()` 轮转槽位，**只调 `restart()`** 点火。禁止 `finished` 之后置 `emitting = true`（技能 `godot-particles` 硬规则），`finished` 回调只负责把 `emitting` 归零。
- 贴图 `preload` 成常量，节点参数一次性配好：`one_shot`、`explosiveness = 1.0`、`local_coords = false`、`visibility_rect = Rect2(-640,-640,1280,1280)`、`CanvasItemMaterial.BLEND_MODE_ADD`。
- 事件接线（`duel_view.gd`）：`hit_landed` → `burst_hit`、`clash_happened` → `burst_clash`、`attack_blocked` → `burst_block(perfect)`；全屏暖闪 alpha `0.55 → 0.28` 降为辅助。

| 特效 | 贴图 | 数量 | 寿命 | 尺寸（设计像素） | 初速 | 备注 |
|---|---|---|---|---|---|---|
| 命中 `HIT` | `impact/star_07` | 14 | 0.26s | 110 | 240–560 | 收小到 0.55 倍，避免多颗叠白 |
| 对刀 `CLASH` | `impact/star_09` | 7 | 0.30s | 140 | 320–700 | 首轮 26 颗/190px 叠成一团白，砍到 7 颗后八角星可辨 |
| 架住 `BLOCK` | `guard/circle_03` | 1 | 0.30s | 170（0.45→1.0 生长） | 0 | 放在防守方护手一侧（±36px） |
| 完美格挡 `PERFECT` | `guard/light_02` | 1 | 0.38s | 220（0.45→1.0 生长） | 0 | 薄雾环，比普通架住更亮更「贵气」 |

位置：命中点＝被打方躯干 `GROUND_Y - BODY_H * 0.62`（y = 447）；对刀＝两人中点 `x = 640`；架住＝防守方护手线 `x ± 36`。

### 6.2 染色表（人类拍板「攻击方制」，只取既有调色板）

| 事件 | 取谁的色 | 具体值 |
|---|---|---|
| 命中 | **出刀方** | `COLOR_P1 #6fc3ff` / `COLOR_P2 #ff8a72`，再 `.lightened(0.25)` |
| 架住（普通） | **防守方** | 同上，`.lightened(0.15)` |
| 对刀 | 固定（不归任一方） | 暖白 `#fff3c4`（既有 CLASH 色） |
| 完美格挡 | 固定 | 心流高档色 `#9ff0d0` |

低强度时不仅减数量，也压 `alpha`（`0.55 + 0.45 * power`），否则「轻轻碰一下」也会白一片。

### 6.3 暂停、换局与强度

- 暂停：`duel_controller._open_pause_panel()` / `_close_pause_panel()` → `DuelView.set_paused()` → `DuelFx.set_paused()`，把每个节点 `speed_scale` 置 0/1。粒子不吃 `SceneTree.paused`（暂停是控制器里的手动标志），所以必须显式冻结；暂停期间新的爆发直接丢弃，避免解冻瞬间补放。
- 换局：`DuelView.bind()` 末尾 `_fx.clear_all()`，防止上一局的残余飘进新一局。
- 强度：`DuelFx.set_strength(0.0–1.0)` 已留接口，**尚未接设置页**（0 = 完全关闭）。
- 判定层不受影响：`DuelFx` 只读位置与颜色参数，**不得**回写 `DuelSim`。

### 6.4 还没做的部分

- 扬尘、空架、收刀、心流氛围（§5 表后半）均未接线，贴图已备。
- 连斩第 2 段起换 `twirl_01/02`、符卡蓄力法阵（`magic_01/02`）、符卡被打断的火星+烟，都还没接。
- `set_strength()` 只有接口，未进设置页。

### 6.5 刀光与符卡爆环（第二批，2026-10-23）

「怎么换」的关键是**贴图不是整环**：先用脚本统计 `twirl_03` 的 alpha 分布（alpha > 96 的像素换算成极坐标），得到亮带半径 **175–231 / 512**（中位 203）、张角 **-80°…+28°**（中心 -26°、跨度 108°）。旧弧是 ±51.5°（跨度 103°）、线宽 6 的白线，两者跨度几乎一样，所以不需要改判定或弧心，只要把贴图**摆**上去：

| 问题 | 处理 |
|---|---|
| 半径对不上 | 缩放 `122 / 203 ≈ 0.60` → 亮带落在半径 105–139，压在旧 122 弧上 |
| 朝向对不上 | 贴图带中心 -26°，旋转 **+26°** 对齐到 0°（P1 朝右）；P2 再 +180° |
| 弧心对不上 | 沿用 `(cx, top + 70)`，并用 `_swing_center()` 复用 `_draw_fighter()` 的 lean/crouch（SLASH 前倾 28、RECOVERY 前倾 10、SLASH 下蹲 2），刀光贴着刀身而不是飘在旁边 |

- **为什么不用「一次性粒子」**：挥砍是持续 4–6 帧的连续态（`slash_frames` = 5/4/6，`_is_swinging()` 连收招头几帧也算），不是一瞬事件。每帧调 `pose_slash()` 摆一枚 Sprite2D，比每帧重发粒子便宜，也不会在慢帧上断掉。
- **时间轴**：进度 `(state_frame + 1) / slash_frames`，交给 `slash_sweep.gdshader` 的 `progress`（见 §6.6）；`modulate.a = 0.9 × (1 - 0.35 p²)`，收刀时只剩淡残光。
- **颜色**：保持白色，不取攻击方色——刀光是「同一把刀的轨迹」，染成方色会和「命中火花按出刀方」的读法打架。
- **符卡爆环**：`circle_02` 的环外缘在 **172 / 512**，缩放 = 目标半径 / 172；**单枚**（2026-10-23 人类反馈：两枚 0.72 倍叠加看起来像 `circle_03`）；半径 30 → 250 用 ease-out 推开，总时长 **0.55s**；alpha `(1-t)^1.4 × 0.75`，被打断乘 **0.6**。紫色 `#b79bff` 就是既有 `COLOR_SPELL_P1`，双方共用（人类指定「使用紫色」）。
- **自绘层保留**：全屏淡紫闪（`_spell_flash² × 0.10`）留作「符卡 vs 命中」的节奏区分；心流气环 / 架窗环 / 血条等判定类提示不动。
- 三者都由 `DuelFx` 持有（`_slash[2]`、`_burst_ring`、`_charge[2]`），`clear_all()` 一并隐藏，暂停时 `pose_slash()` / `burst_spell()` / `pose_charge()` 直接丢弃。

### 6.6 刀光扇形消失与起构蓄力环（第三批，2026-10-23）

**刀光为什么需要 shader**：`twirl_03` 是一整条静态月牙，Sprite2D 只能整体旋转/缩放，做不出「刀扫过的部分立刻消失」。所以加了 `resources/shaders/slash_sweep.gdshader`（`canvas_item`、`blend_add`）：贴图 UV 换极坐标得到角度 `ang`，`head` 把挥砍进度映射成刀锋角，`fade = 1 - smoothstep(-0.06, tail_span, head - ang)`——刀锋扫过的角度直接乘 0。

| 参数 | 值 | 说明 |
|---|---|---|
| `progress` | 0 → 1 | 由 `pose_slash()` 每帧写入 `ShaderMaterial` 的 `progress` |
| `head_from` / `head_to` | -1.449 / +0.506 rad（-83° → +29°） | 覆盖旧弧 ±51.5° 的可见段 |
| `tail_span` | 0.16 rad（≈9°） | 刀锋后的软过渡宽度 |
| `modulate.a` | `0.9 × (1 - 0.35 p²)` | 整体衰减交给 modulate，形态交给 shader |

踩坑：初版 `tail_span = 1.35`（77°）比月牙总张角 108° 还宽，等价于「永不塌陷」，肉眼只看到整体变淡；改成 9° 后连拍才看到 0% 全弧 → 35% 上端消失 → 70% 只剩半截 → 100% 收尾。

**起构蓄力环替代自绘收束弧**：人类指正「是替换，不是叠加」。原先 `_draw_fighter()` 里两道 `draw_arc`（主弧 + 临刀白弧）整段删除，改由 `DuelFx.pose_charge()` 摆一枚 `spell/light_03`：

| 项 | 值 |
|---|---|
| 贴图换算 | `CHARGE_TEX_RADIUS = 208`（亮带外缘 208 / 512），等比缩放 `radius / 208`，**不压扁** |
| 生长 | 半径 20 → 132 随 `progress` 线性长大 |
| 颜色 | `#fffdf7`（近白）→ `#ffc94a`（亮金）插值；alpha 0.32 → 0.82 |
| 临刀 | 半径 +5~8 呼吸，纯亮金、不掺白（掺白会洗成米色），alpha 0.82–0.92 呼吸 |
| 圆心 | 取 `_draw_aura()` 的 `(x, GROUND_Y - 90)`，与心流圆环**同心**，不吃 COMMIT 的前倾/下蹲 |
| 进度来源 | `_commit_state(fighter)` → `progress` / `imminent` / `pulse`（含「看破」`hint_lead` 只给 P2 的规则），与头顶进度圆点共用同一份 |

## 7. 未选清单与理由

素材包共 80 张（`PNG (Transparent)`），以下 44 张**没有**入库：

| 未选 | 理由 |
|---|---|
| `fire_01..02`、`flame_01..06`、`muzzle_01..05` | 枪口焰 / 烛火形态，与本作「无火器、居合剑斗」的美术方向不符；符卡也全是架势/穿防/崩势，没有火焰主题 |
| `window_01..04` | 方格/箭头/菱形网格，更像 UI 底板或弹幕网格；本作 UI 已有 110 个 SVG 图标 |
| `symbol_01`（心形）、`symbol_02`（云/花瓣形） | 单看太「可爱」，与冷色调剑斗不搭；主题「心」已在文案与系统层表达，不需要图形硬点题 |
| `scratch_01` | 三道爪痕，需要墙面/地面承托；本作 1280×720 横向舞台没有合适承载面 |
| `dirt_02`、`smoke_01` `smoke_02` `smoke_03` `smoke_05` `smoke_10` | 与已选的扬尘贴图重复度高，先取 6 张够覆盖「落地/收刀/打断」；不够再从 `temp_assets/` 补 |
| `circle_01`（实心暗圆）、`circle_04`（极淡环） | `circle_01` 是遮罩用暗圆；`circle_04` 太淡，不如 `circle_02` / `light_02` 可读 |
| `star_01..05`（除 `star_05`）、`magic_04`、`flare_01` 之外的星型重复项 | 命中闪只需 3–4 档大小；同类过多会让表现风格散 |
| `spark_03..06`、`scorch_02` `scorch_03`、`trace_01..04` `trace_06` | 电弧/拖尾方向与尺寸重复；已选够用 |
| `window_*` / `Rotated/*` / `PNG (Black background)/*` | 见上；带黑底的整套不可用 |

> 换图原则：**先看 §5 表缺哪个事件再补**，不要「多收一点备用」——包里 80 张全收会让 2.2 MB 变 4.6 MB，且未来挑图时更难判断哪张是当前在用的。

## 8. 验证记录（2026-10-23）

- 复制：36 张（`slash` 7 / `impact` 10 / `guard` 3 / `spell` 6 / `dust` 7 / `glow` 3），合计约 2.2 MB，像素未改。
- `temp_assets/.gdignore` 生效：`godot --headless --import` 后，`temp_assets/` 内 `*.import` / `*.uid` 计数为 **0**；再取包里**未被选中的 25 个代表文件**（`fire_01` `fire_02` `flame_01` `flame_06` `muzzle_01` `muzzle_05` `window_01` `window_04` `symbol_01` `symbol_02` `scratch_01` `smoke_01` `smoke_10` `dirt_02` `circle_01` `circle_04` `star_01` `star_04` `spark_03` `spark_06` `scorch_02` `scorch_03` `trace_01` `trace_04` `magic_04`）逐个反查 `.godot/imported/`，**全部查无对应 `.ctex`** —— 说明 Godot 从未扫描该目录，而不只是「没被 git 跟踪」。
- `assets/particles/**`：36 个 `*.png.import` 与对应 `.ctex` 全部生成，重新导入步骤 36 步、无报错。
- `.gitignore`：`/temp_assets/` 已加入，配合上面的 `.gdignore`，git 与 Godot 两侧都排除。
- GUT 全量（素材入库轮）：**195/195 tests、746 asserts，退出码 0**（与改动前基线一致；该轮未改任何 `.gd` 代码）。

### 8.1 粒子接线轮（2026-10-23，第二批验证）

- GUT 全量：**212/212 tests、811 asserts，退出码 0**（新增 `tests/unit/test_duel_fx.gd` 10 例 45 asserts、`tests/integration/test_duel_view_fx.gd` 7 例；单测内部调 `assert_no_new_orphans()`，不能放 `after_all`——GUT 的 orphan 计数器只在「当前测试」期间有效，放外面会报 `Nonexistent function 'size' in base 'Nil'`）。
- 导入：36 张 `.png.import` 全部 `mipmaps/generate=true`，重新导入后 `star_07`/`light_02` 的 `.ctex` 更新（`light_02` 40 KB → 121,358 B，即真的写入了 mip 链）。
- 出图：`tools/capture_fx_preview.gd`（`--windowed -s`，非 headless）→ `docs/dev-example/duel-fx-preview.png`（1280×720）。三轮迭代：① 对刀 26 颗/190px 叠成纯白团、架住环被角色身体吃掉一半；② 对刀砍到 10 颗/150px、架住换 `circle_03` 并放大到 170；③ 对刀再降到 7 颗/140px、初速提到 320–700，八角星轮廓才可辨。
- headless 冒烟：`--headless --quit-after 240`，退出码 0、stderr 无 `ERROR`。
- 校验：`DuelFx` 不读输入、不碰 `AudioStreamPlayer`、不现场搭 `GUIDEMappingContext`，`test_project_contract.gd` 的禁用模式守卫仍全绿。

### 8.2 刀光/爆环轮（2026-10-23，第三批验证）

- GUT 全量：**224/224 tests、847 asserts，退出码 0**（`test_duel_fx.gd` 10 → 18 例、`test_duel_view_fx.gd` 7 → 11 例）。
- 统计：`twirl_03` 亮带半径 175–231、张角 -80°…+28°；`circle_02` 环外缘 172——两处实测量化写进了 `duel_fx.gd` 的常量注释（`SLASH_TEX_BAND` / `SLASH_TEX_CENTER_DEG` / `SPELL_RING_TEX_RADIUS`）。
- 出图：`docs/dev-example/duel-fx-slash.png`（P1 月牙 + 右侧紫环）。第一次拍**没有刀光**——`view._process` 每帧调 `_update_slash_fx()`，而截图用的 sim 是「待机」，于是刚摆上的月牙立刻被 `hide_slash()` 收走；修法是截图工具先 `view.set_process(false)` 再手动摆位。
- headless 冒烟：`--headless --quit-after 240`，退出码 0、stderr 无 `ERROR`。
- 判定层零改动：这一批只动 `duel_view.gd` 的绘制与 `duel_fx.gd`，`duel_sim.gd` / `fighter_data.gd` 未改。

### 8.3 扇形消失与蓄力环轮（2026-10-23，第三批反馈验证）

- 贴图身份核实：`assets/particles/guard/circle_02.png` 与源包同图，MD5 `8634C6D0…`、43,380 B；「像 `circle_03`」是双环叠加造成的观感，已改单枚。
- 刀光 shader：`tail_span` 1.35 rad（77°）> 月牙张角 108° ⇒ 永不塌陷（只看到整体变淡）；改 0.16 rad（9°）后四格连拍出现「全弧 → 上端消失 → 半截 → 收尾」。逐格亮像素统计 1079 / 3093 / 2663 / 318。
- 蓄力环：`light_03` 亮带外缘 208 / 512、maxAlpha 235；等比缩放（`scale.x == scale.y`）保证正圆，圆心与 `_draw_aura()` 同为 `(x, GROUND_Y - 90)`。
- GUT 全量：**229/229 tests、871 asserts，退出码 0**；headless 240 帧冒烟无 `ERROR`。
- 出图：`docs/dev-example/duel-fx-sweep.png`（0/35/70/100% 四格）、`docs/dev-example/duel-fx-charge.png`（左起手白小、右临刀亮金胀满）。
