extends Node2D

## 灰盒对决控制器：GUIDE 输入 + RunState 阶梯 / 本地双人 + 表现层。
## P1：J 斩 / K 架（鼠标左/右键、手柄 1 的 A/B 同时可用）；
## P2：小键盘 1/2（或 I/O），检测到第二手柄时也可用手柄 2 的 A/B。
## R 重开；Esc 暂停；1–3 选心得。

const VIEW_SCENE := preload("res://scenes/duel/duel_view.tscn")
const HUD_SCENE := preload("res://scenes/duel/hud.tscn")
const PAUSE_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const MENU_SCENE := "res://scenes/menu/menu.tscn"

const OFFER_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3]

var sim: DuelSim
var ai: DuelAi
var run: RunState
var mode: StringName = &"run"

var _view: DuelView
var _hud: DuelHud
var _audio: DuelAudio
var _pause: PauseMenu
var _paused := false
var _start_cue_played := false

var _context: GUIDEMappingContext
var _attack_action: GUIDEAction
var _guard_action: GUIDEAction
var _p2_attack_action: GUIDEAction
var _p2_guard_action: GUIDEAction
var _restart_action: GUIDEAction
var _pause_action: GUIDEAction
var _offer_actions: Array[GUIDEAction] = []

var _attack_queued := false
var _guard_queued := false
var _p2_attack_queued := false
var _p2_guard_queued := false
var _restart_queued := false
var _settled := false
var _raw_p1_device := -1
var _raw_p2_device := -1
var _last_pause_ms := -1000


func _ready() -> void:
	mode = GameBootstrap.pending_mode if GameBootstrap != null else &"run"
	if mode != &"versus":
		mode = &"run"

	var pads := Input.get_connected_joypads()
	if pads.size() >= 1:
		_raw_p1_device = pads[0]
	if pads.size() >= 2:
		_raw_p2_device = pads[1]

	_setup_input()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_view = VIEW_SCENE.instantiate() as DuelView
	add_child(_view)
	_hud = HUD_SCENE.instantiate() as DuelHud
	add_child(_hud)
	_hud.offer_chosen.connect(_on_offer_chosen)
	_audio = DuelAudio.new()
	add_child(_audio)

	_pause = PAUSE_SCENE.instantiate() as PauseMenu
	_hud.add_child(_pause)
	_pause.resume_requested.connect(_on_resume_requested)
	_pause.restart_requested.connect(_on_pause_restart_requested)
	_pause.menu_requested.connect(_on_pause_menu_requested)

	if mode == &"versus":
		_start_versus()
	else:
		run = RunState.new(
			12345,
			GameBootstrap.meta if GameBootstrap != null else null,
			GameBootstrap.pending_character if GameBootstrap != null else &"char_a",
			GameBootstrap.hard_mode if GameBootstrap != null else false
		)
		_start_stage()


func _exit_tree() -> void:
	if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)
	if _audio != null:
		_audio.stop_ambient()
	if _context != null:
		GUIDE.disable_mapping_context(_context)


## 手柄原始事件兜底：GUIDE 依赖启动时的手柄枚举，若枚举为空则 joy_index
## 映射会失效。这里按实际 event.device 直接分发，保证已连接手柄仍可用；
## GUIDE 正常时两条路径都只置位队列，不会重复出招。
func _input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton):
		return
	var joy := event as InputEventJoypadButton
	if not joy.pressed:
		return

	var device := joy.device
	if _raw_p1_device < 0:
		_raw_p1_device = device
	var slot := 0
	if mode == &"versus":
		if _raw_p2_device < 0 and device != _raw_p1_device:
			_raw_p2_device = device
		slot = 1 if device == _raw_p2_device else 0

	var meta := GameBootstrap.meta if GameBootstrap != null else null
	var button := joy.button_index
	if slot == 0:
		if button == KeyBindings.get_joy_button(meta, &"attack_p1"):
			_attack_queued = true
		elif button == KeyBindings.get_joy_button(meta, &"guard_p1"):
			_guard_queued = true
	else:
		if button == KeyBindings.get_joy_button(meta, &"attack_p2"):
			_p2_attack_queued = true
		elif button == KeyBindings.get_joy_button(meta, &"guard_p2"):
			_p2_guard_queued = true
	if button == KeyBindings.get_joy_button(meta, &"pause"):
		_on_pause_pressed()
	elif button == KeyBindings.get_joy_button(meta, &"restart"):
		_on_restart_pressed()


func _physics_process(_delta: float) -> void:
	if sim == null:
		return
	if _paused:
		return

	if sim.finished:
		if not _settled:
			_settle_duel()
		if _restart_queued:
			_restart_queued = false
			if mode == &"versus":
				_start_versus()
			elif run != null and (run.phase == RunState.Phase.FAILED or run.phase == RunState.Phase.CLEAR):
				run.restart_run()
				_start_stage()
		_hud.refresh()
		return

	if mode == &"versus":
		sim.set_input(DuelTypes.Side.P1, _attack_queued, _guard_queued)
		sim.set_input(DuelTypes.Side.P2, _p2_attack_queued, _p2_guard_queued)
		_attack_queued = false
		_guard_queued = false
		_p2_attack_queued = false
		_p2_guard_queued = false
		sim.tick()
	else:
		sim.set_input(DuelTypes.Side.P1, _attack_queued, _guard_queued)
		_attack_queued = false
		_guard_queued = false
		if ai != null:
			ai.tick(sim)
		sim.tick()
	_play_start_cue_once()
	_hud.refresh()


