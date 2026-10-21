class_name SettingsPanel
extends UIPanel

## 设置页（UIManager 面板）：音量 / 静音 / 全屏 / 语言 / 按键。
## 设置写入 MetaSave.settings，应用交给 GameBootstrap。
## 语言切换走 I18NManager → LanguageChangedEvent，本面板自行重建文案，
## 不再 reload_current_scene。

const FONT := preload("res://assets/fonts/MiSans-Semibold.otf")
const CLICK := preload("res://assets/audio/sfx/sfx_ui_click.ogg")
const LANGUAGES: Array[String] = ["zh_CN", "en"]
const LANGUAGE_LABELS: Array[String] = ["中文", "English"]

var _master: HSlider
var _sfx: HSlider
var _ambient: HSlider
var _mute: CheckButton
var _fullscreen: CheckButton
var _language: OptionButton
var _key_buttons: Dictionary = {}
var _joy_buttons: Dictionary = {}
var _hint: Label
var _pads: Label
var _rebinding: StringName = &""
var _joy_rebinding: StringName = &""
## 音量拖动去抖：滑条每动 1 像素都会触发 value_changed，
## 直接写盘会变成几十次截断重写（审计 P2-14）。
var _save_timer: Timer
## 「清除存档」二次确认：第一次按下只是上膛，3 秒内再按才真的删。
var _wipe_button: Button
var _wipe_timer: Timer
var _wipe_armed := false


## 层级与缓存策略由 GameBootstrap 的注册表统一声明（单一来源），
## 这里只做面板自身的锚点与命中设置。
func _on_init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_ensure_timers()
	_build_ui()
	_load_values()
	_refresh_keys()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	EventBus.subscribe(&"LanguageChangedEvent", _on_language_changed)


## 计时器不是 UI 节点，_build_ui() 重建时不会删它们。
func _ensure_timers() -> void:
	if _save_timer == null:
		_save_timer = Timer.new()
		_save_timer.one_shot = true
		_save_timer.wait_time = 0.35
		_save_timer.timeout.connect(_flush_save)
		add_child(_save_timer)
	if _wipe_timer == null:
		_wipe_timer = Timer.new()
		_wipe_timer.one_shot = true
		_wipe_timer.wait_time = 3.0
		_wipe_timer.timeout.connect(_disarm_wipe)
		add_child(_wipe_timer)


func _on_open(_data: Dictionary = {}) -> void:
	_load_values()
	_refresh_keys()
	call_deferred("_focus_default")


func _focus_default() -> void:
	if _master != null:
		_master.grab_focus()


func _exit_tree() -> void:
	# 面板关闭时把去抖中的设置立刻落盘，避免「刚拖完就关页」丢设置。
	_flush_save()
	EventBus.unsubscribe(&"LanguageChangedEvent", _on_language_changed)
	if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)


func _on_language_changed(_event: Event) -> void:
	_rebuild_ui()


## 语言变了：原地重建所有文本，保留当前焦点语义（回到第一个滑条）。
func _rebuild_ui() -> void:
	if not is_inside_tree():
		return
	_cancel_rebind()
	_build_ui()
	_load_values()
	_refresh_keys()
	call_deferred("_focus_default")


func _on_joy_connection_changed(_device: int, _connected: bool) -> void:
	_refresh_keys()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _joy_rebinding != &"":
		_handle_joy_rebind(event)
		return
	if _rebinding != &"":
		_handle_key_rebind(event)
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back_pressed()


func _handle_key_rebind(event: InputEvent) -> void:
	var joy_event := event as InputEventJoypadButton
	if joy_event != null and joy_event.pressed and joy_event.button_index == JOY_BUTTON_B:
		get_viewport().set_input_as_handled()
		_cancel_rebind()
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	get_viewport().set_input_as_handled()
	var key: Key = key_event.keycode
	if key == KEY_NONE:
		key = key_event.physical_keycode
	if key == KEY_ESCAPE:
		_cancel_rebind()
		return
	var meta := GameBootstrap.meta if GameBootstrap != null else null
	if meta == null:
		_cancel_rebind()
		return
	if KeyBindings.set_key(meta, _rebinding, key):
		GameBootstrap.save_meta()
		_rebinding = &""
		_hint.text = ""
		_refresh_keys()
	else:
		_hint.text = _tr("settings.key_conflict")
		_rebinding = &""
		_refresh_keys()


