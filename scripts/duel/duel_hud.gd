class_name DuelHud
extends CanvasLayer

## 灰盒 HUD：I18N 文本 + 数值条 + 三选一按钮；正式文案由人类替换。

signal offer_chosen(index: int)

const FONT := preload("res://assets/fonts/MiSans-Semibold.otf")

var sim: DuelSim
var run: RunState
var versus: bool = false

var _p1_hp: Label
var _p1_flow_bar: ProgressBar
var _p1_flow_text: Label
var _p2_hp: Label
var _p2_flow_bar: ProgressBar
var _p2_flow_text: Label
var _center: Label
var _start_cue: Label
var _run_info: Label
var _tutorial: Label
var _result: Label
var _controls: Label
var _reward_box: VBoxContainer
var _reward_dim: ColorRect
var _reward_title: Label
var _reward_hint: Label
var _reward_buttons: Array[Button] = []


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.name = "HudRoot"
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_reward_dim = ColorRect.new()
	_reward_dim.color = Color(0, 0, 0, 0.55)
	_reward_dim.position = Vector2.ZERO
	_reward_dim.size = Vector2(1280, 720)
	_reward_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reward_dim.visible = false
	root.add_child(_reward_dim)

	_p1_hp = _make_label(root, Vector2(40, 24), 24, HORIZONTAL_ALIGNMENT_LEFT)
	_p1_flow_bar = _make_bar(root, Vector2(40, 62))
	_p1_flow_text = _make_label(root, Vector2(40, 82), 16, HORIZONTAL_ALIGNMENT_LEFT)

	_p2_hp = _make_label(root, Vector2(980, 24), 24, HORIZONTAL_ALIGNMENT_RIGHT)
	_p2_flow_bar = _make_bar(root, Vector2(980, 62))
	_p2_flow_text = _make_label(root, Vector2(980, 82), 16, HORIZONTAL_ALIGNMENT_RIGHT)

	_center = _make_label(root, Vector2(0, 118), 18, HORIZONTAL_ALIGNMENT_CENTER)
	_center.size = Vector2(1280, 28)

	_run_info = _make_label(root, Vector2(0, 152), 18, HORIZONTAL_ALIGNMENT_CENTER)
	_run_info.size = Vector2(1280, 28)

	_start_cue = _make_label(root, Vector2(0, 300), 64, HORIZONTAL_ALIGNMENT_CENTER)
	_start_cue.size = Vector2(1280, 80)
	_start_cue.add_theme_color_override("font_color", Color("#ffd36e"))
	_start_cue.visible = false

	_controls = _make_label(root, Vector2(0, 652), 18, HORIZONTAL_ALIGNMENT_CENTER)
	_controls.size = Vector2(1280, 28)
	_controls.text = _tr("ui.controls")

	_tutorial = _make_label(root, Vector2(0, 596), 20, HORIZONTAL_ALIGNMENT_CENTER)
	_tutorial.size = Vector2(1280, 30)

	_result = _make_label(root, Vector2(0, 196), 44, HORIZONTAL_ALIGNMENT_CENTER)
	_result.size = Vector2(1280, 60)
	_result.visible = false

	_reward_box = VBoxContainer.new()
	_reward_box.position = Vector2(380, 260)
	_reward_box.size = Vector2(520, 320)
	_reward_box.add_theme_constant_override("separation", 12)
	_reward_box.visible = false
	root.add_child(_reward_box)

	_reward_title = Label.new()
	_reward_title.text = _tr("ui.reward_title")
	_reward_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_title.add_theme_font_size_override("font_size", 26)
	_reward_title.add_theme_font_override("font", FONT)
	_reward_title.add_theme_color_override("font_color", Color("#e9eef5"))
	_reward_box.add_child(_reward_title)

	_reward_hint = Label.new()
	_reward_hint.text = _tr("ui.reward_hint")
	_reward_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_hint.add_theme_font_size_override("font_size", 16)
	_reward_hint.add_theme_font_override("font", FONT)
	_reward_hint.add_theme_color_override("font_color", Color("#9aa7b8"))
	_reward_box.add_child(_reward_hint)

	for i in 3:
		var button := Button.new()
		button.custom_minimum_size = Vector2(520, 64)
		button.add_theme_font_override("font", FONT)
		button.pressed.connect(_on_reward_button.bind(i))
		UiFocus.prepare(button)
		_reward_box.add_child(button)
		_reward_buttons.append(button)


func bind(p_sim: DuelSim) -> void:
	sim = p_sim
	refresh()


func set_run(p_run: RunState) -> void:
	run = p_run
	refresh()


func set_versus(value: bool) -> void:
	versus = value
	refresh()


