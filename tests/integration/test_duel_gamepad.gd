extends GutTest

## 验证手柄按钮映射能通过 GUIDE 注入触发；不需要真实手柄。
## InputDevices 的设备分配逻辑由 test_input_devices.gd 覆盖。


const DUEL_SCENE := preload("res://scenes/duel/duel.tscn")


func test_joy_button_mapping_triggers_action() -> void:
	var duel := DUEL_SCENE.instantiate()
	add_child_autofree(duel)
	await wait_process_frames(2)

	var no_keys: Array[Key] = []
	var no_mouse: Array[MouseButton] = []
	var virtual_id: int = GUIDE._input_state.connect_virtual_stick(0)
	var joy_indices: Array[int] = [virtual_id]
	var joy_buttons: Array[JoyButton] = [JOY_BUTTON_A]
	var action: GUIDEAction = duel._add_action(&"test_joy_button", no_keys, no_mouse, joy_indices, joy_buttons)
	GUIDE.disable_mapping_context(duel._context)
	GUIDE.enable_mapping_context(duel._context, true)

	var triggered := [0]
	action.just_triggered.connect(func() -> void: triggered[0] += 1)

	var down := InputEventJoypadButton.new()
	down.device = virtual_id
	down.button_index = JOY_BUTTON_A
	down.pressed = true
	GUIDE.inject_input(down)
	await wait_process_frames(3)
	assert_eq(triggered[0], 1, "手柄 A 按下应触发一次 just_triggered")

	var up := InputEventJoypadButton.new()
	up.device = virtual_id
	up.button_index = JOY_BUTTON_A
	up.pressed = false
	GUIDE.inject_input(up)
	await wait_process_frames(2)
	GUIDE._input_state.disconnect_virtual_stick(virtual_id)


func test_hotplug_rebuilds_input_context() -> void:
	var duel := DUEL_SCENE.instantiate()
	add_child_autofree(duel)
	await wait_process_frames(2)

	var old_context: GUIDEMappingContext = duel._context
	duel._on_joy_connection_changed(0, true)
	await wait_process_frames(2)

	assert_not_null(duel._context)
	assert_ne(duel._context, old_context)
	assert_true(duel._context.mappings.size() > 0)
