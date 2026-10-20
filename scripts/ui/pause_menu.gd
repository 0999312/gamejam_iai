class_name PauseMenu
extends Control

## 对决内暂停层：继续 / 重新开始 / 返回菜单。
## 不暂停 SceneTree，由 DuelController 跳过 sim.tick()。

signal resume_requested()
signal restart_requested()
signal menu_requested()

const FONT := preload("res://assets/fonts/MiSans-Semibold.otf")
const CLICK := preload("res://assets/audio/sfx/sfx_ui_click.ogg")

var _resume_button: Button


func _ready() -> void:
	_build_ui()
	visible = false


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	var title := Label.new()
	title.text = _tr("pause.title")
	title.position = Vector2(0, 150)
	title.size = Vector2(1280, 70)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color("#e9eef5"))
	add_child(title)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(360, 260)
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	_resume_button = _make_button(box, _tr("pause.resume"))
	_resume_button.pressed.connect(_on_resume_pressed)
	var restart := _make_button(box, _tr("pause.restart"))
	restart.pressed.connect(_on_restart_pressed)
	var menu := _make_button(box, _tr("pause.menu"))
	menu.pressed.connect(_on_menu_pressed)


func _make_button(parent: Control, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(360, 58)
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 22)
	UiFocus.prepare(button)
	parent.add_child(button)
	return button


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_resume_pressed()


func show_pause() -> void:
	visible = true
	_resume_button.grab_focus()


func hide_pause() -> void:
	visible = false


func _on_resume_pressed() -> void:
	SoundManager.play_ui_sound(CLICK)
	resume_requested.emit()


func _on_restart_pressed() -> void:
	SoundManager.play_ui_sound(CLICK)
	restart_requested.emit()


func _on_menu_pressed() -> void:
	SoundManager.play_ui_sound(CLICK)
	menu_requested.emit()


func _tr(key: String) -> String:
	var text := I18NManager.get_text(key)
	if text == key:
		return "[占位] " + key
	return text
