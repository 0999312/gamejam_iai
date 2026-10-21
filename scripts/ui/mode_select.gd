class_name ModeSelectPanel
extends UIPanel

## 模式选择二级菜单（UIManager 面板）：单人阶梯 / 本地双人 / 返回。
##
## 主菜单原先同时放了「开始」与「本地双人」两个入口，六个按钮把 720px 高的
## 竖排容器撑到与标题、副标题重叠（用户 2026-10-21 反馈）。现在主菜单只留
## 一个「开始游戏」，具体模式在这里选。

signal mode_chosen(mode: StringName)

const FONT := preload("res://assets/fonts/MiSans-Semibold.otf")
const CLICK := preload("res://assets/audio/sfx/sfx_ui_click.ogg")

var _solo_button: Button


func _on_init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _enter_tree() -> void:
	EventBus.subscribe(&"LanguageChangedEvent", _on_language_changed)


func _exit_tree() -> void:
	EventBus.unsubscribe(&"LanguageChangedEvent", _on_language_changed)


func _ready() -> void:
	_build_ui()


func _on_open(_data: Dictionary = {}) -> void:
	call_deferred("_focus_default")


func _focus_default() -> void:
	if _solo_button != null:
		_solo_button.grab_focus()


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
	_solo_button = null

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.05, 0.07, 0.9)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var title := Label.new()
	title.text = _tr("menu.mode_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 150
	title.offset_bottom = 220
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("#e9eef5"))
	add_child(title)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_top = 120
	add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(380, 300)
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	var hint := Label.new()
	hint.text = _tr("menu.mode_hint")
	hint.custom_minimum_size = Vector2(380, 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_override("font", FONT)
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color("#7f8b9c"))
	box.add_child(hint)

	_solo_button = _make_button(box, _tr("menu.mode_solo"))
	_solo_button.pressed.connect(_on_solo_pressed)

	var versus := _make_button(box, _tr("menu.mode_versus"))
	versus.pressed.connect(_on_versus_pressed)

	var back := _make_button(box, _tr("menu.mode_back"))
	back.pressed.connect(_on_back_pressed)


func _make_button(parent: Control, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(380, 58)
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 22)
	UiFocus.prepare(button)
	parent.add_child(button)
	return button


func _on_solo_pressed() -> void:
	SoundManager.play_ui_sound(CLICK)
	mode_chosen.emit(&"run")


func _on_versus_pressed() -> void:
	SoundManager.play_ui_sound(CLICK)
	mode_chosen.emit(&"versus")


func _on_back_pressed() -> void:
	SoundManager.play_ui_sound(CLICK)
	UIManager.back(UILayer.NORMAL)


func _tr(key: String) -> String:
	var text := I18NManager.get_text(key)
	if text == key:
		return "[占位] " + key
	return text
