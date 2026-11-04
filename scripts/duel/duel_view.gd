class_name DuelView
extends Node2D

## 灰盒表现层：只读取 DuelSim 的状态快照，不修改任何判定。

const GROUND_Y := 540.0
const P1_X := 430.0
const P2_X := 850.0
const BODY_W := 46.0
const BODY_H := 150.0
const HEAD_R := 18.0

const COLOR_BG := Color("#0b0e13")
const COLOR_FLOOR := Color("#2b3340")
const COLOR_P1 := Color("#6fc3ff")
const COLOR_P2 := Color("#ff8a72")
const COLOR_FLOW_LOW := Color("#55606f")
const COLOR_FLOW_MID := Color("#d8b45a")
const COLOR_FLOW_HIGH := Color("#9ff0d0")
const COLOR_SPELL_P1 := Color("#b79bff")
const COLOR_SPELL_P2 := Color("#ff9bd0")
## 起构蓄力环的两端颜色：起手近白，蓄满亮金（贴图是白的，全靠 modulate 上色）。
const CHARGE_WHITE := Color("#fffdf7")
const CHARGE_GOLD := Color("#ffc94a")

const FX_SCENE := preload("res://scenes/duel/duel_fx.tscn")
const BG_SCENE := preload("res://scenes/duel/rainy_night.tscn")
## P2 的独立图集：同一副骨架换蓝色衣装贴图。按席位而非角色 id 绑定，
## 这样同一角色站在 P2 时也变蓝，而站在 P1 时仍是原色。
const P2_ATLAS_PATH := "res://resources/spine/skeleton_p2.atlas"

var sim: DuelSim

## 角色 id → SpineFighterProfile 的显式覆盖；留空时按
## `res://resources/spine/<角色 id>.tres` 约定路径查。找不到就回退灰盒。
@export var spine_profiles: Dictionary = {}
## 可选的 P2 图集覆盖；为空时加载 P2_ATLAS_PATH。
@export var p2_atlas_file: Resource

## 雨夜背景层。它是子节点但 z_index=-1 / show_behind_parent，绘制在自绘层之后，
## 因此不会挡住角色、心流环、血条或判定提示。
var _background: ColorRect

## 粒子特效层（命中/对刀/架防），挂在自身之下，绘制顺序在自绘角色之上。
var _fx: DuelFx

## Spine 人物层：子节点比自绘层晚绘制，所以人站在心流环/血条之上；
## 没有档案或没装扩展时两个节点保持不激活，DuelView 照旧画灰盒。
var _spine_p1: SpineFighterView
var _spine_p2: SpineFighterView

## P2 图集与原档案克隆的缓存。键是原档案的 instance_id：
## 同一角色反复 bind 时复用同一个副本，SpineFighterView 不会每次重建骨架。
var _p2_atlas: Resource
var _p2_profiles: Dictionary = {}

var _flash: float = 0.0
## 符卡全屏淡紫闪的剩余量；内外爆环本身已交给 `DuelFx.burst_spell()`。
var _spell_flash: float = 0.0


func _ready() -> void:
	# 背景最先建，但靠 z_index/show_behind_parent 压在自绘层后面。
	_build_background()
	# 先建人物层、再建粒子层：同为主节点子节点时按顺序绘制，粒子才会在最上面。
	_build_spine_views()
	_fx = FX_SCENE.instantiate() as DuelFx
	add_child(_fx)
	# 允许「先 bind 再入树」（headless 截图/测试会这么用）：入树后补挂档案。
	if sim != null:
		_bind_spine()


func bind(p_sim: DuelSim) -> void:
	if sim != null:
		sim.hit_landed.disconnect(_on_hit_landed)
		sim.clash_happened.disconnect(_on_clash)
		sim.attack_blocked.disconnect(_on_blocked)
		sim.spell_cast.disconnect(_on_spell_cast)
		sim.spell_interrupted.disconnect(_on_spell_interrupted)
	sim = p_sim
	sim.hit_landed.connect(_on_hit_landed)
	sim.clash_happened.connect(_on_clash)
	sim.attack_blocked.connect(_on_blocked)
	sim.spell_cast.connect(_on_spell_cast)
	sim.spell_interrupted.connect(_on_spell_interrupted)
	# 换局时上一局的残余粒子不能飘进新一局。
	if _fx != null:
		_fx.clear_all()
	_bind_spine()
	queue_redraw()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.5)
	if _spell_flash > 0.0:
		_spell_flash = maxf(0.0, _spell_flash - delta * 1.6)
	_update_slash_fx()
	_update_charge_fx()
	_update_spine()
	queue_redraw()


