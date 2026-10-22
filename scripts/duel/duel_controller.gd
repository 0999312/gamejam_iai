extends Node2D

## 灰盒对决控制器：GUIDE 输入 + RunState 阶梯 / 本地双人 + 表现层。
## P1：J 斩 / K 架（鼠标左/右键、手柄 1 的 A/B 同时可用）；
## P2：小键盘 1/2（或 I/O），检测到第二手柄时也可用手柄 2 的 A/B。
## R 重开；Esc 暂停；1–3 选心得。

const VIEW_SCENE := preload("res://scenes/duel/duel_view.tscn")
const HUD_SCENE := preload("res://scenes/duel/hud.tscn")
const MENU_SCENE := "res://scenes/menu/menu.tscn"

const OFFER_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3]

## 开场礼让与对手开局心流：写进常量，避免三处魔法数字各自漂移。
const OPENING_LOCK_FRAMES := 180
const ENEMY_START_FLOW := 40
const TEACHING_GRACE_FRAMES := 210

var sim: DuelSim
var ai: DuelAi
var run: RunState
var mode: StringName = &"run"

## 本局种子：开局随机一次，同局内第 N 场由 base + 场次派生。
## 这样「同一局可复现、不同局不重复」，而不是每局都用固定 12345（审计 P2-11）。
var _run_seed: int = 0

var _view: DuelView
var _hud: DuelHud
var _audio: DuelAudio
var _paused := false
var _start_cue_played := false

var _context: GUIDEMappingContext
var _attack_action: GUIDEAction
var _guard_action: GUIDEAction
var _spell_action: GUIDEAction
var _p2_attack_action: GUIDEAction
var _p2_guard_action: GUIDEAction
var _p2_spell_action: GUIDEAction
var _restart_action: GUIDEAction
var _pause_action: GUIDEAction
var _offer_actions: Array[GUIDEAction] = []

var _attack_queued := false
var _guard_queued := false
var _guard_held := false
var _spell_queued := false
var _p2_attack_queued := false
var _p2_guard_queued := false
var _p2_guard_held := false
var _p2_spell_queued := false
var _restart_queued := false
var _settled := false
var _raw_p1_device := -1
var _raw_p2_device := -1
var _last_pause_ms := -1000


func _ready() -> void:
	mode = GameBootstrap.pending_mode if GameBootstrap != null else &"run"
	if mode != &"versus":
		mode = &"run"

	_run_seed = _new_seed()

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

	if mode == &"versus":
		_start_versus()
	else:
		run = RunState.new(
			_run_seed,
			GameBootstrap.meta if GameBootstrap != null else null,
			GameBootstrap.pending_character if GameBootstrap != null else &"char_a",
			_meta_hard_mode()
		)
		_start_stage()


## 困难模式只存在 meta.settings["hard_mode"] 一处真相；读缓存副本会读到旧值。
func _meta_hard_mode() -> bool:
	if GameBootstrap == null or GameBootstrap.meta == null:
		return false
	return bool(GameBootstrap.meta.settings.get("hard_mode", false))


## 非零随机种子。0 在 DuelSim/DuelAi/RunState 里是「请自行 randomize」的哨兵值，
## 这里显式避开，保证 seed 语义只有一种。
static func _new_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi_range(1, 2147483646)


## 同一局内第 N 场的派生种子：局内可复现（便于复现 bug），跨局不重复。
func _stage_seed(stage_index: int) -> int:
	return (_run_seed + stage_index * 7919) % 2147483646 + 1


func _exit_tree() -> void:
	if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)
	if _audio != null:
		_audio.stop_ambient()
	if _context != null:
		GUIDE.disable_mapping_context(_context)
	# 改键配置是全局的：对局结束后必须卸掉，否则其它场景仍按对局改键生效（审计 P3）。
	if GUIDE != null:
		GUIDE.set_remapping_config(null)


