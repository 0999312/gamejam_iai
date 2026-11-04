class_name SpineFighterView
extends Node2D

## 一个角色的 Spine 表现节点：包一层 `SpineSprite`，把 DuelSim 的状态喂给动画状态机。
##
## 为什么用 ClassDB 而不是直接写 `SpineSprite.new()`：
## 外部 GDExtension 未安装时，硬引用类型会让整个脚本解析失败、连带 DuelView 一起挂；
## 走 ClassDB 只有「装了扩展」的机器才会真的创建节点，没装就 setup() 返回 false 回退灰盒。
##
## 节点原点的语义 = 「脚底中心」：`DuelView` 把本节点摆到 (x, GROUND_Y)，
## 内部按骨架包围盒自动缩放/对位，所以美术换角色只需要换档案数值。

signal animation_missing(state_name: String, animation: String)

const TRACK_ID := 0

var profile: SpineFighterProfile

var _sprite: Node2D
var _anim_state: Object
var _data: Object
var _bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(150.0, 150.0))
var _fit_scale: float = 1.0
var _face_left: bool = false
var _paused: bool = false
var _base_time_scale: float = 1.0
## 是否正停在「瞬发架刀」的防御动画末帧（窗口结束时要解冻复位）。
var _frozen: bool = false
var _current_state: int = -1
var _current_animation: String = ""
var _reported: Dictionary = {}

## 同一份骨架可能被两个角色共用，数据对象只建一次。
static var _data_cache: Dictionary = {}


static func is_supported() -> bool:
	return ClassDB.class_exists("SpineSprite") and ClassDB.class_exists("SpineSkeletonDataResource")


func setup(p_profile: SpineFighterProfile) -> bool:
	if p_profile == null or not p_profile.has_resources() or not is_supported():
		return false
	_teardown()
	var data: Object = _shared_data(p_profile.skeleton_file, p_profile.atlas_file)
	if data == null:
		return false
	_data = data
	var sprite: Node2D = ClassDB.instantiate("SpineSprite") as Node2D
	if sprite == null:
		_data = null
		return false
	sprite.call("set_skeleton_data_res", data)
	sprite.visible = false
	add_child(sprite)
	_sprite = sprite
	profile = p_profile
	_reported.clear()
	_current_state = -1
	_current_animation = ""
	_base_time_scale = 1.0
	_bounds = _read_bounds()
	_fit_scale = _compute_fit_scale()
	_anim_state = sprite.call("get_animation_state")
	_apply_pose()
	return true


func clear() -> void:
	_teardown()


## 每帧由 DuelView 调用：位置由调用方摆放，这里只吃状态与朝向。
func apply(fighter: FighterState, face_left: bool) -> void:
	if _sprite == null or fighter == null or profile == null:
		return
	_face_left = face_left
	# 瞬发架刀：按 L 后立刻停在防御动画的最后一帧，直到窗口结束 / 出刀 / 被打穿。
	var hold := _should_hold_last_frame(fighter)
	if fighter.state != _current_state:
		_play_state(fighter.state, _sync_window_frames(fighter))
		_current_state = fighter.state
		if hold:
			_hold_last_frame()
		else:
			_frozen = false
	elif hold != _frozen:
		if hold:
			_hold_last_frame()
		else:
			_resume_from_hold(maxi(1, fighter.state_duration - fighter.state_frame))
	# 有倒地动画就播完躺下；只有档案没配 DOWN 动画时才交回灰盒倒地剪影。
	_sprite.visible = fighter.state != DuelTypes.State.DOWN \
			or _has_state_animation(DuelTypes.State.DOWN)
	var tint := profile.hitstun_tint if fighter.state == DuelTypes.State.HITSTUN else Color.WHITE
	_sprite.modulate = tint
	_apply_pose()
	_apply_time_scale()


