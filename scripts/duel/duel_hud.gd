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
var _p1_spell: Label
var _p2_hp: Label
var _p2_flow_bar: ProgressBar
var _p2_flow_text: Label
var _p2_spell: Label
var _center: Label
var _start_cue: Label
var _spell_banner: Label
var _banner_until_frame: int = -1
var _banner_text: String = ""
var _banner_side: int = -1
## 符卡发不出去时把对应那一行标红几帧，避免「按了没反应」。
var _p1_spell_fail_until: int = -1
var _p2_spell_fail_until: int = -1
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
	_p1_spell = _make_label(root, Vector2(40, 104), 16, HORIZONTAL_ALIGNMENT_LEFT)

	_p2_hp = _make_label(root, Vector2(980, 24), 24, HORIZONTAL_ALIGNMENT_RIGHT)
	_p2_flow_bar = _make_bar(root, Vector2(980, 62))
	_p2_flow_text = _make_label(root, Vector2(980, 82), 16, HORIZONTAL_ALIGNMENT_RIGHT)
	_p2_spell = _make_label(root, Vector2(980, 104), 16, HORIZONTAL_ALIGNMENT_RIGHT)

	_center = _make_label(root, Vector2(0, 118), 18, HORIZONTAL_ALIGNMENT_CENTER)
	_center.size = Vector2(1280, 28)

	_run_info = _make_label(root, Vector2(0, 152), 18, HORIZONTAL_ALIGNMENT_CENTER)
	_run_info.size = Vector2(1280, 28)

	_start_cue = _make_label(root, Vector2(0, 300), 64, HORIZONTAL_ALIGNMENT_CENTER)
	_start_cue.size = Vector2(1280, 80)
	_start_cue.add_theme_color_override("font_color", Color("#ffd36e"))
	_start_cue.visible = false

	_spell_banner = _make_label(root, Vector2(0, 246), 42, HORIZONTAL_ALIGNMENT_CENTER)
	_spell_banner.size = Vector2(1280, 56)
	_spell_banner.visible = false

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
	if sim != null:
		if sim.spell_cast.is_connected(_on_spell_cast):
			sim.spell_cast.disconnect(_on_spell_cast)
		if sim.spell_interrupted.is_connected(_on_spell_interrupted):
			sim.spell_interrupted.disconnect(_on_spell_interrupted)
		if sim.spell_failed.is_connected(_on_spell_failed):
			sim.spell_failed.disconnect(_on_spell_failed)
	sim = p_sim
	_p1_spell_fail_until = -1
	_p2_spell_fail_until = -1
	_banner_until_frame = -1
	if sim != null:
		sim.spell_cast.connect(_on_spell_cast)
		sim.spell_interrupted.connect(_on_spell_interrupted)
		sim.spell_failed.connect(_on_spell_failed)
	refresh()


func set_run(p_run: RunState) -> void:
	run = p_run
	refresh()


func set_versus(value: bool) -> void:
	versus = value
	refresh()


## 当前心流档位下这一刀的实际前摇帧数（HUD 直接给出数字，不再靠体感猜）。
func _commit_frames(fighter: FighterState) -> int:
	var tier := DuelTypes.tier_for_flow(fighter.flow)
	return maxi(DuelSim.COMMIT_MIN_FRAMES,
			fighter.data.base_commit + DuelTypes.COMMIT_TIER_OFFSET[tier])


## 当前心流档位下的实际「架」持续帧数（含心得/残心加成）。
func _guard_frames(fighter: FighterState) -> int:
	return fighter.data.guard_duration_base + DuelTypes.GUARD_TIER_OFFSET[DuelTypes.tier_for_flow(fighter.flow)]


## 心流条随档位换色，升档时整个数值区更亮，补足「心流变强了」的即时反馈。
func _tier_color(flow: int) -> Color:
	if flow >= 67:
		return Color("#9ff0d0")
	if flow >= 34:
		return Color("#d8b45a")
	return Color("#8b97a6")


func _spell_ready(fighter: FighterState) -> bool:
	return fighter.spell_card != null \
			and fighter.spell_uses_left > 0 \
			and fighter.flow >= fighter.spell_card.flow_cost