## 刀光从 `_draw()` 的 `draw_arc` 搬到了 FX 层的 Sprite2D：
## 贴图是「一段月牙」，要靠位置/旋转/缩放摆到弧上，所以每帧按挥砍进度喂一次；
## 只读 `_is_swinging()`，不参与任何判定。
func _update_slash_fx() -> void:
	if _fx == null:
		return
	for side in [DuelTypes.Side.P1, DuelTypes.Side.P2]:
		var fighter: FighterState = null
		if sim != null:
			fighter = sim.p1 if side == DuelTypes.Side.P1 else sim.p2
		if fighter != null and _is_swinging(fighter):
			var span := maxf(1.0, float(fighter.data.slash_frames))
			var progress := clampf((float(fighter.state_frame) + 1.0) / span, 0.0, 1.0)
			_fx.pose_slash(side, _swing_center(fighter, _side_x(side)), progress)
		else:
			_fx.hide_slash(side)


## 与 `_draw_fighter()` 里的 cx/top 同一套前倾与下蹲量：弧心必须贴着刀身，
## 否则刀光会飘在角色旁边。
func _swing_center(fighter: FighterState, x: float) -> Vector2:
	var lean := 10.0
	var crouch := 0.0
	if fighter.state == DuelTypes.State.SLASH:
		lean = 28.0
		crouch = 2.0
	if fighter.side != DuelTypes.Side.P1:
		lean = -lean
	return Vector2(x + lean, GROUND_Y - BODY_H + crouch + 70.0)


## 「构」（攻击前摇）的蓄力环：**替代**原先在 `_draw_fighter()` 里自绘的那道
## 收束弧（2026-10-23 人类指正：是替换，不是叠第二层）。
## 2026-10-23 二次指正：要**从小长到大**、由白转亮金，且与角色背后的心流圆环同心。
## 所以圆心直接用 `_draw_aura()` 的 `(x, GROUND_Y - 90)`，不吃 COMMIT 的前倾/下蹲，
## 否则两个环会偏心。
func _update_charge_fx() -> void:
	if _fx == null:
		return
	for side in [DuelTypes.Side.P1, DuelTypes.Side.P2]:
		var fighter: FighterState = null
		if sim != null:
			fighter = sim.p1 if side == DuelTypes.Side.P1 else sim.p2
		if fighter != null and fighter.state == DuelTypes.State.COMMIT:
			var commit := _commit_state(fighter)
			var progress: float = commit["progress"]
			# 20 → 132：起手时只比角色腰宽一圈，蓄满时罩住整个身位。
			var radius := lerpf(20.0, 132.0, progress)
			# 白 → 亮金：贴图本身是白的，靠 modulate 上色，所以末段的金要够亮；
			# 但 alpha 收在 0.82 以下，否则实心光晕会把角色洗成一团金色。
			var color := charge_color(progress, bool(commit["imminent"]), float(commit["pulse"]))
			if commit["imminent"]:
				radius += 5.0 + 3.0 * float(commit["pulse"])
			_fx.pose_charge(side, _commit_center(fighter, _side_x(side)), radius, color,
					float(fighter.state_frame) * 0.06)
		else:
			_fx.hide_charge(side)


## 「构」的蓄力环颜色：全程白 → 亮金，临刀只在金上做呼吸，不再硬切纯金。
## 旧写法在 `imminent` 时直接 `color = CHARGE_GOLD`，白段被整段吞掉；
## 看破（u05）把对手的 progress 提前 6f 后，玩家只看到「更早黄」，
## 分辨不出「白→金」推进了多少——这里把白段保留到中段。
static func charge_color(progress: float, imminent: bool, pulse: float) -> Color:
	var p := clampf(progress, 0.0, 1.0)
	var warm := smoothstep(0.12, 1.0, p)
	var color := CHARGE_WHITE.lerp(CHARGE_GOLD, warm)
	color.a = 0.32 + 0.50 * p
	if imminent:
		color = color.lerp(CHARGE_GOLD.lightened(0.18), 0.7)
		color.a = 0.82 + 0.10 * clampf(pulse, 0.0, 1.0)
	return color


