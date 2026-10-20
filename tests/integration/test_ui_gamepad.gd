extends GutTest

## 全手柄 UI：内置 UI 动作补手柄键；各界面初始焦点与方向键导航。

const MENU_SCENE := preload("res://scenes/menu/menu.tscn")
const SHOP_SCENE := preload("res://scenes/ui/shop.tscn")
const SETTINGS_SCENE := preload("res://scenes/ui/settings.tscn")
const PAUSE_SCENE := preload("res://scenes/ui/pause_menu.tscn")

var _old_meta: MetaSave


func before_each() -> void:
	_old_meta = GameBootstrap.meta
	GameBootstrap.meta = MetaSave.new()


func after_each() -> void:
	GameBootstrap.meta = _old_meta


func test_ui_accept_and_cancel_have_gamepad_events() -> void:
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	var cancel := InputEventJoypadButton.new()
	cancel.button_index = JOY_BUTTON_B
	assert_true(InputMap.action_has_event(&"ui_accept", accept))
	assert_true(InputMap.action_has_event(&"ui_cancel", cancel))


func test_menu_focus_moves_with_dpad() -> void:
	var menu := MENU_SCENE.instantiate() as Control
	add_child_autofree(menu)
	await wait_process_frames(2)
	var first := get_viewport().gui_get_focus_owner()
	assert_not_null(first)

	var down := InputEventJoypadButton.new()
	down.button_index = JOY_BUTTON_DPAD_DOWN
	down.pressed = true
	Input.parse_input_event(down)
	await wait_process_frames(2)
	var second := get_viewport().gui_get_focus_owner()
	assert_not_null(second)
	assert_ne(first, second)
	assert_true(second is Button)


func test_shop_focuses_first_available_action() -> void:
	var shop := SHOP_SCENE.instantiate() as Control
	add_child_autofree(shop)
	await wait_process_frames(2)
	var focus := get_viewport().gui_get_focus_owner()
	assert_not_null(focus)
	assert_true(focus is Button)


func test_settings_focuses_first_slider() -> void:
	var settings := SETTINGS_SCENE.instantiate() as Control
	add_child_autofree(settings)
	await wait_process_frames(2)
	var focus := get_viewport().gui_get_focus_owner()
	assert_not_null(focus)
	assert_true(focus is HSlider)


func test_pause_focuses_resume() -> void:
	var pause := PAUSE_SCENE.instantiate() as PauseMenu
	add_child_autofree(pause)
	await wait_process_frames(1)
	pause.show_pause()
	await wait_process_frames(1)
	assert_eq(get_viewport().gui_get_focus_owner(), pause._resume_button)


func test_joy_a_presses_focused_button() -> void:
	var button := Button.new()
	button.text = "OK"
	button.size = Vector2(220, 64)
	add_child_autofree(button)
	button.grab_focus()
	await wait_process_frames(1)
	var pressed := [false]
	button.pressed.connect(func() -> void: pressed[0] = true)

	var down := InputEventJoypadButton.new()
	down.button_index = JOY_BUTTON_A
	down.pressed = true
	Input.parse_input_event(down)
	await wait_process_frames(1)
	var up := InputEventJoypadButton.new()
	up.button_index = JOY_BUTTON_A
	up.pressed = false
	Input.parse_input_event(up)
	await wait_process_frames(2)
	assert_true(pressed[0])
