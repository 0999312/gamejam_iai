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


func test_duel_context_always_contains_p1_joy_mapping() -> void:
	# 即使启动帧没有枚举到手柄，也要保留 P1 的“第一个手柄”映射；
	# 否则已连接手柄在启动时会被永久忽略。
	var duel := DUEL_SCENE.instantiate()
	add_child_autofree(duel)
	await wait_process_frames(2)
	var joy_mapping_count := 0
	for mapping in duel._context.mappings:
		for input_mapping in mapping.input_mappings:
			if input_mapping.input is GUIDEInputJoyButton:
				joy_mapping_count += 1
	assert_gt(joy_mapping_count, 0, "P1 至少应有一条手柄映射")


func test_raw_joy_fallback_sets_p1_queue() -> void:
	# GUIDE 枚举失败时的兜底：直接按 event.device 分发。
	var duel := DUEL_SCENE.instantiate()
	add_child_autofree(duel)
	await wait_process_frames(2)

	var attack := InputEventJoypadButton.new()
	attack.device = 3
	attack.button_index = JOY_BUTTON_A
	attack.pressed = true
	duel._input(attack)
	assert_true(duel._attack_queued, "原始手柄 A 应置位 P1 攻击队列")

	var guard := InputEventJoypadButton.new()
	guard.device = 3
	guard.button_index = JOY_BUTTON_B
	guard.pressed = true
	duel._input(guard)
	assert_true(duel._guard_queued, "原始手柄 B 应置位 P1 防御队列")


func test_raw_joy_fallback_keeps_players_separate() -> void:
	var duel := DUEL_SCENE.instantiate()
	add_child_autofree(duel)
	await wait_process_frames(2)
	duel.mode = &"versus"
	duel._raw_p1_device = 0
	duel._raw_p2_device = 1

	var p2_attack := InputEventJoypadButton.new()
	p2_attack.device = 1
	p2_attack.button_index = JOY_BUTTON_A
	p2_attack.pressed = true
	duel._input(p2_attack)
	assert_true(duel._p2_attack_queued, "P2 手柄 A 应置位 P2 攻击队列")
	assert_false(duel._attack_queued, "P2 手柄不应同时触发 P1")


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
