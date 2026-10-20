extends GutTest

## 设置页：改键会写回 MetaSave，取消不会写。


const SETTINGS_SCENE := preload("res://scenes/ui/settings.tscn")


func test_rebind_writes_key() -> void:
	var old_meta := GameBootstrap.meta
	GameBootstrap.meta = MetaSave.new()
	var settings := SETTINGS_SCENE.instantiate() as Control
	add_child_autofree(settings)
	await wait_process_frames(1)

	settings._begin_rebind(&"attack_p1")
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_L
	settings.get_viewport().push_input(event)
	await wait_process_frames(1)

	assert_true(KeyBindings.get_keys(GameBootstrap.meta, &"attack_p1").has(KEY_L))
	GameBootstrap.meta = old_meta


func test_escape_cancels_rebind() -> void:
	var old_meta := GameBootstrap.meta
	GameBootstrap.meta = MetaSave.new()
	var settings := SETTINGS_SCENE.instantiate() as Control
	add_child_autofree(settings)
	await wait_process_frames(1)

	settings._begin_rebind(&"attack_p1")
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ESCAPE
	settings.get_viewport().push_input(event)
	await wait_process_frames(1)

	assert_true(KeyBindings.get_keys(GameBootstrap.meta, &"attack_p1").has(KEY_J))
	GameBootstrap.meta = old_meta


func test_rebind_writes_gamepad_button() -> void:
	var old_meta := GameBootstrap.meta
	GameBootstrap.meta = MetaSave.new()
	var settings := SETTINGS_SCENE.instantiate() as Control
	add_child_autofree(settings)
	await wait_process_frames(1)

	settings._begin_joy_rebind(&"guard_p1")
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_X
	event.pressed = true
	settings.get_viewport().push_input(event)
	await wait_process_frames(1)

	assert_eq(KeyBindings.get_joy_button(GameBootstrap.meta, &"guard_p1"), JOY_BUTTON_X)
	GameBootstrap.meta = old_meta


func test_gamepad_rebind_escape_cancels() -> void:
	var old_meta := GameBootstrap.meta
	GameBootstrap.meta = MetaSave.new()
	var settings := SETTINGS_SCENE.instantiate() as Control
	add_child_autofree(settings)
	await wait_process_frames(1)

	settings._begin_joy_rebind(&"guard_p1")
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ESCAPE
	settings.get_viewport().push_input(event)
	await wait_process_frames(1)

	assert_eq(KeyBindings.get_joy_button(GameBootstrap.meta, &"guard_p1"), JOY_BUTTON_B)
	GameBootstrap.meta = old_meta


func test_settings_labels_follow_locale() -> void:
	I18NManager.set_language("en")
	var old_meta := GameBootstrap.meta
	GameBootstrap.meta = MetaSave.new()
	var settings := SETTINGS_SCENE.instantiate() as Control
	add_child_autofree(settings)
	await wait_process_frames(1)

	var texts: Array[String] = []
	for label in settings.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	assert_true(texts.has("Settings"))
	assert_true(texts.has("Keys & Gamepad"))
	GameBootstrap.meta = old_meta
	I18NManager.set_language("zh_CN")