## 「构」的进度/预警：自绘的头顶圆点与 FX 层的蓄力环共用同一份，
## 免得两边对「还剩几帧」的判断出现分叉。
func _commit_state(fighter: FighterState) -> Dictionary:
	# 2026-10-21：「看破」心得（hint_lead）的语义是「提前看到对手的刀」，
	# 所以提前量只加在对手（P2）的环上。
	var lead := 0.0
	if sim != null and fighter.side == DuelTypes.Side.P2:
		lead = float(int(sim.mods.get("hint_lead", 0)))
	var total := maxf(1.0, float(fighter.commit_total))
	var remaining := total - float(fighter.state_frame) - lead
	return {
		"progress": clampf((float(fighter.state_frame) + lead) / total, 0.0, 1.0),
		"imminent": remaining <= float(DuelTypes.SLASH_WARN_FRAMES),
		"pulse": 0.5 + 0.5 * sin(float(fighter.state_frame) * 1.7),
		# 看破（u05）的提前帧数与本次前摇总长，供 `_draw_fighter()` 画预读弧。
		"lead": lead,
		"span": total,
	}


## 蓄力环的圆心＝心流圆环的圆心（`_draw_aura()` 的 `(x, GROUND_Y - 90)`），
## 这样两个环是同心圆；不吃 COMMIT 的前倾/下蹲，免得环跟着角色漂。
func _commit_center(_fighter: FighterState, x: float) -> Vector2:
	return Vector2(x, GROUND_Y - 90.0)


func _draw() -> void:
	# 有雨夜背景时，底色/地平线/地面全部交给 shader；仅在背景场景加载失败时
	# 回退到旧灰盒背景，保证对决仍然可读。
	if _background == null:
		draw_rect(Rect2(0, 0, 1280, 720), COLOR_BG)
		_draw_floor()
	if sim == null:
		return
	_draw_aura(sim.p1, P1_X)
	_draw_aura(sim.p2, P2_X)
	_draw_fighter(sim.p1, P1_X, COLOR_P1)
	_draw_fighter(sim.p2, P2_X, COLOR_P2)
	_draw_effect()


func _draw_floor() -> void:
	draw_line(Vector2(140, GROUND_Y), Vector2(1140, GROUND_Y), COLOR_FLOOR, 3.0)
	for i in 21:
		var x := 140.0 + i * 50.0
		var height := 10.0 if i % 2 == 0 else 5.0
		draw_line(Vector2(x, GROUND_Y), Vector2(x, GROUND_Y + height), COLOR_FLOOR, 1.0)
	# 中线提示
	draw_line(Vector2(640, 200), Vector2(640, GROUND_Y), Color(1, 1, 1, 0.04), 1.0)


func _draw_aura(fighter: FighterState, x: float) -> void:
	var flow_ratio := float(fighter.flow) / float(fighter.data.max_flow)
	var color := _flow_color(fighter.flow)
	color.a = 0.12 + flow_ratio * 0.22
	var radius := 54.0 + flow_ratio * 36.0
	draw_arc(Vector2(x, GROUND_Y - 90.0), radius, 0.0, TAU, 48, color, 2.0, true)


func _flow_color(flow: int) -> Color:
	if flow >= 67:
		return COLOR_FLOW_HIGH
	if flow >= 34:
		return COLOR_FLOW_MID
	return COLOR_FLOW_LOW


## 刀是否正扫过去。SLASH 状态只存在一个逻辑帧（命中当帧即转收招），
## 所以「收招的头 slash_frames 帧」也算挥砍期——纯表现，不读判定结果。
func _is_swinging(fighter: FighterState) -> bool:
	if fighter.state == DuelTypes.State.SLASH:
		return true
	if fighter.state != DuelTypes.State.RECOVERY:
		return false
	return fighter.state_frame < fighter.data.slash_frames


