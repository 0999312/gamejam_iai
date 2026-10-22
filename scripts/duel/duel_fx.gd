class_name DuelFx
extends Node2D

## 粒子特效层：只在表现层被调用，绝不写回 `DuelSim` 的任何状态。
##
## 选型、尺寸与配色口径见 `docs/particle-assets-plan.md` §5–§6；
## 素材是 512×512 纯白 + alpha（Kenney Particle Pack，CC0），
## 因此双方共用同一批贴图，颜色一律运行时靠
## `ParticleProcessMaterial.color` 上色，不另存一套染色图。
##
## 配色约定（2026-10-23 人工拍板「攻击方制」）：
## - 命中：出刀方的颜色——一眼能看出是谁打中的；
## - 架住：防守方的颜色——一眼能看出是谁在架；
## - 对刀：固定暖白 `#fff3c4`（既有 CLASH 色），表示「双方同时」；
## - 完美格挡：心流高档色 `#9ff0d0`，与普通格挡的方色形成对比。
## 以上颜色全部取自 `duel_view.gd` 现有调色板，没有新增颜色。

enum Kind { HIT, CLASH, BLOCK, PERFECT }

## 每种特效预建几个节点。one-shot 寿命 0.26–0.38s，最长连击间隔也够用；
## 超出时轮转复用旧节点，绝不在战斗帧里 `PackedScene.instantiate()`。
const POOL_PER_KIND := 3

## 贴图边长，粒子 scale = 目标尺寸 / 512。
const TEX_SIZE := 512.0

const TEX_HIT: Texture2D = preload("res://assets/particles/impact/star_07.png")
const TEX_CLASH: Texture2D = preload("res://assets/particles/impact/star_09.png")
const TEX_BLOCK: Texture2D = preload("res://assets/particles/guard/circle_03.png")
const TEX_PERFECT: Texture2D = preload("res://assets/particles/guard/light_02.png")

## 刀光：`twirl_03` 是「一段固定月牙」，不是可缩放的整环，
## 因此只能当贴图摆到挥砍弧上（见 `pose_slash`），不能像环那样长大。
const TEX_SLASH: Texture2D = preload("res://assets/particles/slash/twirl_03.png")
## 刀光的扇形消失由 shader 做：只留刀锋附近的窗口，扫过的部分塌掉。
const SLASH_SHADER: Shader = preload("res://resources/shaders/slash_sweep.gdshader")
## 符卡爆环：`circle_02` 是细环，按「环半径 = 目标半径」缩放。
const TEX_SPELL_RING: Texture2D = preload("res://assets/particles/guard/circle_02.png")
## 「构」（攻击前摇）的蓄力环：**代替** `duel_view.gd` 原先自绘的那道收束弧，
## 不是叠在角色身上的第二层。用 `light_03`（同心光环，最亮处 alpha 235/255）
## 是因为 `star_03` 太淡、在灰盒背景上读不出来（2026-10-23 人类反馈）。
const TEX_CHARGE: Texture2D = preload("res://assets/particles/spell/light_03.png")

## 实测（alpha > 96 的像素）：twirl_03 的亮带在半径 175–231 / 512、
## 张角 -80°…+28°（中心 -26°）。据此两个常数把贴图对到旧的 122 半径弧上。
const SLASH_TEX_BAND := 203.0
const SLASH_TEX_CENTER_DEG := 26.0
## 与旧 `draw_arc` 同半径，弧心也沿用「躯干上方 70」。
const SLASH_RADIUS := 122.0

## circle_02 的环外缘在 172 / 512，缩放系数 = 目标半径 / 172。
const SPELL_RING_TEX_RADIUS := 172.0
const SPELL_BURST_TIME := 0.55
## 只放一枚环：内外两枚同贴图叠在一起会被读成「厚双环」（`circle_03`），
## 与人类指定的「circle_02 细环」不符。
const SPELL_RING_START := 30.0
const SPELL_RING_END := 250.0
const SPELL_RING_COLOR := Color("#b79bff")

## `light_03` 的亮带外缘在 208 / 512，等比缩放 = 目标半径 / 208；
## 等比缩放（不压扁）保证屏幕上是一枚正圆，不做任何扭曲。
const CHARGE_TEX_RADIUS := 208.0

## 对刀是「双方同时」，不归任何一方，用既有 CLASH 暖白。
const CLASH_COLOR := Color("#fff3c4")
## 完美格挡借心流高档色（`duel_view.gd` 的 `COLOR_FLOW_HIGH`）。
const PERFECT_COLOR := Color("#9ff0d0")

