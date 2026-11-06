class_name CharacterSelectPanel
extends UIPanel

## 角色选择二级面板：模式选完后在这里选角色（双人再各自选输入方式）。
##
## 单人只选 P1 角色；双人各自选角色与输入方式，允许双方都用手柄。
## 这里不检测手柄是否接入——手柄可以游戏中途插入，届时默认归 1P。

signal character_confirmed

const FONT := preload("res://assets/fonts/MiSans-Semibold.otf")
const CLICK := preload("res://assets/audio/sfx/sfx_ui_click.ogg")
const INPUT_KEYBOARD := &"keyboard"
const INPUT_GAMEPAD := &"gamepad"

var _mode: StringName = &"run"
var _p1_character: OptionButton
var _p2_character: OptionButton
var _p1_input: OptionButton
var _p2_input: OptionButton
var _p2_character_row: Control
var _p2_input_row: Control
var _start_button: Button


func _on_init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _enter_tree() -> void:
	EventBus.subscribe(&"LanguageChangedEvent", _on_language_changed)


func _exit_tree() -> void:
	EventBus.unsubscribe(&"LanguageChangedEvent", _on_language_changed)


func _ready() -> void:
	_build_ui()


func _on_open(data: Dictionary = {}) -> void:
	_mode = StringName(str(data.get("mode", &"run")))
	if _mode != &"versus":
		_mode = &"run"
	_build_ui()
	call_deferred("_focus_default")


func _focus_default() -> void:
	if _p1_character != null:
		_p1_character.grab_focus()


func _on_language_changed(_event: Event) -> void:
	if not is_inside_tree():
		return
	_build_ui()
	call_deferred("_focus_default")


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _build_ui() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_p1_character = null
	_p2_character = null
	_p1_input = null
	_p2_input = null
	_p2_character_row = null
	_p2_input_row = null
	_start_button = null

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.07, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var title := Label.new()
	title.text = _tr("menu.char_select_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 84
	title.offset_bottom = 146
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color("#e9eef5"))
	add_child(title)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 100
	add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(560, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var hint := Label.new()
	hint.text = _tr("menu.char_select_hint_versus" if _mode == &"versus" else "menu.char_select_hint_solo")
	hint.custom_minimum_size = Vector2(560, 44)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_override("font", FONT)
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color("#7f8b9c"))
	box.add_child(hint)

	_p1_character = _make_option_row(box, "menu.p1_character", _character_labels())
	_populate_characters(_p1_character, GameBootstrap.pending_character)

	if _mode == &"versus":
		_p1_input = _make_option_row(box, "menu.p1_input", _input_labels())
		_populate_inputs(_p1_input, GameBootstrap.pending_input_p1)

		_p2_character = _make_option_row(box, "menu.p2_character", _character_labels())
		_populate_characters(_p2_character, GameBootstrap.pending_character_p2)
		_p2_input = _make_option_row(box, "menu.p2_input", _input_labels())
		_populate_inputs(_p2_input, GameBootstrap.pending_input_p2)

	_start_button = _make_button(box, _tr("menu.start_duel"))
	_start_button.pressed.connect(_on_start_pressed)

	var back := _make_button(box, _tr("menu.mode_back"))
	back.pressed.connect(_on_back_pressed)


func _character_labels() -> Array[String]:
	var labels: Array[String] = []
	var meta := GameBootstrap.meta if GameBootstrap != null else null
	for id in Unlocks.character_ids(meta):
		labels.append(_tr("menu.%s" % String(id)))
	return labels


func _input_labels() -> Array[String]:
	return [_tr("menu.input_keyboard"), _tr("menu.input_gamepad")]


func _make_option_row(parent: Control, label_key: String, items: Array[String]) -> OptionButton:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(560, 44)
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var label := Label.new()
	label.text = _tr(label_key)
	label.custom_minimum_size = Vector2(200, 44)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color("#c7d2df"))
	row.add_child(label)

	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(348, 44)
	option.add_theme_font_override("font", FONT)
	option.add_theme_font_size_override("font_size", 18)
	option.fit_to_longest_item = false
	UiFocus.prepare(option)
	row.add_child(option)
	for item in items:
		option.add_item(item)
	return option


func _populate_characters(option: OptionButton, selected_id: StringName) -> void:
	if option == null:
		return
	var meta := GameBootstrap.meta if GameBootstrap != null else null
	var ids := Unlocks.character_ids(meta)
	option.clear()
	if ids.is_empty():
		option.add_item(_tr("menu.char_a"))
		option.set_item_metadata(0, "char_a")
		option.select(0)
		return
	var selected := 0
	for i in ids.size():
		var id := ids[i]
		option.add_item(_tr("menu.%s" % String(id)))
		option.set_item_metadata(i, String(id))
		if id == selected_id:
			selected = i
	option.select(selected)


func _populate_inputs(option: OptionButton, method: StringName) -> void:
	if option == null:
		return
	option.clear()
	option.add_item(_tr("menu.input_keyboard"))
	option.set_item_metadata(0, INPUT_KEYBOARD)
	option.add_item(_tr("menu.input_gamepad"))
	option.set_item_metadata(1, INPUT_GAMEPAD)
	option.select(1 if method == INPUT_GAMEPAD else 0)
	option.item_selected.connect(_on_input_selected.bind(option))


func _on_input_selected(_index: int, _option: OptionButton) -> void:
	# 双方都可用手柄：P1 用第一只手柄，P2 用第二只手柄，互不挤占。
	SoundManager.play_ui_sound(CLICK)


func _selected_input(option: OptionButton) -> StringName:
	if option == null or option.selected < 0:
		return INPUT_KEYBOARD
	return StringName(option.get_item_metadata(option.selected))


func _selected_character(option: OptionButton, fallback: StringName) -> StringName:
	if option == null or option.selected < 0:
		return fallback
	return StringName(option.get_item_metadata(option.selected))


func _make_button(parent: Control, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(560, 54)
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 22)
	UiFocus.prepare(button)
	parent.add_child(button)
	return button


func _on_start_pressed() -> void:
	SoundManager.play_ui_sound(CLICK)
	GameBootstrap.pending_character = _selected_character(_p1_character, &"char_a")
	if _mode == &"versus":
		GameBootstrap.pending_character_p2 = _selected_character(_p2_character, &"char_a")
		GameBootstrap.pending_input_p1 = _selected_input(_p1_input)
		GameBootstrap.pending_input_p2 = _selected_input(_p2_input)
	else:
		# 单人沿用旧行为：键鼠与手柄同时可用，这里的选择不参与映射。
		GameBootstrap.pending_input_p1 = INPUT_KEYBOARD
		GameBootstrap.pending_input_p2 = INPUT_KEYBOARD
	character_confirmed.emit()


func _on_back_pressed() -> void:
	SoundManager.play_ui_sound(CLICK)
	UIManager.back(UILayer.NORMAL)


func _tr(key: String) -> String:
	var text := I18NManager.get_text(key)
	# 缺键留空，由界面标识空位；不再输出占位前缀（2026-11-06 人类指令）。
	if text == key or text.is_empty():
		push_warning("I18N missing key: " + key)
		return ""
	return text