func _draw_fighter(fighter: FighterState, x: float, base_color: Color) -> void:
	var color := base_color
	var body_center := Vector2(x, GROUND_Y - BODY_H * 0.5)
	var lean := 0.0
	var crouch := 0.0

	match fighter.state:
		DuelTypes.State.COMMIT:
			lean = 14.0 if fighter.side == DuelTypes.Side.P1 else -14.0
			crouch = 6.0
			color = color.lightened(0.12)
		DuelTypes.State.SLASH:
			lean = 28.0 if fighter.side == DuelTypes.Side.P1 else -28.0
			crouch = 2.0
		DuelTypes.State.RECOVERY, DuelTypes.State.GUARD_REC:
			lean = 10.0 if fighter.side == DuelTypes.Side.P1 else -10.0
		DuelTypes.State.HITSTUN:
			lean = -26.0 if fighter.side == DuelTypes.Side.P1 else 26.0
			crouch = 16.0
			color = Color("#ff4a4a")
		DuelTypes.State.GUARD:
			lean = 4.0 if fighter.side == DuelTypes.Side.P1 else -4.0
			color = color.lightened(0.2)
		DuelTypes.State.CLASH:
			lean = 18.0 if fighter.side == DuelTypes.Side.P1 else -18.0
			color = Color("#fff3c4")
		DuelTypes.State.SPELL:
			lean = 6.0 if fighter.side == DuelTypes.Side.P1 else -6.0
			crouch = 10.0
			color = Color("#d9b3ff")
		DuelTypes.State.DOWN:
			# 战败由 Spine 的 siwang 动画接管时，不再画灰盒「倒地小人」；
			# 只有没装骨架/没映射 DOWN 的角色才回退到灰盒。
			if _draws_graybox(fighter):
				_draw_down(x, base_color)
			return

	# Spine 接管时人物由骨架自己画：灰盒的躯干/头/刀全部让位，只留叠加层。
	# 骨架的姿态来自动画，不吃灰盒的 lean/crouch，所以这两项归零，让头顶进度点、
	# 架窗线、血条都贴回骨架的实际站位。
	var spine := _is_spine_active(fighter.side)
	if spine:
		lean = 0.0
		crouch = 0.0

	var cx := x + lean
	var top := GROUND_Y - BODY_H + crouch

	if not spine:
		# 躯干与头
		draw_rect(Rect2(cx - BODY_W * 0.5, top, BODY_W, BODY_H - crouch), color, true)
		draw_circle(Vector2(cx, top - HEAD_R + 4.0), HEAD_R, color.lightened(0.15))

		# 刀
		var hand := Vector2(cx + (BODY_W * 0.35 if fighter.side == DuelTypes.Side.P1 else -BODY_W * 0.35), top + 52.0)
		var blade_len := 110.0
		var angle := -0.5 if fighter.side == DuelTypes.Side.P1 else PI + 0.5
		match fighter.state:
			DuelTypes.State.COMMIT:
				angle = -1.4 if fighter.side == DuelTypes.Side.P1 else PI + 1.4
			DuelTypes.State.SLASH:
				angle = 0.15 if fighter.side == DuelTypes.Side.P1 else PI - 0.15
			DuelTypes.State.GUARD:
				angle = -PI * 0.5
			DuelTypes.State.HITSTUN:
				angle = 0.9 if fighter.side == DuelTypes.Side.P1 else PI - 0.9
		var tip := hand + Vector2(cos(angle), sin(angle)) * blade_len
		# 出刀那一帧刀就该扫过去：SLASH 在命中当帧就转收招，只按状态画的话
		# 刀光一次都不会出现，玩家看到的就是「按下去→人一歪→对面掉血」。
		var swing := _is_swinging(fighter)
		if swing and fighter.state != DuelTypes.State.SLASH:
			angle = 0.15 if fighter.side == DuelTypes.Side.P1 else PI - 0.15
			tip = hand + Vector2(cos(angle), sin(angle)) * blade_len
		draw_line(hand, tip, Color("#dfe7f2"), 4.0, true)

	# 2026-10-23：原来这里画一段 `draw_arc(122, ±51°)` 的白色线；现在改由
	# `duel_fx.gd` 的 `pose_slash()` 用 `twirl_03` 贴图承担（加法混合的月牙），
	# 弧心/半径/进度口径与旧线一致，不再在自绘层出现。

	# 无音效时的可读性：「构」的蓄力环整段可见，越接近出刀越紧越亮。
	# 2026-10-20：原来提示点只在 progress > 0.7 才亮，20f 前摇只剩 6f（100ms），
	# 低于人类视觉反应（150–250ms），玩家「看见亮圈再按」必然来不及。
	# 2026-10-20 二次调参：环之外再加「落刀预警」——剩余 SLASH_WARN_FRAMES
	# 帧时整环转白并起脉冲，给玩家一个不需要读进度的确认点。
	# 2026-10-23：那道 `draw_arc` 收束弧已交给 `duel_fx.gd` 的 `pose_charge()`
	# （`light_03` 贴图）承担，此处只保留头顶的进度圆点；进度与预警共用
	# `_commit_state()`，保证点与环不会说两套话。
	if fighter.state == DuelTypes.State.COMMIT:
		var commit := _commit_state(fighter)
		var progress: float = commit["progress"]
		var dot := 5.0 + 7.0 * progress
		var dot_color := CHARGE_WHITE.lerp(CHARGE_GOLD, progress)
		dot_color.a = 0.55 + 0.45 * progress
		if commit["imminent"]:
			dot_color = Color(1, 1, 1, 0.9)
		# 看破（u05）的「预读弧」：环外一段冷白弧，长度＝提前帧数占前摇总长的比例。
		# 没有它时，看破只让环早一点变金/变大，玩家很难把「提前量」和普通进度分开。
		if float(commit["lead"]) > 0.0:
			var lead_ratio := clampf(float(commit["lead"]) / maxf(1.0, float(commit["span"])), 0.0, 1.0)
			var outer := lerpf(20.0, 132.0, progress) + 12.0 + 3.0 * float(commit["pulse"])
			draw_arc(Vector2(cx, GROUND_Y - 90.0), outer, -PI * 0.5,
					-PI * 0.5 + TAU * lead_ratio, 24, Color(0.86, 0.94, 1.0, 0.55), 2.0, true)
		draw_circle(Vector2(cx, top - 24.0), dot, dot_color)

	# 「架」的有效窗剩余量：亮了这么久还剩多少，玩家能直接读到。
	if fighter.state == DuelTypes.State.GUARD:
		var guard_x := cx + (36.0 if fighter.side == DuelTypes.Side.P1 else -36.0)
		draw_line(Vector2(guard_x, top + 10.0), Vector2(guard_x, GROUND_Y - 10.0), Color(1, 1, 1, 0.65), 5.0, true)
		var elapsed := fighter.state_frame - fighter.data.guard_startup
		var ratio := clampf(1.0 - float(elapsed) / maxf(1.0, float(fighter.guard_duration)), 0.0, 1.0)
		draw_arc(Vector2(guard_x, GROUND_Y - 80.0), 42.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 24,
				Color(0.72, 0.94, 1.0, 0.35 + 0.5 * ratio), 3.0, true)

	if fighter.state == DuelTypes.State.SPELL:
		# 符卡蓄力：脚下的光柱 + 围绕身体的双环，越接近发动转得越快。
		var spell_color := _spell_color(fighter.side)
		var spell_center := Vector2(cx, top + 70.0)
		var spin := float(fighter.state_frame) * 0.38
		draw_rect(Rect2(cx - 18.0, GROUND_Y - 230.0, 36.0, 230.0),
				Color(spell_color.r, spell_color.g, spell_color.b, 0.10), true)
		for i in 2:
			var ring := 52.0 + i * 18.0
			var seg := spin + i * PI
			draw_arc(spell_center, ring, seg, seg + PI * 1.35, 24,
					Color(spell_color.r, spell_color.g, spell_color.b, 0.55 - i * 0.18),
					3.0 + float(i), true)
		draw_circle(spell_center, 11.0, Color(spell_color.r, spell_color.g, spell_color.b, 0.4))
		# 蓄力进度：从外向内收的环。斩类符卡到点自动出刀，玩家必须提前看清
		# 「还有多久落下」——落刀前 SLASH_WARN_FRAMES 帧转白，与普通构的预警一致。
		if fighter.spell_pending_slash:
			var charge_ratio := clampf(float(fighter.state_frame) \
					/ maxf(1.0, float(fighter.state_duration)), 0.0, 1.0)
			var charge_radius := 108.0 - 58.0 * charge_ratio
			var charge_color := Color(spell_color.r, spell_color.g, spell_color.b,
					0.5 + 0.4 * charge_ratio)
			if fighter.state_duration - fighter.state_frame <= DuelTypes.SLASH_WARN_FRAMES:
				charge_color = Color(1, 1, 1, 0.9)
			draw_arc(spell_center, charge_radius, 0.0, TAU, 40, charge_color, 4.0, true)

	# 架势符卡的安全区：持续期间常驻一圈青白环，剩余时间用弧长表示。
	# 没有这圈的话，「必完美格挡」是纯隐形的规则，玩家感觉不到自己处在窗口里。
	if sim != null and fighter.state != DuelTypes.State.SPELL \
			and fighter.spell_perfect_until_frame > sim.frame:
		var left := float(fighter.spell_perfect_until_frame - sim.frame)
		var span := 60.0
		if fighter.spell_card != null:
			span = maxf(1.0, float(fighter.spell_card.amount))
		var ratio := clampf(left / span, 0.0, 1.0)
		draw_arc(Vector2(cx, top + 70.0), 84.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 36,
				Color(0.72, 1.0, 0.92, 0.30 + 0.45 * ratio), 3.0, true)

	_draw_hp_pips(fighter, cx, top - 52.0)
	_draw_tier_marker(fighter, cx, GROUND_Y + 26.0)