func _handle_joy_rebind(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo:
		if key_event.keycode == KEY_ESCAPE or key_event.physical_keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_cancel_rebind()
			return
	var joy_event := event as InputEventJoypadButton
	if joy_event == null or not joy_event.pressed:
		return
	get_viewport().set_input_as_handled()
	if joy_event.button_index == JOY_BUTTON_BACK:
		_cancel_rebind()
		return
	var meta := GameBootstrap.meta if GameBootstrap != null else null
	if meta == null:
		_cancel_rebind()
		return
	if KeyBindings.set_joy_button(meta, _joy_rebinding, joy_event.button_index):
		GameBootstrap.save_meta()
		_joy_rebinding = &""
		_hint.text = ""
		_refresh_keys()
	else:
		_hint.text = _tr("settings.joy_conflict")
		_joy_rebinding = &""
		_refresh_keys()


func _build_ui() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_key_buttons.clear()
	_joy_buttons.clear()

	var bg := ColorRect.new()
	bg.color = Color("#0b0e13")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var title := Label.new()
	title.text = _tr("settings.title")
	title.position = Vector2(0, 42)
	title.size = Vector2(1280, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", FONT)
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color("#e9eef5"))
	add_child(title)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 给标题留出 90px：标题仍是绝对定位（y=42..102），内容从 90 起排，
	# 避免 CenterContainer 把 592px 高的内容顶上来压住标题（审计 P2-3）。
	center.offset_top = 90.0
	add_child(center)

	var outer := VBoxContainer.new()
	outer.custom_minimum_size = Vector2(920, 520)
	outer.add_theme_constant_override("separation", 18)
	center.add_child(outer)

	var columns := HBoxContainer.new()
	columns.custom_minimum_size = Vector2(920, 430)
	columns.add_theme_constant_override("separation", 36)
	outer.add_child(columns)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(430, 430)
	left.add_theme_constant_override("separation", 10)
	columns.add_child(left)

	# 右列条目多（8 个动作 × 3 列 + 重置 + 提示），固定 430px 会溢出，
	# 用 ScrollContainer 兜住，手柄/键盘焦点仍按容器顺序滚动到可见区。
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(466, 430)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	columns.add_child(scroll)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(450, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	scroll.add_child(right)

	# 第一个参数是显示文案的 I18N 键，第二个是写入 MetaSave.settings 的键。
	# 之前两者共用同一个值，导致滑条写入 "settings.master" 这类脏键，
	# 而 apply_settings() 读的是 "volume_master" → 音量完全不生效（审计 P0-1）。
	_master = _add_slider_row(left, "settings.master", "volume_master", 0.8)
	_sfx = _add_slider_row(left, "settings.sfx", "volume_sfx", 0.8)
	_ambient = _add_slider_row(left, "settings.ambient", "volume_ambient", 0.7)

	_mute = _add_check_row(left, "settings.mute", _on_mute_toggled)
	_fullscreen = _add_check_row(left, "settings.fullscreen", _on_fullscreen_toggled)

	var lang_row := HBoxContainer.new()
	lang_row.custom_minimum_size = Vector2(430, 44)
	lang_row.add_theme_constant_override("separation", 12)
	left.add_child(lang_row)

	var lang_label := Label.new()
	lang_label.text = _tr("settings.language")
	lang_label.custom_minimum_size = Vector2(130, 40)
	lang_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lang_label.add_theme_font_override("font", FONT)
	lang_label.add_theme_font_size_override("font_size", 18)
	lang_label.add_theme_color_override("font_color", Color("#c7d2df"))
	lang_row.add_child(lang_label)

	_language = OptionButton.new()
	_language.custom_minimum_size = Vector2(260, 40)
	_language.add_theme_font_override("font", FONT)
	_language.add_theme_font_size_override("font_size", 18)
	for i in LANGUAGES.size():
		_language.add_item(LANGUAGE_LABELS[i])
		_language.set_item_metadata(i, LANGUAGES[i])
	_language.item_selected.connect(_on_language_selected)
	UiFocus.prepare(_language)
	lang_row.add_child(_language)

	var keys_title := Label.new()
	keys_title.text = _tr("settings.keys")
	keys_title.custom_minimum_size = Vector2(450, 30)
	keys_title.add_theme_font_override("font", FONT)
	keys_title.add_theme_font_size_override("font_size", 22)
	keys_title.add_theme_color_override("font_color", Color("#e9eef5"))
	right.add_child(keys_title)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(450, 22)
	header.add_theme_constant_override("separation", 10)
	right.add_child(header)
	for column_key in ["settings.action_col", "settings.key_col", "settings.joy_col"]:
		var column := Label.new()
		column.text = _tr(column_key)
		column.custom_minimum_size = Vector2(210 if column_key == "settings.action_col" else 110, 20)
		column.add_theme_font_override("font", FONT)
		column.add_theme_font_size_override("font_size", 13)
		column.add_theme_color_override("font_color", Color("#8d9aab"))
		header.add_child(column)

	for id in KeyBindings.ACTION_ORDER:
		_add_key_row(right, id)

	var reset := Button.new()
	reset.text = _tr("settings.reset_keys")
	reset.custom_minimum_size = Vector2(450, 38)
	reset.add_theme_font_override("font", FONT)
	reset.add_theme_font_size_override("font_size", 16)
	reset.pressed.connect(_on_reset_keys)
	UiFocus.prepare(reset)
	right.add_child(reset)

	_hint = Label.new()
	_hint.custom_minimum_size = Vector2(450, 22)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_override("font", FONT)
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color("#d98a8a"))
	right.add_child(_hint)

	_pads = Label.new()
	_pads.custom_minimum_size = Vector2(450, 22)
	_pads.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pads.add_theme_font_override("font", FONT)
	_pads.add_theme_font_size_override("font_size", 14)
	_pads.add_theme_color_override("font_color", Color("#9aa7b8"))
	_pads.tooltip_text = _tr("settings.gamepad_hint")
	right.add_child(_pads)

	# 人工清档入口（用户 2026-10-21 决策）：先上膛再确认，避免误触。
	_wipe_button = Button.new()
	_wipe_button.text = _tr("settings.wipe_save")
	_wipe_button.custom_minimum_size = Vector2(240, 44)
	_wipe_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_wipe_button.add_theme_font_override("font", FONT)
	_wipe_button.add_theme_font_size_override("font_size", 18)
	_wipe_button.pressed.connect(_on_wipe_pressed)
	UiFocus.prepare(_wipe_button)
	outer.add_child(_wipe_button)

	var back := Button.new()
	back.text = _tr("settings.back")
	back.custom_minimum_size = Vector2(240, 48)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.add_theme_font_override("font", FONT)
	back.add_theme_font_size_override("font_size", 20)
	back.pressed.connect(_on_back_pressed)
	UiFocus.prepare(back)
	outer.add_child(back)


func _add_slider_row(parent: VBoxContainer, label_key: String, setting_key: String, default_value: float) -> HSlider:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(430, 48)
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	var label := Label.new()
	label.text = _tr(label_key)
	label.custom_minimum_size = Vector2(130, 44)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color("#c7d2df"))
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = default_value * 100.0
	slider.custom_minimum_size = Vector2(280, 36)
	slider.value_changed.connect(_on_volume_changed.bind(setting_key))
	UiFocus.prepare(slider)
	row.add_child(slider)
	return slider


