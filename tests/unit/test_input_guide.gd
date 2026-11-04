extends GutTest

## 双人选人后的槽位重排：手柄方只留手柄槽，键鼠方按“键→鼠标”占用既有槽位；
## 不新增 index，因为 GUIDE 只遍历资源原有的 action_mappings。

var _meta: MetaSave


func before_each() -> void:
	_meta = MetaSave.new()


func _config(versus: bool, p1_gamepad: bool, p2_gamepad: bool) -> GUIDERemappingConfig:
	var context := InputGuide.context_for(&"versus" if versus else &"run")
	assert_not_null(context)
	return InputGuide.build_remap_config(context, _meta, versus, p1_gamepad, p2_gamepad)


func _slots(config: GUIDERemappingConfig, action_name: StringName) -> Dictionary:
	var context: GUIDEMappingContext = config.remapped_inputs.keys()[0]
	var action := InputGuide.action(context, action_name)
	assert_not_null(action)
	return config.remapped_inputs[context][action]


func test_p1_keyboard_p2_gamepad_unbinds_p1_gamepad_slot() -> void:
	var config := _config(true, false, true)
	var p1: Dictionary = _slots(config, &"duel_attack_p1")
	assert_true(p1[0] is GUIDEInputKey)
	assert_eq((p1[0] as GUIDEInputKey).key, KEY_J)
	assert_true(p1[1] is GUIDEInputMouseButton)
	assert_eq((p1[1] as GUIDEInputMouseButton).button, MOUSE_BUTTON_LEFT)
	assert_null(p1[2])

	var p2: Dictionary = _slots(config, &"duel_attack_p2")
	assert_true(p2[0] is GUIDEInputJoyButton)
	assert_eq((p2[0] as GUIDEInputJoyButton).joy_index, 0)
	assert_eq((p2[0] as GUIDEInputJoyButton).button, KeyBindings.get_joy_button(_meta, &"attack_p2"))
	assert_null(p2[1])
	assert_null(p2[2])


func test_p1_gamepad_p2_keyboard_puts_mouse_on_p2_joy_slot() -> void:
	var config := _config(true, true, false)
	var p1: Dictionary = _slots(config, &"duel_attack_p1")
	assert_true(p1[0] is GUIDEInputJoyButton)
	assert_eq((p1[0] as GUIDEInputJoyButton).joy_index, 0)
	assert_null(p1[1])
	assert_null(p1[2])

	var p2: Dictionary = _slots(config, &"duel_attack_p2")
	assert_true(p2[0] is GUIDEInputKey)
	assert_eq((p2[0] as GUIDEInputKey).key, KEY_KP_1)
	assert_true(p2[1] is GUIDEInputKey)
	assert_eq((p2[1] as GUIDEInputKey).key, KEY_I)
	assert_true(p2[2] is GUIDEInputMouseButton)
	assert_eq((p2[2] as GUIDEInputMouseButton).button, MOUSE_BUTTON_LEFT)


func test_both_keyboard_keeps_mouse_on_p1_only() -> void:
	var config := _config(true, false, false)
	var p1: Dictionary = _slots(config, &"duel_guard_p1")
	assert_true(p1[0] is GUIDEInputKey)
	assert_true(p1[1] is GUIDEInputMouseButton)
	assert_eq((p1[1] as GUIDEInputMouseButton).button, MOUSE_BUTTON_RIGHT)
	assert_null(p1[2])

	var p2: Dictionary = _slots(config, &"duel_guard_p2")
	assert_true(p2[0] is GUIDEInputKey)
	assert_eq((p2[0] as GUIDEInputKey).key, KEY_KP_2)
	assert_true(p2[1] is GUIDEInputKey)
	assert_eq((p2[1] as GUIDEInputKey).key, KEY_O)
	assert_null(p2[2])


func test_both_gamepads_use_joy_index_zero_and_one() -> void:
	var config := _config(true, true, true)
	var p1: Dictionary = _slots(config, &"duel_attack_p1")
	assert_true(p1[0] is GUIDEInputJoyButton)
	assert_eq((p1[0] as GUIDEInputJoyButton).joy_index, 0)
	assert_eq((p1[0] as GUIDEInputJoyButton).button, KeyBindings.get_joy_button(_meta, &"attack_p1"))
	assert_null(p1[1])
	assert_null(p1[2])

	var p2: Dictionary = _slots(config, &"duel_attack_p2")
	assert_true(p2[0] is GUIDEInputJoyButton)
	assert_eq((p2[0] as GUIDEInputJoyButton).joy_index, 1)
	assert_eq((p2[0] as GUIDEInputJoyButton).button, KeyBindings.get_joy_button(_meta, &"attack_p2"))
	assert_null(p2[1])
	assert_null(p2[2])


func test_solo_keeps_keyboard_mouse_and_gamepad_together() -> void:
	var config := _config(false, false, false)
	var p1: Dictionary = _slots(config, &"duel_spell_p1")
	assert_true(p1[0] is GUIDEInputKey)
	assert_eq((p1[0] as GUIDEInputKey).key, KEY_L)
	# 单人不对鼠标槽做重映射，沿用上下文里的鼠标中键；因此配置里没有 index 1。
	assert_false(p1.has(1), "鼠标槽保持上下文默认，不写重映射")
	assert_true(p1[2] is GUIDEInputJoyButton)
	assert_eq((p1[2] as GUIDEInputJoyButton).joy_index, 0)
	var context: GUIDEMappingContext = config.remapped_inputs.keys()[0]
	var action := InputGuide.action(context, &"duel_spell_p1")
	var mapping: GUIDEActionMapping = null
	for candidate in context.mappings:
		if candidate.action == action:
			mapping = candidate
			break
	assert_not_null(mapping)
	var mouse: GUIDEInput = mapping.input_mappings[1].input
	assert_true(mouse is GUIDEInputMouseButton)
	assert_eq((mouse as GUIDEInputMouseButton).button, MOUSE_BUTTON_MIDDLE)


func test_global_actions_keep_keyboard_and_both_gamepads() -> void:
	var config := _config(true, true, false)
	var pause: Dictionary = _slots(config, &"duel_pause")
	assert_true(pause[0] is GUIDEInputKey)
	assert_eq((pause[0] as GUIDEInputKey).key, KEY_ESCAPE)
	assert_true(pause[1] is GUIDEInputJoyButton)
	assert_eq((pause[1] as GUIDEInputJoyButton).joy_index, 0)
	assert_true(pause[2] is GUIDEInputJoyButton)
	assert_eq((pause[2] as GUIDEInputJoyButton).joy_index, 1)