func _controls_text() -> String:
	var meta := GameBootstrap.meta if GameBootstrap != null else null
	if meta == null:
		return _tr("ui.controls_versus" if versus else "ui.controls")
	var template := _tr("ui.controls_versus_template" if versus else "ui.controls_template")
	if template.begins_with("[占位]"):
		return _tr("ui.controls_versus" if versus else "ui.controls")
	return template \
		.replace("%a", KeyBindings.label(meta, &"attack_p1")) \
		.replace("%g", KeyBindings.label(meta, &"guard_p1")) \
		.replace("%d", KeyBindings.label(meta, &"attack_p2")) \
		.replace("%f", KeyBindings.label(meta, &"guard_p2")) \
		.replace("%r", KeyBindings.label(meta, &"restart")) \
		.replace("%p", KeyBindings.label(meta, &"pause"))


func refresh() -> void:
	if sim == null:
		return
	_p1_hp.text = "%s %d/%d" % [_tr("ui.hp"), sim.p1.hp, sim.p1.data.max_hp]
	_p1_flow_bar.value = sim.p1.flow
	_p1_flow_text.text = "%s %d" % [_tr("ui.flow"), sim.p1.flow]

	_p2_hp.text = "%s %d/%d" % [_tr("ui.hp"), sim.p2.hp, sim.p2.data.max_hp]
	_p2_flow_bar.value = sim.p2.flow
	_p2_flow_text.text = "%s %d" % [_tr("ui.flow"), sim.p2.flow]

	_center.text = "%s %s / %s" % [
		_tr("ui.state"),
		_state_label(sim.p1.state),
		_state_label(sim.p2.state),
	]

	_controls.text = _controls_text()

	if run != null and not versus:
		_run_info.text = "%s %d/%d  %s %d  %s %d" % [
			_tr("ui.run"), run.stage_index + 1, RunState.STAGE_COUNT,
			_tr("ui.gold"), run.gold,
			_tr("ui.zanshin"), run.zanshin,
		]
	elif versus:
		_run_info.text = _tr("ui.versus")
	else:
		_run_info.text = ""

	_result.visible = sim.finished

	var cue_end := sim.opening_lock_frames + 42
	_start_cue.visible = not sim.finished and sim.frame >= sim.opening_lock_frames and sim.frame < cue_end
	if _start_cue.visible:
		_start_cue.text = _tr("ui.round_start")
	if sim.finished:
		if versus:
			_result.text = _tr("ui.result_p1" if sim.winner == DuelTypes.Side.P1 else "ui.result_p2")
		elif run != null:
			match run.phase:
				RunState.Phase.REWARD:
					_result.text = _tr("ui.result_win")
				RunState.Phase.FAILED:
					_result.text = _tr("ui.result_lose")
				RunState.Phase.CLEAR:
					_result.text = _tr("ui.result_clear")
				_:
					_result.text = ""
		else:
			_result.text = ""

	_tutorial.text = "" if versus else _tutorial_text()


func show_rewards(offers: Array) -> void:
	if offers.is_empty():
		_reward_box.visible = false
		_reward_dim.visible = false
		return
	for i in _reward_buttons.size():
		var button := _reward_buttons[i]
		if i < offers.size():
			var id: StringName = offers[i]
			var label: String = String(id)
			var desc := ""
			if run != null:
				label = run.upgrade_label(id)
				desc = run.upgrade_desc(id)
			button.text = "%d. %s\n%s" % [i + 1, label, desc]
			button.visible = true
		else:
			button.visible = false
	_reward_box.visible = true
	_reward_dim.visible = true
	for i in _reward_buttons.size():
		var focus_button := _reward_buttons[i]
		if focus_button.visible and not focus_button.disabled:
			focus_button.grab_focus()
			break


func hide_rewards() -> void:
	_reward_box.visible = false
	_reward_dim.visible = false
	if get_viewport() != null:
		get_viewport().gui_release_focus()


func _on_reward_button(index: int) -> void:
	SoundManager.play_ui_sound(preload("res://assets/audio/sfx/sfx_ui_click.ogg"))
	offer_chosen.emit(index)


func _tutorial_text() -> String:
	if sim == null or sim.finished:
		return ""
	if sim.frame < sim.opening_lock_frames:
		return _tr("tutorial.start")
	if sim.p2.state == DuelTypes.State.COMMIT:
		return _tr("tutorial.guard")
	if sim.p2.state == DuelTypes.State.RECOVERY or sim.p2.state == DuelTypes.State.GUARD_REC:
		return _tr("tutorial.attack")
	if sim.p1.flow <= 20:
		return _tr("tutorial.flow")
	return _tr("tutorial.wait")


func _state_label(state: int) -> String:
	return _tr("state." + DuelTypes.state_name(state).to_lower())


func _tr(key: String) -> String:
	var text := I18NManager.get_text(key)
	if text == key:
		return "[占位] " + key
	return text


func _make_label(parent: Control, pos: Vector2, font_size: int, align: int) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = Vector2(260, 34)
	label.horizontal_alignment = align
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("#e9eef5"))
	parent.add_child(label)
	return label


func _make_bar(parent: Control, pos: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.position = pos
	bar.size = Vector2(260, 14)
	bar.max_value = 100.0
	bar.show_percentage = false
	parent.add_child(bar)
	return bar
