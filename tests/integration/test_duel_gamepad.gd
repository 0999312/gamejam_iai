extends GutTest

## 验证手柄按钮映射能通过 GUIDE 注入触发；不需要真实手柄。
## InputDevices 的设备分配逻辑由 test_input_devices.gd 覆盖。


const DUEL_SCENE := preload("res://scenes/duel/duel.tscn")


func test_joy_button_mapping_triggers_action() -> void:
	var duel := DUEL_SCENE.instantiate()
	add_child_autofree(duel)
	await wait_process_frames(2)

	# 测试自己造一个只挂虚拟手柄的动作：生产环境的动作都来自 res://input/contexts，
	# 但虚拟手柄的 device 与真实手柄的 joy_index 解析方式不同，需要专用动作。
	var virtual_id: int = GUIDE._input_state.connect_virtual_stick(0)
	var action := GUIDEAction.new()
	action.name = &"test_joy_button"
	action.action_value_type = GUIDEAction.GUIDEActionValueType.BOOL
	var mapping := GUIDEActionMapping.new()
	mapping.action = action
	var input_mapping := GUIDEInputMapping.new()
	var joy_input := GUIDEInputJoyButton.new()
	joy_input.joy_index = virtual_id
	joy_input.button = JOY_BUTTON_A
	input_mapping.input = joy_input
	mapping.input_mappings.append(input_mapping)
	duel._context.mappings.append(mapping)
	GUIDE.disable_mapping_context(duel._context)
	GUIDE.enable_mapping_context(duel._context, true)
	assert_not_null(action, "上下文里应当有 P1 攻击动作")

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
	# 双人输入方式由选人面板决定：本用例只要 P2 用手柄、P1 用键鼠。
	duel._p1_uses_gamepad = false
	duel._p2_uses_gamepad = true

	var p2_attack := InputEventJoypadButton.new()
	p2_attack.device = 1
	p2_attack.button_index = JOY_BUTTON_A
	p2_attack.pressed = true
	duel._input(p2_attack)
	assert_true(duel._p2_attack_queued, "P2 手柄 A 应置位 P2 攻击队列")
	assert_false(duel._attack_queued, "P2 手柄不应同时触发 P1")


func test_raw_joy_fallback_splits_two_gamepads() -> void:
	var duel := DUEL_SCENE.instantiate()
	add_child_autofree(duel)
	await wait_process_frames(2)
	duel.mode = &"versus"
	duel._p1_uses_gamepad = true
	duel._p2_uses_gamepad = true
	duel._raw_p1_device = 0
	duel._raw_p2_device = 1

	var p1_attack := InputEventJoypadButton.new()
	p1_attack.device = 0
	p1_attack.button_index = JOY_BUTTON_A
	p1_attack.pressed = true
	duel._input(p1_attack)
	assert_true(duel._attack_queued, "设备 0 应归 P1")
	assert_false(duel._p2_attack_queued, "设备 0 不应触发 P2")

	var p2_attack := InputEventJoypadButton.new()
	p2_attack.device = 1
	p2_attack.button_index = JOY_BUTTON_A
	p2_attack.pressed = true
	duel._input(p2_attack)
	assert_true(duel._p2_attack_queued, "设备 1 应归 P2")
	assert_eq(duel._attack_queued, true, "P2 攻击不应清掉 P1 已置位的队列")


func test_guard_release_only_clears_matching_gamepad() -> void:
	var duel := DUEL_SCENE.instantiate()
	add_child_autofree(duel)
	await wait_process_frames(2)
	duel.mode = &"versus"
	duel._p1_uses_gamepad = true
	duel._p2_uses_gamepad = true
	duel._raw_p1_device = 0
	duel._raw_p2_device = 1

	for device in [0, 1]:
		var guard := InputEventJoypadButton.new()
		guard.device = device
		guard.button_index = JOY_BUTTON_B
		guard.pressed = true
		duel._input(guard)
	assert_true(duel._guard_held)
	assert_true(duel._p2_guard_held)

	var p1_release := InputEventJoypadButton.new()
	p1_release.device = 0
	p1_release.button_index = JOY_BUTTON_B
	p1_release.pressed = false
	duel._input(p1_release)
	assert_false(duel._guard_held, "只松开 P1 的手柄")
	assert_true(duel._p2_guard_held, "P2 仍按着架")

	var p2_release := InputEventJoypadButton.new()
	p2_release.device = 1
	p2_release.button_index = JOY_BUTTON_B
	p2_release.pressed = false
	duel._input(p2_release)
	assert_false(duel._p2_guard_held)


func test_hotplug_rebuilds_input_context() -> void:
	var duel := DUEL_SCENE.instantiate()
	add_child_autofree(duel)
	await wait_process_frames(2)

	var old_context: GUIDEMappingContext = duel._context
	duel._guard_held = true
	duel._p2_guard_held = true
	duel._on_joy_connection_changed(0, true)
	await wait_process_frames(2)

	assert_false(duel._guard_held, "重建输入后不应继承旧手柄的按住架")
	assert_false(duel._p2_guard_held, "重建输入后 P2 的按住架也应复位")
	assert_not_null(duel._context)
	assert_ne(duel._context, old_context)
	assert_true(duel._context.mappings.size() > 0)