## 是否是「已付心流、正在等兑现」的蓄力中（含架势的安全区）。
func _spell_charging(fighter: FighterState) -> bool:
	var now: int = sim.frame if sim != null else 0
	return fighter.spell_pending_slash \
			or fighter.spell_power_amount > 0 \
			or fighter.spell_perfect_until_frame > now


func _spell_remaining(fighter: FighterState) -> int:
	var now: int = sim.frame if sim != null else 0
	if fighter.spell_perfect_until_frame > now:
		return fighter.spell_perfect_until_frame - now
	if fighter.state == DuelTypes.State.SPELL:
		return maxi(0, fighter.state_duration - fighter.state_frame)
	return 0


func _spell_modulate(fighter: FighterState) -> Color:
	if _spell_charging(fighter):
		return Color("#b79bff")
	if _spell_ready(fighter):
		return Color(1, 1, 1, 1.0)
	return Color(1, 1, 1, 0.45)


## 符卡行：就绪 / 蓄力中（▶剩余帧）/ 已用 / 心流不足。
func _spell_text(fighter: FighterState) -> String:
	var card := fighter.spell_card
	if card == null:
		return ""
	var name_text := _tr(card.name_key)
	if fighter.spell_uses_left <= 0:
		return "%s ×0" % name_text
	if _spell_charging(fighter):
		return "%s ×%d ▶%d" % [name_text, fighter.spell_uses_left, _spell_remaining(fighter)]
	return "%s ×%d (%d)" % [name_text, fighter.spell_uses_left, card.flow_cost]


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
	_p1_flow_bar.modulate = _tier_color(sim.p1.flow)
	_p1_flow_text.text = "%s %d · %df/%df" % [
		_tr("ui.flow"), sim.p1.flow, _commit_frames(sim.p1), _guard_frames(sim.p1),
	]
	_p1_spell.text = _spell_text(sim.p1)
	_p1_spell.modulate = _spell_modulate(sim.p1)
	if sim.frame < _p1_spell_fail_until:
		_p1_spell.modulate = Color("#ff6a6a")

	_p2_hp.text = "%s %d/%d" % [_tr("ui.hp"), sim.p2.hp, sim.p2.data.max_hp]
	_p2_flow_bar.value = sim.p2.flow
	_p2_flow_bar.modulate = _tier_color(sim.p2.flow)
	_p2_flow_text.text = "%s %d · %df/%df" % [
		_tr("ui.flow"), sim.p2.flow, _commit_frames(sim.p2), _guard_frames(sim.p2),
	]
	_p2_spell.text = _spell_text(sim.p2)
	_p2_spell.modulate = _spell_modulate(sim.p2)
	if sim.frame < _p2_spell_fail_until:
		_p2_spell.modulate = Color("#ff6a6a")

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

	# 符卡报幕：只显示符卡名（文案由人类提供），不附加任何 AI 撰写的动词。
	var banner_on := sim.frame < _banner_until_frame and not sim.finished
	_spell_banner.visible = banner_on
	if banner_on:
		_spell_banner.text = _banner_text
		_spell_banner.add_theme_color_override("font_color", _spell_banner_color(_banner_side))
		# 剩余时间越短越淡，避免硬切。
		var left := float(_banner_until_frame - sim.frame) / 96.0
		_spell_banner.modulate = Color(1, 1, 1, clampf(left * 2.0, 0.0, 1.0))


func _on_spell_cast(side: int, _effect: int) -> void:
	_show_banner(side)


func _on_spell_failed(side: int) -> void:
	if sim == null:
		return
	if side == DuelTypes.Side.P1:
		_p1_spell_fail_until = sim.frame + 16
	else:
		_p2_spell_fail_until = sim.frame + 16


func _on_spell_interrupted(side: int) -> void:
	_show_banner(side)


func _show_banner(side: int) -> void:
	if sim == null:
		return
	var fighter := sim.get_fighter(side)
	if fighter.spell_card == null:
		return
	_banner_side = side
	_banner_text = "◆ %s ◆" % _tr(fighter.spell_card.name_key)
	_banner_until_frame = sim.frame + 96


func _spell_banner_color(side: int) -> Color:
	return Color("#b79bff") if side == DuelTypes.Side.P1 else Color("#ff9bd0")


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