func _draw_down(x: float, color: Color) -> void:
	draw_rect(Rect2(x - 70.0, GROUND_Y - 26.0, 140.0, 26.0), color.darkened(0.25), true)
	draw_circle(Vector2(x + 78.0, GROUND_Y - 30.0), 16.0, color.darkened(0.15))


## 战败时是否还要画灰盒占位小人：Spine 未接管，或接管了但没有 DOWN 动画时画。
## 单独抽出来给测试断言「战败不再叠灰盒」，而不是靠截图猜。
func _draws_graybox(fighter: FighterState) -> bool:
	if not _is_spine_active(fighter.side):
		return true
	var view := _spine_p1 if fighter.side == DuelTypes.Side.P1 else _spine_p2
	return view == null or not view.has_animation_for_state(DuelTypes.State.DOWN)


## 血条（2026-10-21：血量 ×10 后不再是一格一点的方块，改成连续血条 + 每 10 血一道刻度）。
## 宽度固定，任何血量都能画得下；每 10 血一格刻度，方便读出「还剩几刀」。
const HP_BAR_WIDTH: float = 150.0
const HP_BAR_HEIGHT: float = 8.0
const HP_TICK_STEP: int = 10


func _draw_hp_pips(fighter: FighterState, x: float, y: float) -> void:
	var max_hp := maxi(1, fighter.data.max_hp)
	var ratio := clampf(float(fighter.hp) / float(max_hp), 0.0, 1.0)
	var bar := Rect2(x - HP_BAR_WIDTH * 0.5, y, HP_BAR_WIDTH, HP_BAR_HEIGHT)
	draw_rect(bar, Color("#2a313c"), true)
	var fill := Rect2(bar.position, Vector2(HP_BAR_WIDTH * ratio, HP_BAR_HEIGHT))
	draw_rect(fill, Color("#e8eef7"), true)
	# 每 10 血一道刻度：30 血 → 2 道，40 血 → 3 道。
	var step_ratio := float(HP_TICK_STEP) / float(max_hp)
	var tick := step_ratio
	while tick < 0.999:
		var tx := bar.position.x + HP_BAR_WIDTH * tick
		draw_line(Vector2(tx, bar.position.y), Vector2(tx, bar.position.y + HP_BAR_HEIGHT),
				Color(0.16, 0.19, 0.24, 0.9), 1.0)
		tick += step_ratio


