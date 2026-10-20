extends Node2D

## 灰盒对决控制器：GUIDE 输入 + RunState 阶梯 / 本地双人 + 表现层。
## P1：J 斩 / K 架；P2：小键盘 1/2（或 I/O）；R 重开；Esc 返回菜单；1–3 选心得。

const VIEW_SCENE := preload("res://scenes/duel/duel_view.tscn")
const HUD_SCENE := preload("res://scenes/duel/hud.tscn")
const PAUSE_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const MENU_SCENE := "res://scenes/menu/menu.tscn"

const RESTART_KEY := KEY_R
const PAUSE_KEY := KEY_ESCAPE
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


func _ready() -> void:
	mode = GameBootstrap.pending_mode if GameBootstrap != null else &"run"
	if mode != &"versus":
		mode = &"run"

	_setup_input()
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
	if _audio != null:
		_audio.stop_ambient()
	if _context != null:
		GUIDE.disable_mapping_context(_context)


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

	var p1_attack: Array[Key] = [KEY_J]
	var p1_guard: Array[Key] = [KEY_K]
	var p2_attack: Array[Key] = [KEY_KP_1, KEY_I]
	var p2_guard: Array[Key] = [KEY_KP_2, KEY_O]
	var restart_keys: Array[Key] = [RESTART_KEY]
	var pause_keys: Array[Key] = [PAUSE_KEY]

	_attack_action = _add_key_action(&"duel_attack_p1", p1_attack)
	_guard_action = _add_key_action(&"duel_guard_p1", p1_guard)
	_p2_attack_action = _add_key_action(&"duel_attack_p2", p2_attack)
	_p2_guard_action = _add_key_action(&"duel_guard_p2", p2_guard)
	_restart_action = _add_key_action(&"duel_restart", restart_keys)
	_pause_action = _add_key_action(&"duel_pause", pause_keys)

	_attack_action.just_triggered.connect(_on_attack_pressed)
	_guard_action.just_triggered.connect(_on_guard_pressed)
	_p2_attack_action.just_triggered.connect(_on_p2_attack_pressed)
	_p2_guard_action.just_triggered.connect(_on_p2_guard_pressed)
	_restart_action.just_triggered.connect(_on_restart_pressed)
	_pause_action.just_triggered.connect(_on_pause_pressed)

	for i in OFFER_KEYS.size():
		var offer_keys: Array[Key] = [OFFER_KEYS[i]]
		var action := _add_key_action(StringName("duel_offer_%d" % (i + 1)), offer_keys)
		action.just_triggered.connect(_on_offer_key.bind(i))
		_offer_actions.append(action)

	GUIDE.enable_mapping_context(_context, true)


func _add_key_action(action_name: StringName, keys: Array[Key]) -> GUIDEAction:
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
	_paused = not _paused
	if _paused:
		_pause.show_pause()
	else:
		_pause.hide_pause()


func _on_resume_requested() -> void:
	_paused = false
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
