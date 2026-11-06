extends Node2D

## 灰盒对决控制器：GUIDE 输入 + RunState 阶梯 / 本地双人 + 表现层。
## 单人：P1 键鼠与手柄同时可用。
## 本地双人：角色与输入方式由选人面板决定（双方键鼠、一人键鼠一人手柄、双方手柄）；
## 游戏中途接入手柄默认给 P1（此时键鼠为 P2），第二只手柄插入后补齐 P2。
## R 重开；Esc 暂停；1–3 选心得。

const VIEW_SCENE := preload("res://scenes/duel/duel_view.tscn")
const HUD_SCENE := preload("res://scenes/duel/hud.tscn")
const MENU_SCENE := "res://scenes/menu/menu.tscn"

const OFFER_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3]

## 单人阶梯前四关的敌方图集：第 N 关给 P2 席位换 skeleton_eN 贴图。
## BOSS 关（第 5 关）不在此表，沿用默认 P2 图集；本地双人同理。
const STAGE_ENEMY_ATLASES: Array[String] = [
	"res://resources/spine/skeleton_e1.atlas",
	"res://resources/spine/skeleton_e2.atlas",
	"res://resources/spine/skeleton_e3.atlas",
	"res://resources/spine/skeleton_e4.atlas",
]

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
var _p1_uses_gamepad := false
var _p2_uses_gamepad := false
## 玩家在选人面板的偏好；实际是否用手柄还要看当前接入数量（第二只插入后自动补齐）。
var _p1_wants_gamepad := false
var _p2_wants_gamepad := false
var _last_pause_ms := -1000


func _ready() -> void:
	mode = GameBootstrap.pending_mode if GameBootstrap != null else &"run"
	if mode != &"versus":
		mode = &"run"

	_run_seed = _new_seed()

	_read_input_assignment()
	_sync_raw_devices()
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
		# 恢复后仍以为玩家按着架。双方手柄时必须按设备分席，不能互相清架。
		var release_slot := _raw_slot_for_device(joy.device, false)
		if release_slot == 0:
			_guard_held = false
		elif release_slot == 1:
			_p2_guard_held = false
		return
	if _paused:
		# 暂停期间只允许用暂停键恢复；攻击/架/符卡/重开一律丢弃。
		# 否则暂停时按下的键会留在队列里，恢复的第一帧立刻出刀（审计 P1-1）。
		if joy.button_index == KeyBindings.get_joy_button(meta, &"pause"):
			_on_pause_pressed()
		return

	var slot := _raw_slot_for_device(joy.device, true)
	var button := joy.button_index
	if slot == 0:
		if button == KeyBindings.get_joy_button(meta, &"attack_p1"):
			_attack_queued = true
		elif button == KeyBindings.get_joy_button(meta, &"guard_p1"):
			_guard_queued = true
			_guard_held = true
		elif button == KeyBindings.get_joy_button(meta, &"spell_p1"):
			_spell_queued = true
	elif slot == 1:
		if button == KeyBindings.get_joy_button(meta, &"attack_p2"):
			_p2_attack_queued = true
		elif button == KeyBindings.get_joy_button(meta, &"guard_p2"):
			_p2_guard_queued = true
			_p2_guard_held = true
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
		_view.set_seat_atlas(enemy_atlas_for_stage(run.stage_index))
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
	var p2_data := FighterData.for_character(
		GameBootstrap.pending_character_p2 if GameBootstrap != null else &"char_a"
	)
	sim = DuelSim.new(p1_data, p2_data, _new_seed())
	sim.opening_lock_frames = OPENING_LOCK_FRAMES
	sim.p1.hp = p1_data.max_hp
	sim.p2.hp = p2_data.max_hp
	sim.p1.flow = p1_data.start_flow
	sim.p2.flow = p2_data.start_flow

	_clear_queued_input()
	_settled = false
	_start_cue_played = false
	_close_pause_panel()

	if _view != null:
		_view.set_seat_atlas(null)
		_view.bind(sim)
	if _audio != null:
		_audio.bind(sim)
	if _hud != null:
		_hud.set_input_methods(_p1_uses_gamepad, _p2_uses_gamepad)
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


## 第 N 关（0 基）的敌方图集；BOSS 关、越界或资源缺失都返回 null，
## 让 DuelView 沿用默认 P2 图集，不影响开局。
static func enemy_atlas_for_stage(stage_index: int) -> Resource:
	if stage_index < 0 or stage_index >= STAGE_ENEMY_ATLASES.size():
		return null
	var path: String = STAGE_ENEMY_ATLASES[stage_index]
	if not ResourceLoader.exists(path):
		push_warning("DuelController: 敌方图集缺失 %s，回退默认 P2 图集" % path)
		return null
	return load(path)


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
	# 双人再按选人面板的输入方式重排玩家槽位（双方键鼠、一人手柄或双方手柄）。
	var remap := InputGuide.build_remap_config(
		_context, meta, mode == &"versus", _p1_uses_gamepad, _p2_uses_gamepad
	)
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