## 一次性动画要对齐的动作窗口帧数。
## 攻击的 COMMIT 只覆盖「构」本身，而 gongji 是包含挥砍与收势的整刀；
## 用「构 + 斩 + 空挥收招」的总窗口对齐，才不会被构的短窗口催成快进。
func _sync_window_frames(fighter: FighterState) -> int:
	if fighter.state == DuelTypes.State.COMMIT and fighter.data != null:
		var attack_frames := fighter.commit_total \
				+ fighter.data.slash_frames + fighter.data.whiff_recovery
		if attack_frames > 0:
			return attack_frames
	return fighter.state_duration


## 档案是否显式给该状态配了动画，且骨架里确实存在。
func _has_state_animation(state: int) -> bool:
	if profile == null:
		return false
	var key := DuelTypes.state_name(state)
	var mapped: Variant = profile.animation_map.get(key, null)
	if not (mapped is String):
		return false
	var anim: String = mapped
	return not anim.is_empty() and _animation_exists(anim)


func is_active() -> bool:
	return _sprite != null


## 档案是否为该状态配了动画、且骨架里真实存在。DuelView 用它决定
## 「倒地播 siwang」还是「交回灰盒倒地剪影」。
func has_animation_for_state(state: int) -> bool:
	return _has_state_animation(state)


func current_animation() -> String:
	return _current_animation


## 当前动画状态机的时间倍率（0 = 暂停；非循环动画会按状态帧数重定时）。
func playback_time_scale() -> float:
	if _anim_state == null:
		return 0.0
	return float(_anim_state.call("get_time_scale"))


func fit_scale() -> float:
	return _fit_scale


func bounds() -> Rect2:
	return _bounds


func set_paused(value: bool) -> void:
	_paused = value
	_apply_time_scale()


func _exit_tree() -> void:
	_teardown()


func _play_state(state: int, duration_frames: int) -> void:
	if _anim_state == null or _data == null or profile == null:
		return
	var anim := profile.animation_for_state(state)
	if anim.is_empty():
		# 该状态没配动画：保持上一段，不要把人冻在 T 姿。
		return
	if not _animation_exists(anim):
		_report_missing(DuelTypes.state_name(state), anim)
		return
	# 进入「构」= 一次新攻击：即使上一段还是同一攻击动画（例如收招时
	# 被脚本直接拉回构），也要从第 0 帧重播。其余相邻状态（构 → 斩 → 收招）
	# 共用同一段动画，继续播，不要每一跳都从头起手。
	var restart := state == DuelTypes.State.COMMIT
	if anim == _current_animation and not restart:
		return
	var loop := profile.is_looping(anim)
	_anim_state.call("set_animation", anim, loop, TRACK_ID)
	_current_animation = anim
	_base_time_scale = 1.0
	if profile.sync_animation_to_state and not loop and duration_frames > 0:
		var anim_seconds := _animation_duration(anim)
		var state_seconds := float(duration_frames) / 60.0
		if anim_seconds > 0.001 and state_seconds > 0.001:
			# 动画长度 / 状态长度：一次性动画恰好在状态结束那一帧播完。
			_base_time_scale = anim_seconds / state_seconds
	_apply_time_scale()


func _apply_time_scale() -> void:
	if _anim_state == null:
		return
	_anim_state.call("set_time_scale", 0.0 if _paused else _base_time_scale)


## A 符卡（瞬发架刀）窗口内：把防御动画定位到最后一帧并暂停。
func _should_hold_last_frame(fighter: FighterState) -> bool:
	if fighter == null or fighter.state != DuelTypes.State.SPELL:
		return false
	if fighter.spell_card == null or fighter.spell_card.effect != SpellCardData.Effect.GUARD_STANCE:
		return false
	return fighter.spell_auto_guard_until_frame >= 0


func _hold_last_frame() -> void:
	_frozen = true
	if _anim_state == null:
		return
	var entry: Object = _anim_state.call("get_track", TRACK_ID)
	var duration := _animation_duration(_current_animation)
	if entry != null and duration > 0.001 and entry.has_method("set_track_time"):
		entry.call("set_track_time", duration)
	_base_time_scale = 0.0
	_apply_time_scale()


