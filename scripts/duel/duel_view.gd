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

var sim: DuelSim

var _flash: float = 0.0
var _hit_side: int = -1
var _spell_flash: float = 0.0
var _spell_side: int = -1


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
	queue_redraw()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.5)
	if _spell_flash > 0.0:
		_spell_flash = maxf(0.0, _spell_flash - delta * 1.6)
	queue_redraw()


func _draw() -> void:
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
			_draw_down(x, base_color)
			return

	var cx := x + lean
	var top := GROUND_Y - BODY_H + crouch

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

	if swing:
		var arc_center := Vector2(cx, top + 70.0)
		var start := -0.9 if fighter.side == DuelTypes.Side.P1 else PI - 0.9
		var end := 0.9 if fighter.side == DuelTypes.Side.P1 else PI + 0.9
		draw_arc(arc_center, 122.0, start, end, 24, Color(1, 1, 1, 0.85), 6.0, true)

	# 无音效时的可读性：「构」的收束环整段可见，越接近出刀越亮越紧。
	# 2026-10-20：原来提示点只在 progress > 0.7 才亮，20f 前摇只剩 6f（100ms），
	# 低于人类视觉反应（150–250ms），玩家「看见亮圈再按」必然来不及。
	# 2026-10-20 二次调参：收束环之外再加「落刀预警」——剩余 SLASH_WARN_FRAMES
	# 帧时整环转白并起脉冲，给玩家一个不需要读进度的确认点。
	if fighter.state == DuelTypes.State.COMMIT:
		var lead := 0.0
		if fighter.side == DuelTypes.Side.P1 and sim != null:
			lead = float(int(sim.mods.get("hint_lead", 0)))
		var total := maxf(1.0, float(fighter.commit_total))
		var progress := clampf((float(fighter.state_frame) + lead) / total, 0.0, 1.0)
		var remaining := total - float(fighter.state_frame) - lead
		var imminent := remaining <= float(DuelTypes.SLASH_WARN_FRAMES)
		var ring_center := Vector2(cx, top + 70.0)
		var radius := 96.0 - 44.0 * progress
		var ring_color := Color(1.0, 0.82, 0.35, 0.55 + 0.4 * progress)
		var ring_width := 3.0 + 3.0 * progress
		if imminent:
			# 白环 + 呼吸式加粗：玩家不需要判断「还剩几帧」，只看颜色突变。
			var pulse := 0.5 + 0.5 * sin(float(fighter.state_frame) * 1.7)
			ring_color = Color(1.0, 0.97, 0.88, 0.85 + 0.15 * pulse)
			ring_width = 6.0 + 3.0 * pulse
			draw_arc(ring_center, radius + 7.0 + 3.0 * pulse, 0.0, TAU, 40,
					Color(1, 1, 1, 0.20 + 0.25 * pulse), 2.0, true)
		draw_arc(ring_center, radius, -PI * 0.9, PI * 0.1, 32, ring_color, ring_width, true)
		var dot := 5.0 + 7.0 * progress
		var dot_color := Color(1.0, 0.9, 0.45, 0.55 + 0.45 * progress)
		if imminent:
			dot_color = Color(1, 1, 1, 0.9)
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
	var alpha := _flash * 0.55
	draw_rect(Rect2(0, 0, 1280, 720), Color(1.0, 0.85, 0.65, alpha), true)


## 符卡发动的扩散环：从发动者身上炸开一圈，颜色区分双方。
func _draw_spell_burst() -> void:
	if _spell_flash <= 0.0:
		return
	var t := 1.0 - _spell_flash
	var origin := Vector2(P1_X if _spell_side == DuelTypes.Side.P1 else P2_X, GROUND_Y - 90.0)
	var color := _spell_color(_spell_side)
	var radius := 36.0 + t * 330.0
	var ring_alpha := _spell_flash * 0.75
	draw_arc(origin, radius, 0.0, TAU, 64,
			Color(color.r, color.g, color.b, ring_alpha), 2.0 + 7.0 * _spell_flash, true)
	draw_arc(origin, radius * 0.72, 0.0, TAU, 48,
			Color(color.r, color.g, color.b, ring_alpha * 0.55), 2.0 + 3.0 * _spell_flash, true)
	draw_rect(Rect2(0, 0, 1280, 720),
			Color(color.r, color.g, color.b, _spell_flash * _spell_flash * 0.10), true)


func _spell_color(side: int) -> Color:
	return COLOR_SPELL_P1 if side == DuelTypes.Side.P1 else COLOR_SPELL_P2


func _on_spell_cast(side: int, _effect: int) -> void:
	_spell_flash = 1.0
	_spell_side = side
	queue_redraw()


func _on_spell_interrupted(side: int) -> void:
	_spell_flash = maxf(_spell_flash, 0.5)
	_spell_side = side
	queue_redraw()


func _on_hit_landed(_attacker_side: int, defender_side: int, _damage: int) -> void:
	_flash = 1.0
	_hit_side = defender_side
	queue_redraw()


func _on_clash(_a: int, _b: int) -> void:
	_flash = 0.8
	queue_redraw()


func _on_blocked(_attacker: int, _defender: int, perfect: bool) -> void:
	_flash = 0.45 if perfect else 0.25
	queue_redraw()