func _add_check_row(parent: VBoxContainer, key: String, handler: Callable) -> CheckButton:
	var check := CheckButton.new()
	check.text = _tr(key)
	check.custom_minimum_size = Vector2(430, 42)
	check.add_theme_font_override("font", FONT)
	check.add_theme_font_size_override("font_size", 18)
	check.toggled.connect(handler)
	UiFocus.prepare(check)
	parent.add_child(check)
	return check


func _add_key_row(parent: VBoxContainer, id: StringName) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(450, 40)
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)

	var label := Label.new()
	label.text = _tr(KeyBindings.label_key(id))
	label.custom_minimum_size = Vector2(210, 38)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color("#c7d2df"))
	row.add_child(label)

	var button := Button.new()
	button.custom_minimum_size = Vector2(110, 38)
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(_begin_rebind.bind(id))
	UiFocus.prepare(button)
	row.add_child(button)
	_key_buttons[id] = button

	var joy_button := Button.new()
	joy_button.custom_minimum_size = Vector2(110, 38)
	joy_button.add_theme_font_override("font", FONT)
	joy_button.add_theme_font_size_override("font_size", 15)
	joy_button.pressed.connect(_begin_joy_rebind.bind(id))
	UiFocus.prepare(joy_button)
	row.add_child(joy_button)
	_joy_buttons[id] = joy_button


func _refresh_keys() -> void:
	var meta := GameBootstrap.meta if GameBootstrap != null else null
	for id in _key_buttons.keys():
		var button: Button = _key_buttons[id]
		button.text = KeyBindings.label(meta, id)
	for id in _joy_buttons.keys():
		var joy_button: Button = _joy_buttons[id]
		joy_button.text = KeyBindings.label_joy(meta, id)
	if _rebinding != &"" and _key_buttons.has(_rebinding):
		(_key_buttons[_rebinding] as Button).text = _tr("settings.press_key")
	if _joy_rebinding != &"" and _joy_buttons.has(_joy_rebinding):
		(_joy_buttons[_joy_rebinding] as Button).text = _tr("settings.press_joy")
	_pads.text = "%s: %d · %s" % [
		_tr("settings.gamepads"),
		InputDevices.count(),
		_tr(InputDevices.p2_source_key()),
	]


