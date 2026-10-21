class_name PauseMenu
extends UIPanel

## 对决暂停层（UIManager POPUP 面板）：继续 / 重新开始 / 返回菜单。
## 不暂停 SceneTree，由 DuelController 跳过 sim.tick()；
## 面板只发意图信号，开合与状态由控制器统一管理。

signal resume_requested()
signal restart_requested()
signal menu_requested()

const FONT := preload("res://assets/fonts/MiSans-Semibold.otf")
const CLICK := preload("res://assets/audio/sfx/sfx_ui_click.ogg")

var _resume_button: Button


func _on_init() -> void:
	ui_layer = UILayer.POPUP
	cache_mode = CacheMode.NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_build_ui()


func _on_open(_data: Dictionary = {}) -> void:
	if _resume_button != null:
		_resume_button.grab_focus()


func _build_ui() -> void:
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