## 手柄原始事件兜底：GUIDE 依赖启动时的手柄枚举，若枚举为空则 joy_index
## 映射会失效。这里按实际 event.device 直接分发，保证已连接手柄仍可用；
## GUIDE 正常时两条路径都只置位队列，不会重复出招。
func _input(event: InputEvent) -> void:
	if not (event is InputEventJoypadButton):
		return
	var joy := event as InputEventJoypadButton
	var meta := GameBootstrap.meta if GameBootstrap != null else null
	if not joy.pressed:
		# 松手也要跟踪：架子按「按住」保持，松开立刻收势。
		# 暂停期间同样要跟（放在 _paused 守卫之前），否则暂停时松手被丢，
		# 恢复后仍以为玩家按着架。
		if joy.button_index == KeyBindings.get_joy_button(meta, &"guard_p1"):
			_guard_held = false
		if joy.button_index == KeyBindings.get_joy_button(meta, &"guard_p2"):
			_p2_guard_held = false
		return
	if _paused:
		# 暂停期间只允许用暂停键恢复；攻击/架/符卡/重开一律丢弃。
		# 否则暂停时按下的键会留在队列里，恢复的第一帧立刻出刀（审计 P1-1）。
		if joy.button_index == KeyBindings.get_joy_button(meta, &"pause"):
			_on_pause_pressed()
		return

	var device := joy.device
	if _raw_p1_device < 0:
		_raw_p1_device = device
	var slot := 0
	if mode == &"versus":
		if _raw_p2_device < 0 and device != _raw_p1_device:
			_raw_p2_device = device
		slot = 1 if device == _raw_p2_device else 0

	var button := joy.button_index
	if slot == 0:
		if button == KeyBindings.get_joy_button(meta, &"attack_p1"):
			_attack_queued = true
		elif button == KeyBindings.get_joy_button(meta, &"guard_p1"):
			_guard_queued = true
		elif button == KeyBindings.get_joy_button(meta, &"spell_p1"):
			_spell_queued = true
	else:
		if button == KeyBindings.get_joy_button(meta, &"attack_p2"):
			_p2_attack_queued = true
		elif button == KeyBindings.get_joy_button(meta, &"guard_p2"):
			_p2_guard_queued = true
		elif button == KeyBindings.get_joy_button(meta, &"spell_p2"):
			_p2_spell_queued = true
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
		sim.set_input(DuelTypes.Side.P1, _attack_queued, _guard_queued, 1 if _guard_held else 0)
		sim.set_input(DuelTypes.Side.P2, _p2_attack_queued, _p2_guard_queued,
				1 if _p2_guard_held else 0)
		if _p2_spell_queued:
			sim.set_spell(DuelTypes.Side.P2)
	else:
		sim.set_input(DuelTypes.Side.P1, _attack_queued, _guard_queued, 1 if _guard_held else 0)
	if _spell_queued:
		sim.set_spell(DuelTypes.Side.P1)
	_clear_input_flags()
	if mode != &"versus" and ai != null:
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
	# 结算会回血（胜利回复，U10 复元为 2）：把结果同步回 sim，
	# 否则 HUD 读的是 sim.p1.hp，奖励界面显示的还是结算前的旧血量，
	# 玩家会以为「回血没触发」。下一场 _start_stage 也会用 run.player_hp 覆盖。
	sim.p1.hp = run.player_hp
	_hud.refresh()
	if run.phase == RunState.Phase.REWARD:
		_hud.show_rewards(run.offers)


func _start_stage() -> void:
	# 多角色基础：一场对局 = MatchSetup（两名角色 + 对手性格），控制器不再自己拼。
	var setup := run.build_match()
	sim = DuelSim.new(setup.p1, setup.p2, _stage_seed(run.stage_index))
	sim.mods = run.mods()
	sim.p1.hp = run.player_hp
	sim.p2.flow = ENEMY_START_FLOW
	sim.opening_lock_frames = OPENING_LOCK_FRAMES

	var profile := setup.p2_profile
	profile.opening_grace_frames = TEACHING_GRACE_FRAMES if run.stage_index == 0 else 0
	ai = DuelAi.new(DuelTypes.Side.P2, profile, _stage_seed(run.stage_index))

	_clear_queued_input()
	_settled = false
	_start_cue_played = false
	_close_pause_panel()

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
	sim = DuelSim.new(p1_data, p1_data, _new_seed())
	sim.opening_lock_frames = OPENING_LOCK_FRAMES
	sim.p1.hp = p1_data.max_hp
	sim.p2.hp = p1_data.max_hp
	sim.p1.flow = p1_data.start_flow
	sim.p2.flow = p1_data.start_flow

	_clear_queued_input()
	_settled = false
	_start_cue_played = false
	_close_pause_panel()

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
	_clear_input_flags()
	_restart_queued = false


func _clear_input_flags() -> void:
	_attack_queued = false
	_guard_queued = false
	_spell_queued = false
	_p2_attack_queued = false
	_p2_guard_queued = false
	_p2_spell_queued = false


func _on_offer_chosen(index: int) -> void:
	if run == null or run.phase != RunState.Phase.REWARD:
		return
	if run.apply_offer(index):
		_start_stage()