## 窗口结束（或按架转普通架）：从当前动画重新起步，并按剩余状态帧重新对齐速度。
func _resume_from_hold(remaining_frames: int) -> void:
	_frozen = false
	if _anim_state == null or profile == null or _current_animation.is_empty():
		return
	var loop := profile.is_looping(_current_animation)
	_anim_state.call("set_animation", _current_animation, loop, TRACK_ID)
	_base_time_scale = 1.0
	if profile.sync_animation_to_state and not loop and remaining_frames > 0:
		var anim_seconds := _animation_duration(_current_animation)
		var state_seconds := float(remaining_frames) / 60.0
		if anim_seconds > 0.001 and state_seconds > 0.001:
			_base_time_scale = anim_seconds / state_seconds
	_apply_time_scale()


## 把骨架摆到「包围盒中心 x = 0、脚底 y = 0」，朝左时水平镜像。
func _apply_pose() -> void:
	if _sprite == null:
		return
	var flip: bool = _face_left and profile != null and profile.flip_when_facing_left
	var s := _fit_scale
	_sprite.scale = Vector2(-s if flip else s, s)
	var center := _bounds.get_center()
	_sprite.position = Vector2((s if flip else -s) * center.x, -s * _bounds.end.y)
	if profile != null:
		_sprite.position += profile.offset


func _read_bounds() -> Rect2:
	if _sprite == null:
		return Rect2(Vector2.ZERO, Vector2(150.0, 150.0))
	var skeleton: Object = _sprite.call("get_skeleton")
	if skeleton == null or not skeleton.has_method("get_bounds"):
		return Rect2(Vector2.ZERO, Vector2(150.0, 150.0))
	var raw: Variant = skeleton.call("get_bounds")
	if raw is Rect2 and (raw as Rect2).size.y > 0.001:
		return raw
	return Rect2(Vector2.ZERO, Vector2(150.0, 150.0))


func _compute_fit_scale() -> float:
	if profile == null or profile.target_height <= 0.0 or _bounds.size.y <= 0.001:
		return 1.0
	return profile.target_height / _bounds.size.y


func _animation_exists(animation: String) -> bool:
	if _data == null:
		return false
	return _data.call("find_animation", animation) != null


func _animation_duration(animation: String) -> float:
	if _data == null:
		return 0.0
	var anim: Variant = _data.call("find_animation", animation)
	if anim is Object and (anim as Object).has_method("get_duration"):
		return float((anim as Object).call("get_duration"))
	return 0.0


func _report_missing(state_name: String, animation: String) -> void:
	var key := "%s|%s" % [state_name, animation]
	if _reported.has(key):
		return
	_reported[key] = true
	push_warning("Spine 动画缺失：状态 %s 需要的动画 %s 不在骨架里" % [state_name, animation])
	animation_missing.emit(state_name, animation)


func _teardown() -> void:
	if _sprite != null:
		remove_child(_sprite)
		_sprite.queue_free()
	_sprite = null
	_anim_state = null
	_data = null
	profile = null
	_current_state = -1
	_current_animation = ""
	_base_time_scale = 1.0
	_frozen = false


static func _shared_data(skeleton_file: Resource, atlas_file: Resource) -> Object:
	var key := "%d:%d" % [skeleton_file.get_instance_id(), atlas_file.get_instance_id()]
	if _data_cache.has(key):
		return _data_cache[key]
	var data: Object = ClassDB.instantiate("SpineSkeletonDataResource")
	if data == null:
		return null
	data.call("set_skeleton_file_res", skeleton_file)
	data.call("set_atlas_res", atlas_file)
	data.call("update_skeleton_data")
	if not bool(data.call("is_skeleton_data_loaded")):
		push_warning("Spine 骨架加载失败：%s" % skeleton_file.resource_path)
		return null
	_data_cache[key] = data
	return data
