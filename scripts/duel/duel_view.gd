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

var sim: DuelSim

var _flash: float = 0.0
var _hit_side: int = -1


func bind(p_sim: DuelSim) -> void:
	if sim != null:
		sim.hit_landed.disconnect(_on_hit_landed)
		sim.clash_happened.disconnect(_on_clash)
		sim.attack_blocked.disconnect(_on_blocked)
	sim = p_sim
	sim.hit_landed.connect(_on_hit_landed)
	sim.clash_happened.connect(_on_clash)
	sim.attack_blocked.connect(_on_blocked)
	queue_redraw()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.5)
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
	draw_line(hand, tip, Color("#dfe7f2"), 4.0, true)

	if fighter.state == DuelTypes.State.SLASH:
		var arc_center := Vector2(cx, top + 70.0)
		var start := -0.9 if fighter.side == DuelTypes.Side.P1 else PI - 0.9
		var end := 0.9 if fighter.side == DuelTypes.Side.P1 else PI + 0.9
		draw_arc(arc_center, 122.0, start, end, 24, Color(1, 1, 1, 0.85), 6.0, true)

	# 无音效时的可读性：构的「气」环随前摇收束，末段亮起提示点。
	if fighter.state == DuelTypes.State.COMMIT:
		var progress := clampf(float(fighter.state_frame) / maxf(1.0, float(fighter.commit_total)), 0.0, 1.0)
		var ring_center := Vector2(cx, top + 70.0)
		var radius := 58.0 + 16.0 * progress
		draw_arc(ring_center, radius, -PI * 0.9, PI * 0.1, 28,
				Color(1.0, 0.82, 0.35, 0.15 + 0.5 * progress), 2.0 + 2.0 * progress, true)
		if progress > 0.7:
			var dot := 3.0 + 4.0 * (progress - 0.7) / 0.3
			draw_circle(Vector2(cx, top - 24.0), dot, Color(1.0, 0.9, 0.45, 0.9))

	if fighter.state == DuelTypes.State.GUARD:
		var guard_x := cx + (36.0 if fighter.side == DuelTypes.Side.P1 else -36.0)
		draw_line(Vector2(guard_x, top + 10.0), Vector2(guard_x, GROUND_Y - 10.0), Color(1, 1, 1, 0.65), 5.0, true)

	_draw_hp_pips(fighter, cx, top - 52.0)
	_draw_tier_marker(fighter, cx, GROUND_Y + 26.0)


func _draw_down(x: float, color: Color) -> void:
	draw_rect(Rect2(x - 70.0, GROUND_Y - 26.0, 140.0, 26.0), color.darkened(0.25), true)
	draw_circle(Vector2(x + 78.0, GROUND_Y - 30.0), 16.0, color.darkened(0.15))


func _draw_hp_pips(fighter: FighterState, x: float, y: float) -> void:
	var max_hp := fighter.data.max_hp
	var pip_w := 16.0
	var total := max_hp * (pip_w + 5.0)
	var start := x - total * 0.5
	for i in max_hp:
		var rect := Rect2(start + i * (pip_w + 5.0), y, pip_w, 6.0)
		draw_rect(rect, Color("#e8eef7") if i < fighter.hp else Color("#2a313c"), true)


func _draw_tier_marker(fighter: FighterState, x: float, y: float) -> void:
	var tier := DuelTypes.tier_for_flow(fighter.flow)
	var color := _flow_color(fighter.flow)
	var width := 26.0 + tier * 10.0
	draw_rect(Rect2(x - width * 0.5, y, width, 4.0), color, true)


func _draw_effect() -> void:
	if _flash <= 0.0:
		return
	var alpha := _flash * 0.55
	draw_rect(Rect2(0, 0, 1280, 720), Color(1.0, 0.85, 0.65, alpha), true)


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