var _paused: bool = false
var _strength: float = 1.0
var _nodes: Array[GPUParticles2D] = []
var _base_amount: PackedInt32Array = PackedInt32Array()
var _cursor: PackedInt32Array = PackedInt32Array()
## 挥砍月牙、符卡爆环与「构」法阵是「连续态 → 贴图」，不占粒子池。
var _slash: Array[Sprite2D] = []
var _burst_ring: Sprite2D
var _burst_t: float = -1.0
var _burst_origin: Vector2 = Vector2.ZERO
var _burst_power: float = 1.0
var _charge: Array[Sprite2D] = []


func _ready() -> void:
	# 角色与地面由 DuelView 自绘，粒子要盖在上面；HUD 是另一个节点，仍在其上。
	z_index = 1
	_cursor.resize(Kind.size())
	for kind in Kind.size():
		var spec := _spec_for(kind)
		for slot in POOL_PER_KIND:
			var node := _make_node(kind, spec, slot)
			add_child(node)
			_nodes.append(node)
			_base_amount.append(int(spec["amount"]))
	_build_sprites()


func _process(delta: float) -> void:
	if _burst_t < 0.0 or _paused:
		return
	_burst_t += delta
	var t := clampf(_burst_t / SPELL_BURST_TIME, 0.0, 1.0)
	# 先快后慢地推开：起手那一下最亮，尾巴留着余光。
	var ease_out := 1.0 - pow(1.0 - t, 2.0)
	var alpha := pow(1.0 - t, 1.5) * 0.62 * _burst_power
	_pose_ring(_burst_ring, _burst_origin, lerpf(SPELL_RING_START, SPELL_RING_END, ease_out), alpha)
	if t >= 1.0:
		_burst_t = -1.0
		_burst_ring.visible = false


func _build_sprites() -> void:
	_slash.append(_make_slash_sprite("SlashP1"))
	_slash.append(_make_slash_sprite("SlashP2"))
	_burst_ring = _make_sprite(TEX_SPELL_RING, "SpellRing")
	_charge.append(_make_sprite(TEX_CHARGE, "ChargeP1"))
	_charge.append(_make_sprite(TEX_CHARGE, "ChargeP2"))