func _draw_tier_marker(fighter: FighterState, x: float, y: float) -> void:
	var tier := DuelTypes.tier_for_flow(fighter.flow)
	var color := _flow_color(fighter.flow)
	var width := 26.0 + tier * 10.0
	draw_rect(Rect2(x - width * 0.5, y, width, 4.0), color, true)


func _draw_effect() -> void:
	_draw_spell_burst()
	if _flash <= 0.0:
		return
	# 2026-10-23：命中/对刀/架防改由粒子（`duel_fx.gd`）承担主表现，
	# 全屏暖闪降为辅助（0.55 → 0.28），避免「白一片」把粒子洗掉。
	var alpha := _flash * 0.28
	draw_rect(Rect2(0, 0, 1280, 720), Color(1.0, 0.85, 0.65, alpha), true)


## 符卡发动：扩散环已改由 `duel_fx.gd` 的 `burst_spell()`（紫色 `circle_02`）承担，
## 自绘层只留一层很淡的全屏紫光，作为「符卡」与「命中」在节奏上的区分。
func _draw_spell_burst() -> void:
	if _spell_flash <= 0.0:
		return
	var color := DuelFx.SPELL_RING_COLOR
	draw_rect(Rect2(0, 0, 1280, 720),
			Color(color.r, color.g, color.b, _spell_flash * _spell_flash * 0.10), true)