func _play_start_cue_once() -> void:
	if _start_cue_played or sim == null:
		return
	if sim.frame >= sim.opening_lock_frames:
		_start_cue_played = true
		if _audio != null:
			_audio.play_start()


func _settle_duel() -> void:
	_settled = true
	if mode == &"versus":
		_hud.refresh()
		return
	if run == null:
		return
	run.player_hp = sim.p1.hp
	run.on_duel_finished(sim.winner)
	_hud.refresh()
	if run.phase == RunState.Phase.REWARD:
		_hud.show_rewards(run.offers)


func _start_stage() -> void:
	sim = DuelSim.new(run.player_data(), run.enemy_data(), 12345 + run.stage_index)
	sim.mods = run.mods()
	sim.p1.hp = run.player_hp
	sim.p1.flow = run.start_flow()
	sim.p2.flow = 40
	sim.opening_lock_frames = 180

	var profile := run.enemy_profile()
	profile.opening_grace_frames = 210 if run.stage_index == 0 else 0
	ai = DuelAi.new(DuelTypes.Side.P2, profile, 12345 + run.stage_index)

	_clear_queued_input()
	_settled = false
	_start_cue_played = false
	_paused = false
	if _pause != null:
		_pause.visible = false

	if _view != null:
		_view.bind(sim)
	if _audio != null:
		_audio.bind(sim)
	if _hud != null:
		_hud.set_versus(false)
		_hud.set_run(run)
		_hud.bind(sim)
		_hud.hide_rewards()


func _start_versus() -> void:
	run = null
	ai = null
	var p1_data := FighterData.for_character(GameBootstrap.pending_character if GameBootstrap != null else &"char_a")
	sim = DuelSim.new(p1_data, p1_data, 12345)
	sim.opening_lock_frames = 180
	sim.p1.hp = p1_data.max_hp
	sim.p2.hp = p1_data.max_hp
	sim.p1.flow = p1_data.start_flow
	sim.p2.flow = p1_data.start_flow

	_clear_queued_input()
	_settled = false
	_start_cue_played = false
	_paused = false
	if _pause != null:
		_pause.visible = false

	if _view != null:
		_view.bind(sim)
	if _audio != null:
		_audio.bind(sim)
	if _hud != null:
		_hud.set_versus(true)
		_hud.set_run(null)
		_hud.bind(sim)
		_hud.hide_rewards()


func _clear_queued_input() -> void:
	_attack_queued = false
	_guard_queued = false
	_p2_attack_queued = false
	_p2_guard_queued = false
	_restart_queued = false


func _on_offer_chosen(index: int) -> void:
	if run == null or run.phase != RunState.Phase.REWARD:
		return
	if run.apply_offer(index):
		_start_stage()