## 刀光用 ShaderMaterial（扇形消失），因此不能复用 `_make_sprite` 的混合材质。
func _make_slash_sprite(sprite_name: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = sprite_name
	sprite.texture = TEX_SLASH
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = SLASH_SHADER
	sprite.material = shader_mat
	sprite.visible = false
	add_child(sprite)
	return sprite


func _make_sprite(tex: Texture2D, sprite_name: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = sprite_name
	sprite.texture = tex
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = blend
	sprite.visible = false
	add_child(sprite)
	return sprite


## 挥砍弧（每帧由 `DuelView` 按 `_is_swinging()` 喂进来）：
## - 位置＝旧弧心，缩放＝122 / 203 ≈ 0.60，月牙正好压在 122 半径上；
## - 旋转＝贴图带中心从 -26° 转到出刀方向（P1 朝右 0°，P2 朝左 180°），
##   再随进度小幅前扫 10°，读作「刀在走」；
## - alpha 随进度 quadratic 淡出，收刀帧不会「啪」地消失；
## - `progress` 同时喂给 shader，让月牙按扇形从刀尾一侧塌掉（见 `slash_sweep.gdshader`）。
func pose_slash(side: int, center: Vector2, progress: float) -> void:
	if _paused:
		return
	var sprite := _slash[0 if side == DuelTypes.Side.P1 else 1]
	var p := clampf(progress, 0.0, 1.0)
	var base := 0.0 if side == DuelTypes.Side.P1 else PI
	sprite.visible = true
	sprite.position = center
	sprite.rotation = base + deg_to_rad(SLASH_TEX_CENTER_DEG) + lerpf(-0.17, 0.12, p)
	sprite.scale = Vector2.ONE * (SLASH_RADIUS / SLASH_TEX_BAND)
	# 消失主要交给 shader 的扇形塌陷，这里只补一点整体淡化，避免末帧硬切。
	sprite.modulate = Color(1.0, 1.0, 1.0, 0.9 * (1.0 - 0.35 * p * p))
	var shader_mat := sprite.material as ShaderMaterial
	if shader_mat != null:
		shader_mat.set_shader_parameter("progress", p)


func hide_slash(side: int) -> void:
	_slash[0 if side == DuelTypes.Side.P1 else 1].visible = false


## 「构」（攻击前摇）的脚下法阵：每帧由 `DuelView` 按 COMMIT 状态喂进度。
## 压扁 y 让它躺在脚下；随进度微微张开、加亮，旋转半圈读作「气在聚」。
## 「构」（攻击前摇）的蓄力环：半径、亮度、是否「落刀预警」全由 `DuelView`
## 按 `COMMIT` 进度算好再喂进来（那边还要叠「看破」心得给 P2 的提前量）。
## 这里只负责等比缩放成正圆、按目标半径摆到躯干中心。
func pose_charge(side: int, center: Vector2, radius: float, color: Color, angle: float = 0.0) -> void:
	if _paused:
		return
	var sprite := _charge[0 if side == DuelTypes.Side.P1 else 1]
	var s := maxf(0.001, radius / CHARGE_TEX_RADIUS)
	sprite.visible = true
	sprite.position = center
	sprite.rotation = angle
	sprite.scale = Vector2(s, s)
	sprite.modulate = color


func hide_charge(side: int) -> void:
	_charge[0 if side == DuelTypes.Side.P1 else 1].visible = false


## 符卡发动/被打断的爆环：紫色 `circle_02` 由内向外推开。
## `strength` 只压亮度（被打断时环还没张开，不该和成功发动一样亮）。
func burst_spell(origin: Vector2, strength: float = 1.0) -> void:
	if _paused:
		return
	_burst_power = clampf(strength * _strength, 0.0, 1.0)
	if _burst_power <= 0.0:
		return
	_burst_t = 0.0
	_burst_origin = origin
	_pose_ring(_burst_ring, origin, SPELL_RING_START, 0.62 * _burst_power)
	_burst_ring.visible = true


func _pose_ring(sprite: Sprite2D, center: Vector2, radius: float, alpha: float) -> void:
	sprite.position = center
	sprite.scale = Vector2.ONE * (radius / SPELL_RING_TEX_RADIUS)
	sprite.modulate = Color(SPELL_RING_COLOR.r, SPELL_RING_COLOR.g, SPELL_RING_COLOR.b, alpha)


## 尺寸是「设计像素里最长边」，由 1280×720 画布与 46×150 的角色推出：
## 命中 110 / 对刀 140 / 架住 170 / 完美 220（定稿表见计划文档 §6.1；
## 对刀与架住按首轮截图从 190/150 收回，避免叠成一团白）。
func _spec_for(kind: int) -> Dictionary:
	match kind:
		Kind.HIT:
			return {
				"texture": TEX_HIT,
				"amount": 14,
				"lifetime": 0.26,
				"size": 110.0,
				"speed_min": 240.0,
				"speed_max": 560.0,
				"spread": 180.0,
				"damping": 340.0,
				"angular": 120.0,
				"grow": false,
			}
		Kind.CLASH:
			return {
				"texture": TEX_CLASH,
				"amount": 7,
				"lifetime": 0.30,
				"size": 140.0,
				"speed_min": 320.0,
				"speed_max": 700.0,
				"spread": 180.0,
				"damping": 180.0,
				"angular": 160.0,
				"grow": false,
			}
		Kind.BLOCK:
			return {
				"texture": TEX_BLOCK,
				"amount": 1,
				"lifetime": 0.30,
				"size": 170.0,
				"speed_min": 0.0,
				"speed_max": 0.0,
				"spread": 180.0,
				"damping": 0.0,
				"angular": 0.0,
				"grow": true,
			}
		Kind.PERFECT:
			return {
				"texture": TEX_PERFECT,
				"amount": 1,
				"lifetime": 0.38,
				"size": 220.0,
				"speed_min": 0.0,
				"speed_max": 0.0,
				"spread": 180.0,
				"damping": 0.0,
				"angular": 0.0,
				"grow": true,
			}
	return {}


func _make_node(kind: int, spec: Dictionary, slot: int) -> GPUParticles2D:
	var node := GPUParticles2D.new()
	node.name = "Fx%s%d" % [Kind.keys()[kind], slot]
	node.emitting = false
	node.one_shot = true
	node.explosiveness = 1.0
	# 爆点要留在原地：粒子不能跟着节点（节点会在下一次爆发时被挪走）。
	node.local_coords = false
	node.amount = int(spec["amount"])
	node.lifetime = float(spec["lifetime"])
	node.texture = spec["texture"] as Texture2D
	# 贴图已开 mipmaps（36 张 .import 全部 mipmaps/generate=true），
	# 这里必须配对用 Linear Mipmap，否则缩小到 0.21–0.43 仍会闪。
	node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# 爆点可能落在半屏之外，默认 200×200 的可视区会被整发剔掉。
	node.visibility_rect = Rect2(-640.0, -640.0, 1280.0, 1280.0)
	node.process_material = _make_process_material(spec)
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	node.material = blend
	node.finished.connect(_on_finished.bind(node))
	return node


func _make_process_material(spec: Dictionary) -> ParticleProcessMaterial:
	var mat := ParticleProcessMaterial.new()
	var scale := float(spec["size"]) / TEX_SIZE
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 8.0
	mat.direction = Vector3(1.0, 0.0, 0.0)
	mat.spread = float(spec["spread"])
	mat.initial_velocity_min = float(spec["speed_min"])
	mat.initial_velocity_max = float(spec["speed_max"])
	mat.damping_min = float(spec["damping"])
	mat.damping_max = float(spec["damping"])
	mat.angular_velocity_min = -float(spec["angular"])
	mat.angular_velocity_max = float(spec["angular"])
	mat.gravity = Vector3.ZERO
	mat.scale_min = scale * 0.85
	mat.scale_max = scale * 1.15
	mat.scale_curve = _scale_curve(bool(spec["grow"]))
	mat.color_ramp = _fade_ramp()
	return mat


## 环类（架住/完美）从 0.45 长到 1.0，读作「护罩张开」；
## 火星类略微收小，避免多颗粒叠成一片白。
func _scale_curve(grow: bool) -> CurveTexture:
	var curve := Curve.new()
	if grow:
		curve.add_point(Vector2(0.0, 0.45))
		curve.add_point(Vector2(0.4, 0.8))
		curve.add_point(Vector2(1.0, 1.0))
	else:
		curve.add_point(Vector2(0.0, 1.0))
		curve.add_point(Vector2(1.0, 0.55))
	var tex := CurveTexture.new()
	tex.curve = curve
	return tex


func _fade_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var tex := GradientTexture1D.new()
	tex.gradient = gradient
	return tex


func burst_hit(at: Vector2, attacker_color: Color, strength: float = 1.0) -> void:
	# 白芯压不住颜色时，攻击方色再提亮一档，保证「谁的刀」可读。
	play(Kind.HIT, at, attacker_color.lightened(0.25), strength)


func burst_clash(at: Vector2, strength: float = 1.0) -> void:
	play(Kind.CLASH, at, CLASH_COLOR, strength)


func burst_block(at: Vector2, defender_color: Color, perfect: bool, strength: float = 1.0) -> void:
	if perfect:
		play(Kind.PERFECT, at, PERFECT_COLOR, strength)
	else:
		play(Kind.BLOCK, at, defender_color.lightened(0.15), strength)


## `strength` 是这一发的强度（0–1），会乘上全局强度并缩放数量与 alpha。
func play(kind: int, at: Vector2, color: Color, strength: float = 1.0) -> void:
	if _paused or kind < 0 or kind >= Kind.size():
		return
	var power := clampf(strength * _strength, 0.0, 1.0)
	if power <= 0.0:
		return
	var slot := int(_cursor[kind])
	_cursor[kind] = (slot + 1) % POOL_PER_KIND
	var index := kind * POOL_PER_KIND + slot
	var node := _nodes[index]
	node.amount = maxi(1, int(round(float(_base_amount[index]) * power)))
	var mat := node.process_material as ParticleProcessMaterial
	if mat != null:
		# 低强度不仅少发几颗，也压 alpha——否则「轻轻碰一下」也会白一片。
		mat.color = Color(color.r, color.g, color.b, color.a * clampf(0.55 + 0.45 * power, 0.0, 1.0))
	node.position = at
	# one-shot 只能靠 restart() 重新点火：finished 之后再 emitting = true
	# 会吃到 GPU 侧的异步状态，整发可能不显示（技能 godot-particles 硬规则）。
	node.restart()


## 舞台暂停时冻结粒子（`speed_scale = 0`），恢复后从原处继续；
## 暂停期间新的爆发直接丢弃，避免解冻瞬间「补放」一串。
func set_paused(value: bool) -> void:
	_paused = value
	for node in _nodes:
		node.speed_scale = 0.0 if value else 1.0


func is_paused() -> bool:
	return _paused


## 0.0 完全关闭，1.0 正常。留给后续设置页的「特效强度」开关。
func set_strength(value: float) -> void:
	_strength = clampf(value, 0.0, 1.0)


func get_strength() -> float:
	return _strength


## 换局 / 重开 / 重摆架势时清空，避免上一局的残余飘进新一局。
func clear_all() -> void:
	for node in _nodes:
		node.emitting = false
		node.restart()
		node.emitting = false
	for sprite in _slash:
		sprite.visible = false
	for sprite in _charge:
		sprite.visible = false
	if _burst_ring != null:
		_burst_ring.visible = false
	_burst_t = -1.0


func _on_finished(node: GPUParticles2D) -> void:
	node.emitting = false