func _spell_color(side: int) -> Color:
	return COLOR_SPELL_P1 if side == DuelTypes.Side.P1 else COLOR_SPELL_P2


func _spell_origin(side: int) -> Vector2:
	return Vector2(_side_x(side), GROUND_Y - 90.0)


func _on_spell_cast(side: int, _effect: int) -> void:
	_spell_flash = 1.0
	if _fx != null:
		_fx.burst_spell(_spell_origin(side))
	queue_redraw()


func _on_spell_interrupted(side: int) -> void:
	_spell_flash = maxf(_spell_flash, 0.5)
	if _fx != null:
		# 被打断时环还没张开，和成功发动用一个强度会读成「符卡放出来了」。
		_fx.burst_spell(_spell_origin(side), 0.6)
	queue_redraw()


func _on_hit_landed(attacker_side: int, defender_side: int, _damage: int) -> void:
	_flash = 1.0
	if _fx != null:
		_fx.burst_hit(_strike_point(defender_side), _side_color(attacker_side))
	queue_redraw()


func _on_clash(_a: int, _b: int) -> void:
	_flash = 0.8
	if _fx != null:
		_fx.burst_clash(Vector2((P1_X + P2_X) * 0.5, GROUND_Y - BODY_H * 0.66))
	queue_redraw()


func _on_blocked(_attacker: int, defender_side: int, perfect: bool) -> void:
	_flash = 0.45 if perfect else 0.25
	if _fx != null:
		# 护罩环放在防守方的护手一侧（与 GUARD 状态的护手线同一位置），
		# 比放在身体正中更贴「刀被架住」的那个点。
		var guard_x := _side_x(defender_side) + (36.0 if defender_side == DuelTypes.Side.P1 else -36.0)
		_fx.burst_block(Vector2(guard_x, GROUND_Y - BODY_H * 0.63), _side_color(defender_side), perfect)
	queue_redraw()


## 雨夜背景：固定铺满 1280×720，鼠标穿透，并把 shader 的地面/角色位置
## 对齐到本脚本的 GROUND_Y / P1_X / P2_X；换分辨率或改站位时这里要同步。
func _build_background() -> void:
	if _background != null:
		return
	_background = BG_SCENE.instantiate() as ColorRect
	if _background == null:
		return
	_background.name = "RainyNight"
	_background.position = Vector2.ZERO
	_background.size = Vector2(1280.0, 720.0)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_background.show_behind_parent = true
	_background.z_index = -1
	add_child(_background)
	_apply_background_focus()


func _apply_background_focus() -> void:
	if _background == null:
		return
	var material := _background.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("ground_y", GROUND_Y / 720.0)
	material.set_shader_parameter("focus_left", P1_X / 1280.0)
	material.set_shader_parameter("focus_right", P2_X / 1280.0)