func _setup_input() -> void:
	_context = GUIDEMappingContext.new()
	_context.display_name = "duel_m3"
	_offer_actions.clear()

	var meta := GameBootstrap.meta if GameBootstrap != null else null
	var p1_attack: Array[Key] = KeyBindings.get_keys(meta, &"attack_p1")
	var p1_guard: Array[Key] = KeyBindings.get_keys(meta, &"guard_p1")
	var p2_attack: Array[Key] = KeyBindings.get_keys(meta, &"attack_p2")
	var p2_guard: Array[Key] = KeyBindings.get_keys(meta, &"guard_p2")
	var restart_keys: Array[Key] = KeyBindings.get_keys(meta, &"restart")
	var pause_keys: Array[Key] = KeyBindings.get_keys(meta, &"pause")

	# 不依赖启动时的设备枚举结果：始终给 P1 建“第一个手柄”映射，双人时给 P2
	# 建“第二个手柄”映射。没有对应手柄时映射不会触发；有手柄时即使
	# Input.get_connected_joypads() 在启动帧暂时为空也不会完全失去手柄。
	var p1_joys: Array[int] = [0]
	var p2_joys: Array[int] = []
	if mode == &"versus":
		p2_joys.append(1)
	var p1_mouse_attack: Array[MouseButton] = [MOUSE_BUTTON_LEFT]
	var p1_mouse_guard: Array[MouseButton] = [MOUSE_BUTTON_RIGHT]
	var no_mouse: Array[MouseButton] = []
	var p1_attack_buttons: Array[JoyButton] = [KeyBindings.get_joy_button(meta, &"attack_p1")]
	var p1_guard_buttons: Array[JoyButton] = [KeyBindings.get_joy_button(meta, &"guard_p1")]
	var p2_attack_buttons: Array[JoyButton] = [KeyBindings.get_joy_button(meta, &"attack_p2")]
	var p2_guard_buttons: Array[JoyButton] = [KeyBindings.get_joy_button(meta, &"guard_p2")]
	var pause_buttons: Array[JoyButton] = [KeyBindings.get_joy_button(meta, &"pause")]
	var restart_buttons: Array[JoyButton] = [KeyBindings.get_joy_button(meta, &"restart")]
	var all_joys: Array[int] = p1_joys.duplicate()
	all_joys.append_array(p2_joys)

	_attack_action = _add_action(&"duel_attack_p1", p1_attack, p1_mouse_attack, p1_joys, p1_attack_buttons)
	_guard_action = _add_action(&"duel_guard_p1", p1_guard, p1_mouse_guard, p1_joys, p1_guard_buttons)
	_p2_attack_action = _add_action(&"duel_attack_p2", p2_attack, no_mouse, p2_joys, p2_attack_buttons)
	_p2_guard_action = _add_action(&"duel_guard_p2", p2_guard, no_mouse, p2_joys, p2_guard_buttons)
	_restart_action = _add_action(&"duel_restart", restart_keys, no_mouse, all_joys, restart_buttons)
	_pause_action = _add_action(&"duel_pause", pause_keys, no_mouse, all_joys, pause_buttons)

	_attack_action.just_triggered.connect(_on_attack_pressed)
	_guard_action.just_triggered.connect(_on_guard_pressed)
	_p2_attack_action.just_triggered.connect(_on_p2_attack_pressed)
	_p2_guard_action.just_triggered.connect(_on_p2_guard_pressed)
	_restart_action.just_triggered.connect(_on_restart_pressed)
	_pause_action.just_triggered.connect(_on_pause_pressed)

	for i in OFFER_KEYS.size():
		var offer_keys: Array[Key] = [OFFER_KEYS[i]]
		var action := _add_action(StringName("duel_offer_%d" % (i + 1)), offer_keys, no_mouse, [], [])
		action.just_triggered.connect(_on_offer_key.bind(i))
		_offer_actions.append(action)

	GUIDE.enable_mapping_context(_context, true)


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_rebuild_input()


## 热插拔：重建 GUIDE 上下文，按新的手柄数量重新分配 P1/P2 设备；
## 不改 sim 状态，因此对局可以继续。
func _rebuild_input() -> void:
	if _context != null:
		GUIDE.disable_mapping_context(_context)
		_context = null
	_clear_queued_input()
	_setup_input()
	if _hud != null:
		_hud.refresh()


## 一个动作可以挂多条映射：键盘、鼠标、手柄同时生效，互不排斥。
func _add_action(action_name: StringName, keys: Array[Key], mouse_buttons: Array[MouseButton], joy_indices: Array[int], joy_buttons: Array[JoyButton]) -> GUIDEAction:
	var action := GUIDEAction.new()
	action.name = action_name
	action.action_value_type = GUIDEAction.GUIDEActionValueType.BOOL

	var mapping := GUIDEActionMapping.new()
	mapping.action = action

	for key in keys:
		var input_mapping := GUIDEInputMapping.new()
		var key_input := GUIDEInputKey.new()
		key_input.key = key
		input_mapping.input = key_input
		mapping.input_mappings.append(input_mapping)

	for mouse_button in mouse_buttons:
		var input_mapping := GUIDEInputMapping.new()
		var mouse_input := GUIDEInputMouseButton.new()
		mouse_input.button = mouse_button
		input_mapping.input = mouse_input
		mapping.input_mappings.append(input_mapping)

	for joy_index in joy_indices:
		for joy_button in joy_buttons:
			var input_mapping := GUIDEInputMapping.new()
			var joy_input := GUIDEInputJoyButton.new()
			joy_input.joy_index = joy_index
			joy_input.button = joy_button
			input_mapping.input = joy_input
			mapping.input_mappings.append(input_mapping)

	_context.mappings.append(mapping)
	return action


func _on_attack_pressed() -> void:
	_attack_queued = true


func _on_guard_pressed() -> void:
	_guard_queued = true


func _on_p2_attack_pressed() -> void:
	_p2_attack_queued = true


func _on_p2_guard_pressed() -> void:
	_p2_guard_queued = true


func _on_restart_pressed() -> void:
	_restart_queued = true


func _on_pause_pressed() -> void:
	if sim == null or _pause == null:
		return
	var now := Time.get_ticks_msec()
	if now - _last_pause_ms < 200:
		return
	_last_pause_ms = now
	_paused = not _paused
	if _paused:
		_pause.show_pause()
	else:
		_pause.hide_pause()


func _on_resume_requested() -> void:
	_paused = false
	_clear_queued_input()
	if _pause != null:
		_pause.hide_pause()


func _on_pause_restart_requested() -> void:
	_paused = false
	if _pause != null:
		_pause.visible = false
	_clear_queued_input()
	if mode == &"versus":
		_start_versus()
	elif run != null:
		if run.phase == RunState.Phase.FAILED or run.phase == RunState.Phase.CLEAR:
			run.restart_run()
		_start_stage()


func _on_pause_menu_requested() -> void:
	_paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_offer_key(index: int) -> void:
	_on_offer_chosen(index)