func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	var old_p1 := _raw_p1_device
	var old_p2 := _raw_p2_device
	if mode == &"versus":
		var pads := Input.get_connected_joypads()
		if connected and not _p1_wants_gamepad and not _p2_wants_gamepad:
			# 需求：不预判手柄是否接入；双方键鼠时中途插入的手柄默认归 P1，键鼠归 P2。
			_p1_wants_gamepad = true
			_p2_wants_gamepad = false
			if GameBootstrap != null:
				GameBootstrap.pending_input_p1 = &"gamepad"
				GameBootstrap.pending_input_p2 = &"keyboard"
		_apply_effective_assignment()
		if not connected and pads.size() == 1 and _p1_wants_gamepad and _p2_wants_gamepad:
			# 双方原本都用手柄，拔掉一只后若剩下的正是 P2 的手柄，
			# 保留 P2 席位，避免把剩下的手柄错绑给 P1。
			if old_p2 == pads[0] and old_p2 != old_p1:
				_p1_uses_gamepad = false
				_p2_uses_gamepad = true
		_sync_raw_devices()
	else:
		_sync_raw_devices()
	_rebuild_input()


## 偏好 + 当前手柄数 → 实际席位。手柄不足时先退回键鼠，第二只插入后自动补齐。
func _resolve_gamepad_assignment(
	p1_wants: bool, p2_wants: bool, pad_count: int
) -> Vector2i:
	if not p1_wants and not p2_wants:
		return Vector2i.ZERO
	if p1_wants and p2_wants:
		if pad_count >= 2:
			return Vector2i(1, 1)
		if pad_count == 1:
			return Vector2i(1, 0)
		return Vector2i.ZERO
	if p1_wants:
		return Vector2i(1, 0) if pad_count >= 1 else Vector2i.ZERO
	return Vector2i(0, 1) if pad_count >= 1 else Vector2i.ZERO


func _apply_effective_assignment() -> void:
	var resolved := _resolve_gamepad_assignment(
		_p1_wants_gamepad, _p2_wants_gamepad, Input.get_connected_joypads().size()
	)
	_p1_uses_gamepad = resolved.x == 1
	_p2_uses_gamepad = resolved.y == 1


func _read_input_assignment() -> void:
	_p1_wants_gamepad = false
	_p2_wants_gamepad = false
	if mode == &"versus" and GameBootstrap != null:
		_p1_wants_gamepad = GameBootstrap.pending_input_p1 == &"gamepad"
		_p2_wants_gamepad = GameBootstrap.pending_input_p2 == &"gamepad"
	_apply_effective_assignment()


func _sync_raw_devices() -> void:
	var pads := Input.get_connected_joypads()
	_raw_p1_device = -1
	_raw_p2_device = -1
	if mode != &"versus":
		if pads.size() >= 1:
			_raw_p1_device = pads[0]
		return
	if _p1_uses_gamepad and pads.size() >= 1:
		_raw_p1_device = pads[0]
	if _p2_uses_gamepad:
		if _p1_uses_gamepad:
			if pads.size() >= 2:
				_raw_p2_device = pads[1]
		elif pads.size() >= 1:
			_raw_p2_device = pads[0]


## 原始手柄事件按实际设备分席。双方手柄时绝不能把两只手柄都算给 P1。
## claim=true 用于按下事件：设备尚未登记时按当时的席位认领；
## 松手事件 claim=false，只清已登记设备的架子，避免误认领。
func _raw_slot_for_device(device: int, claim: bool) -> int:
	if mode != &"versus":
		if claim and _raw_p1_device < 0:
			_raw_p1_device = device
		return 0
	if not _p1_uses_gamepad and not _p2_uses_gamepad:
		# 双方键鼠：手柄没有归属，玩家动作一律不接；暂停/重开仍可用。
		return -1
	if _p1_uses_gamepad and device == _raw_p1_device:
		return 0
	if _p2_uses_gamepad and device == _raw_p2_device:
		return 1
	if not claim:
		return -1
	if _p1_uses_gamepad and _raw_p1_device < 0:
		_raw_p1_device = device
		return 0
	if _p2_uses_gamepad and _raw_p2_device < 0 and device != _raw_p1_device:
		_raw_p2_device = device
		return 1
	return -1


## 热插拔：重建 GUIDE 上下文，按新的手柄数量重新分配 P1/P2 设备；
## 不改 sim 状态，因此对局可以继续。
func _rebuild_input() -> void:
	if _context != null:
		GUIDE.disable_mapping_context(_context)
		_context = null
	_clear_queued_input()
	# 重建后旧手柄的“按住架”已无从释放，必须主动复位，避免新席位继承旧按压。
	_guard_held = false
	_p2_guard_held = false
	_setup_input()
	if _hud != null:
		_hud.set_input_methods(_p1_uses_gamepad, _p2_uses_gamepad)


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