func _begin_rebind(id: StringName) -> void:
	SoundManager.play_ui_sound(CLICK)
	_joy_rebinding = &""
	_refresh_keys()
	_rebinding = id
	_hint.text = ""
	var button: Button = _key_buttons.get(id)
	if button != null:
		button.text = _tr("settings.press_key")


func _begin_joy_rebind(id: StringName) -> void:
	SoundManager.play_ui_sound(CLICK)
	_rebinding = &""
	_refresh_keys()
	_joy_rebinding = id
	if InputDevices.count() == 0:
		_hint.text = _tr("settings.no_gamepad")
	else:
		_hint.text = _tr("settings.press_joy") + " " + _tr("settings.cancel_hint")
	var button: Button = _joy_buttons.get(id)
	if button != null:
		button.text = _tr("settings.press_joy")


func _cancel_rebind() -> void:
	_rebinding = &""
	_joy_rebinding = &""
	_hint.text = ""
	_refresh_keys()


func _load_values() -> void:
	var meta := GameBootstrap.meta if GameBootstrap != null else null
	if meta == null:
		return
	# 用 set_*_no_signal：直接赋值会触发 value_changed / toggled，
	# 每次打开设置页就白跑 5 次 apply_settings() + 5 次写盘（审计 P2-2）。
	_master.set_value_no_signal(float(meta.settings.get("volume_master", 0.8)) * 100.0)
	_sfx.set_value_no_signal(float(meta.settings.get("volume_sfx", 0.8)) * 100.0)
	_ambient.set_value_no_signal(float(meta.settings.get("volume_ambient", 0.7)) * 100.0)
	_mute.set_pressed_no_signal(bool(meta.settings.get("mute", false)))
	_fullscreen.set_pressed_no_signal(bool(meta.settings.get("fullscreen", false)))
	var lang := String(meta.settings.get("language", "zh_CN"))
	var index := LANGUAGES.find(lang)
	_language.select(maxi(index, 0))


func _on_volume_changed(value: float, setting_key: String) -> void:
	var meta := GameBootstrap.meta if GameBootstrap != null else null
	if meta == null:
		return
	meta.settings[setting_key] = clampf(value / 100.0, 0.0, 1.0)
	GameBootstrap.apply_settings()
	_schedule_save()


## 拖动时只应用、不落盘；停手 350ms 后写一次（审计 P2-14）。
func _schedule_save() -> void:
	if _save_timer == null:
		GameBootstrap.save_meta()
		return
	_save_timer.start()


func _flush_save() -> void:
	if _save_timer != null:
		_save_timer.stop()
	if GameBootstrap != null:
		GameBootstrap.save_meta()


## 清除存档（二次确认）：第一次上膛，3 秒内再按一次才真的删。
func _on_wipe_pressed() -> void:
	SoundManager.play_ui_sound(CLICK)
	if not _wipe_armed:
		_wipe_armed = true
		if _wipe_button != null:
			_wipe_button.text = _tr("settings.wipe_confirm")
		if _wipe_timer != null:
			_wipe_timer.start()
		return
	_disarm_wipe()
	if GameBootstrap != null:
		GameBootstrap.wipe_save()
	_load_values()
	_refresh_keys()
	_hint.text = _tr("settings.wipe_done")


func _disarm_wipe() -> void:
	_wipe_armed = false
	if _wipe_timer != null:
		_wipe_timer.stop()
	if _wipe_button != null:
		_wipe_button.text = _tr("settings.wipe_save")


func _on_mute_toggled(pressed: bool) -> void:
	var meta := GameBootstrap.meta if GameBootstrap != null else null
	if meta == null:
		return
	meta.settings["mute"] = pressed
	GameBootstrap.apply_settings()
	_schedule_save()


func _on_fullscreen_toggled(pressed: bool) -> void:
	var meta := GameBootstrap.meta if GameBootstrap != null else null
	if meta == null:
		return
	meta.settings["fullscreen"] = pressed
	GameBootstrap.apply_settings()
	_schedule_save()


func _on_language_selected(index: int) -> void:
	SoundManager.play_ui_sound(CLICK)
	var code := String(_language.get_item_metadata(index))
	# set_language 会通过 EventBus 发 LanguageChangedEvent，_on_language_changed 负责重建本页文案。
	GameBootstrap.set_language(code)


func _on_reset_keys() -> void:
	SoundManager.play_ui_sound(CLICK)
	var meta := GameBootstrap.meta if GameBootstrap != null else null
	if meta == null:
		return
	KeyBindings.reset(meta)
	GameBootstrap.save_meta()
	_hint.text = ""
	_refresh_keys()


func _on_back_pressed() -> void:
	SoundManager.play_ui_sound(CLICK)
	UIManager.back(UILayer.NORMAL)


func _tr(key: String) -> String:
	var text := I18NManager.get_text(key)
	if text == key:
		return "[占位] " + key
	return text
