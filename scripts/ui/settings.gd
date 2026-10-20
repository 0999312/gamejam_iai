extends Control

## 设置页：主音量 / 音效 / 环境音 / 静音 / 全屏。
## 设置写入 MetaSave.settings，应用交给 GameBootstrap。

const FONT := preload("res://assets/fonts/MiSans-Semibold.otf")
const MENU_SCENE := "res://scenes/menu/menu.tscn"
const CLICK := preload("res://assets/audio/sfx/sfx_ui_click.ogg")

var _master: HSlider
var _sfx: HSlider
var _ambient: HSlider
var _mute: CheckButton
var _fullscreen: CheckButton


func _ready() -> void:
	_build_ui()
	_load_values()


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#0b0e13")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title := Label.new()
	title.text = _tr("settings.title")
	title.position = Vector2(0, 48)
	title.size = Vector2(1280, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("#e9eef5"))
	add_child(title)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(560, 430)
	box.add_theme_constant_override("separation", 16)
	center.add_child(box)

	_master = _add_slider_row(box, "settings.master", 0.8)
	_sfx = _add_slider_row(box, "settings.sfx", 0.8)
	_ambient = _add_slider_row(box, "settings.ambient", 0.7)

	_mute = CheckButton.new()
	_mute.text = _tr("settings.mute")
	_mute.custom_minimum_size = Vector2(560, 48)
	_mute.add_theme_font_override("font", FONT)
	_mute.add_theme_font_size_override("font_size", 20)
	_mute.toggled.connect(_on_mute_toggled)
	box.add_child(_mute)

	_fullscreen = CheckButton.new()
	_fullscreen.text = _tr("settings.fullscreen")
	_fullscreen.custom_minimum_size = Vector2(560, 48)
	_fullscreen.add_theme_font_override("font", FONT)
	_fullscreen.add_theme_font_size_override("font_size", 20)
	_fullscreen.toggled.connect(_on_fullscreen_toggled)
	box.add_child(_fullscreen)

	var back := Button.new()
	back.text = _tr("settings.back")
	back.custom_minimum_size = Vector2(240, 52)
	back.add_theme_font_override("font", FONT)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(_on_back_pressed)
	box.add_child(back)


func _add_slider_row(parent: VBoxContainer, key: String, default_value: float) -> HSlider:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(560, 52)
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)

	var label := Label.new()
	label.text = _tr(key)
	label.custom_minimum_size = Vector2(150, 48)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_color_override("font_color", Color("#c7d2df"))
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = default_value * 100.0
	slider.custom_minimum_size = Vector2(380, 40)
	slider.value_changed.connect(_on_volume_changed.bind(key))
	row.add_child(slider)
	return slider


func _load_values() -> void:
	var meta := GameBootstrap.meta if GameBootstrap != null else null
	if meta == null:
		return
	_master.value = float(meta.settings.get("volume_master", 0.8)) * 100.0
	_sfx.value = float(meta.settings.get("volume_sfx", 0.8)) * 100.0
	_ambient.value = float(meta.settings.get("volume_ambient", 0.7)) * 100.0
	_mute.button_pressed = bool(meta.settings.get("mute", false))
	_fullscreen.button_pressed = bool(meta.settings.get("fullscreen", false))


func _on_volume_changed(value: float, key: String) -> void:
	var meta := GameBootstrap.meta if GameBootstrap != null else null
	if meta == null:
		return
	meta.settings[key] = clampf(value / 100.0, 0.0, 1.0)
	GameBootstrap.apply_settings()
	GameBootstrap.save_meta()


func _on_mute_toggled(pressed: bool) -> void:
	var meta := GameBootstrap.meta if GameBootstrap != null else null
	if meta == null:
		return
	meta.settings["mute"] = pressed
	GameBootstrap.apply_settings()
	GameBootstrap.save_meta()


func _on_fullscreen_toggled(pressed: bool) -> void:
	var meta := GameBootstrap.meta if GameBootstrap != null else null
	if meta == null:
		return
	meta.settings["fullscreen"] = pressed
	GameBootstrap.apply_settings()
	GameBootstrap.save_meta()


func _on_back_pressed() -> void:
	SoundManager.play_ui_sound(CLICK)
	get_tree().change_scene_to_file(MENU_SCENE)


func _tr(key: String) -> String:
	var text := I18NManager.get_text(key)
	if text == key:
		return "[占位] " + key
	return text