func _setup_input() -> void:
	_context = InputGuide.context_for(mode)
	_offer_actions.clear()
	if _context == null:
		push_error("DuelController: 缺少 GUIDE 上下文资源 %s" % InputGuide.context_path(mode))
		return

	var meta := GameBootstrap.meta if GameBootstrap != null else null
	# 资源里是默认绑定；玩家改过的键用 GUIDERemappingConfig 覆盖，不动资源本身。
	var remap := InputGuide.build_remap_config(_context, meta)
	if remap != null:
		GUIDE.set_remapping_config(remap)

	_attack_action = InputGuide.action(_context, &"duel_attack_p1")
	_guard_action = InputGuide.action(_context, &"duel_guard_p1")
	_spell_action = InputGuide.action(_context, &"duel_spell_p1")
	_p2_attack_action = InputGuide.action(_context, &"duel_attack_p2")
	_p2_guard_action = InputGuide.action(_context, &"duel_guard_p2")
	_p2_spell_action = InputGuide.action(_context, &"duel_spell_p2")
	_restart_action = InputGuide.action(_context, &"duel_restart")
	_pause_action = InputGuide.action(_context, &"duel_pause")

	if _attack_action != null:
		_attack_action.just_triggered.connect(_on_attack_pressed)
	if _guard_action != null:
		_guard_action.just_triggered.connect(_on_guard_pressed)
		_guard_action.completed.connect(_on_guard_released)
	if _spell_action != null:
		_spell_action.just_triggered.connect(_on_spell_pressed)
	if _p2_attack_action != null:
		_p2_attack_action.just_triggered.connect(_on_p2_attack_pressed)
	if _p2_guard_action != null:
		_p2_guard_action.just_triggered.connect(_on_p2_guard_pressed)
		_p2_guard_action.completed.connect(_on_p2_guard_released)
	if _p2_spell_action != null:
		_p2_spell_action.just_triggered.connect(_on_p2_spell_pressed)
	if _restart_action != null:
		_restart_action.just_triggered.connect(_on_restart_pressed)
	if _pause_action != null:
		_pause_action.just_triggered.connect(_on_pause_pressed)

	for i in OFFER_KEYS.size():
		var offer := InputGuide.action(_context, StringName("duel_offer_%d" % (i + 1)))
		if offer == null:
			continue
		offer.just_triggered.connect(_on_offer_key.bind(i))
		_offer_actions.append(offer)

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


func _on_attack_pressed() -> void:
	_attack_queued = true


func _on_guard_pressed() -> void:
	_guard_queued = true
	_guard_held = true


func _on_guard_released() -> void:
	_guard_held = false


func _on_spell_pressed() -> void:
	_spell_queued = true


func _on_p2_attack_pressed() -> void:
	_p2_attack_queued = true


func _on_p2_guard_pressed() -> void:
	_p2_guard_queued = true
	_p2_guard_held = true


func _on_p2_guard_released() -> void:
	_p2_guard_held = false


func _on_p2_spell_pressed() -> void:
	_p2_spell_queued = true


func _on_restart_pressed() -> void:
	_restart_queued = true


func _on_pause_pressed() -> void:
	if sim == null:
		return
	var now := Time.get_ticks_msec()
	if now - _last_pause_ms < 200:
		return
	_last_pause_ms = now
	if _paused:
		# 与面板「继续」按钮走同一条路径：统一清队列 + 恢复奖励焦点。
		_on_resume_requested()
	else:
		_open_pause_panel()


## 暂停面板走 UIManager 的 POPUP 层：遮罩、层级、关闭生命周期都由插件管。
func _open_pause_panel() -> void:
	var panel := UIManager.open_panel(PanelIds.pause()) as PauseMenu
	if panel == null:
		return
	panel.resume_requested.connect(_on_resume_requested)
	panel.restart_requested.connect(_on_pause_restart_requested)
	panel.menu_requested.connect(_on_pause_menu_requested)
	_paused = true
	# 粒子是自己积分的，不吃 SceneTree.paused：暂停时手动冻结，恢复时解冻。
	if _view != null:
		_view.set_paused(true)


func _close_pause_panel() -> void:
	if UIManager.is_panel_open(PanelIds.pause()):
		UIManager.close_panel(PanelIds.pause())
	_paused = false
	if _view != null:
		_view.set_paused(false)


func _on_resume_requested() -> void:
	_close_pause_panel()
	_clear_queued_input()
	# 奖励阶段被暂停打断：恢复后把焦点还给奖励按钮，
	# 否则纯手柄玩家会卡在没有焦点的奖励界面（审计 P1-4）。
	if _hud != null and run != null and run.phase == RunState.Phase.REWARD:
		_hud.focus_rewards()


func _on_pause_restart_requested() -> void:
	_close_pause_panel()
	_clear_queued_input()
	if mode == &"versus":
		_start_versus()
	elif run != null:
		if run.phase == RunState.Phase.FAILED or run.phase == RunState.Phase.CLEAR:
			run.restart_run()
		_start_stage()


func _on_pause_menu_requested() -> void:
	_close_pause_panel()
	var error := get_tree().change_scene_to_file(MENU_SCENE)
	if error != OK:
		push_error("Duel: 无法返回主菜单 %s（错误码 %d）" % [MENU_SCENE, error])


func _on_offer_key(index: int) -> void:
	# 暂停期间按 1/2/3 不进选择：恢复后再按一次即可（审计 P1-1 同源）。
	if _paused:
		return
	_on_offer_chosen(index)