## Spine 人物层：有扩展、有档案时接管角色表现；任何一环缺失都保持灰盒。
func _build_spine_views() -> void:
	if _spine_p1 != null and _spine_p2 != null:
		return
	if not SpineFighterView.is_supported():
		return
	_spine_p1 = SpineFighterView.new()
	_spine_p1.name = "SpineP1"
	_spine_p1.position = Vector2(P1_X, GROUND_Y)
	add_child(_spine_p1)
	_spine_p2 = SpineFighterView.new()
	_spine_p2.name = "SpineP2"
	_spine_p2.position = Vector2(P2_X, GROUND_Y)
	add_child(_spine_p2)


func _bind_spine() -> void:
	if sim == null:
		return
	_build_spine_views()
	_attach_spine_profile(_spine_p1, sim.p1)
	_attach_spine_profile(_spine_p2, sim.p2)


## 给一个视图挂档案；返回 false 表示这个角色继续用灰盒。
func _attach_spine_profile(view: SpineFighterView, fighter: FighterState) -> bool:
	if view == null or fighter == null or fighter.data == null:
		return false
	var wanted := _profile_for_side(_resolve_profile(fighter.data.id), fighter.side)
	if wanted == null or not SpineFighterView.is_supported():
		view.clear()
		return false
	if view.is_active() and view.profile == wanted:
		return true
	if not view.setup(wanted):
		view.clear()
		return false
	return true


## P2 用独立图集，但沿用原档案的动作映射与缩放参数。
## 返回克隆而不是改原档案：char_b.tres 等资源被 load 缓存共享，
## 直接改 atlas 会让同一角色站在 P1 时也变成蓝色。
func _profile_for_side(profile: SpineFighterProfile, side: int) -> SpineFighterProfile:
	if profile == null or side != DuelTypes.Side.P2:
		return profile
	var atlas := _resolve_p2_atlas()
	if atlas == null or profile.atlas_file == atlas:
		return profile
	var key := profile.get_instance_id()
	var cached: Variant = _p2_profiles.get(key)
	if cached is SpineFighterProfile:
		return cached
	var p2_profile := profile.duplicate() as SpineFighterProfile
	if p2_profile == null:
		return profile
	p2_profile.atlas_file = atlas
	_p2_profiles[key] = p2_profile
	return p2_profile


## P2 图集缺失或导入失败时回退原图集，保证对局仍能开。
func _resolve_p2_atlas() -> Resource:
	if p2_atlas_file != null:
		return p2_atlas_file
	if _p2_atlas == null and ResourceLoader.exists(P2_ATLAS_PATH):
		_p2_atlas = load(P2_ATLAS_PATH)
	return _p2_atlas


## 档案查找：先看 DuelView 上显式绑定的字典（方便每局按角色换装），
## 再退回 res://resources/spine/<角色 id>.tres 的约定路径。
func _resolve_profile(id: StringName) -> SpineFighterProfile:
	for key: Variant in spine_profiles.keys():
		if String(key) == String(id):
			var value: Variant = spine_profiles[key]
			if value is SpineFighterProfile:
				return value
	if id.is_empty():
		return null
	return SpineProfiles.resolve(id)


func _update_spine() -> void:
	if sim == null:
		return
	# P1 在左、面向右；P2 在右、面向左（朝左站时由档案决定是否镜像）。
	if _spine_p1 != null and _spine_p1.is_active():
		_spine_p1.apply(sim.p1, false)
	if _spine_p2 != null and _spine_p2.is_active():
		_spine_p2.apply(sim.p2, true)


func _is_spine_active(side: int) -> bool:
	var view := _spine_p1 if side == DuelTypes.Side.P1 else _spine_p2
	return view != null and view.is_active()


## 舞台暂停时冻结粒子（含爆炸中的火星），恢复后原地继续。
func set_paused(value: bool) -> void:
	if _fx != null:
		_fx.set_paused(value)
	if _spine_p1 != null:
		_spine_p1.set_paused(value)
	if _spine_p2 != null:
		_spine_p2.set_paused(value)


func _side_color(side: int) -> Color:
	return COLOR_P1 if side == DuelTypes.Side.P1 else COLOR_P2


func _side_x(side: int) -> float:
	return P1_X if side == DuelTypes.Side.P1 else P2_X


## 命中点取被打方的躯干高度：白芯就压在角色身上，而不是脚下地面。
func _strike_point(side: int) -> Vector2:
	return Vector2(_side_x(side), GROUND_Y - BODY_H * 0.62)
