class_name InputGuide
extends RefCounted

## GUIDE 上下文与改键的接线层：上下文来自 res://input/contexts 下的资源，
## 运行期只做「读资源 + 套一层改键配置」，不再用代码拼 GUIDEAction。

const RUN_CONTEXT_PATH := "res://input/contexts/duel_run.tres"
const VERSUS_CONTEXT_PATH := "res://input/contexts/duel_versus.tres"

## 动作名 → KeyBindings 里的绑定 id。没有对应 id 的动作（选心得 1–3）不可改键。
const ACTION_BINDINGS: Dictionary = {
	&"duel_attack_p1": &"attack_p1",
	&"duel_guard_p1": &"guard_p1",
	&"duel_spell_p1": &"spell_p1",
	&"duel_attack_p2": &"attack_p2",
	&"duel_guard_p2": &"guard_p2",
	&"duel_spell_p2": &"spell_p2",
	&"duel_restart": &"restart",
	&"duel_pause": &"pause",
}


static func context_path(mode: StringName) -> String:
	return VERSUS_CONTEXT_PATH if mode == &"versus" else RUN_CONTEXT_PATH


## 每个对局拿一份**独占副本**：同一份 .tres 被 load 缓存成单例，GUIDE 的
## 启用/禁用是按「上下文实例 + 动作实例」记状态的。两个对局（热插拔并存、
## 测试里两个场景）共用同一批 GUIDEAction 时，禁用旧上下文会把新上下文
## 也在用的动作一起停掉，表现为「改键后没反应」。所以这里把动作与输入
## 都复制一份，资源仍只负责定义结构。
static func context_for(mode: StringName) -> GUIDEMappingContext:
	var source := load(context_path(mode)) as GUIDEMappingContext
	if source == null:
		return null
	var context := GUIDEMappingContext.new()
	context.display_name = source.display_name
	var actions: Dictionary = {}
	for mapping in source.mappings:
		if mapping == null or mapping.action == null:
			continue
		var action_name: StringName = mapping.action.name
		var action: GUIDEAction = actions.get(action_name)
		if action == null:
			action = mapping.action.duplicate() as GUIDEAction
			actions[action_name] = action
		var copy := mapping.duplicate(true) as GUIDEActionMapping
		copy.action = action
		context.mappings.append(copy)
	return context


static func action(context: GUIDEMappingContext, action_name: StringName) -> GUIDEAction:
	if context == null:
		return null
	for mapping in context.mappings:
		if mapping != null and mapping.action != null and mapping.action.name == action_name:
			return mapping.action
	return null


## 把 KeyBindings 的当前绑定套到上下文上。
##
## 单人对局：键盘槽按顺序替换，多出来的槽显式解绑；手柄槽只换按键、
## 保留 joy_index；鼠标槽保持资源默认（键鼠与手柄同时可用）。
##
## 双人对局：按选人面板选定的输入方式重排六个玩家动作槽——手柄方 index 0
## 绑手柄（独占一方手柄时 joy_index=0，双方手柄时 P1=0 / P2=1），其余槽解绑；
## 键鼠方按键序绑键，鼠标只给键鼠玩家一次（P1 键鼠恒可用；P1 手柄时 P2 键鼠
## 借用 P2 原有的手柄槽 index 2 挂鼠标）。全局暂停/重开保持键盘 + 手柄。
static func build_remap_config(
	context: GUIDEMappingContext,
	meta: MetaSave,
	versus: bool = false,
	p1_gamepad: bool = false,
	p2_gamepad: bool = false
) -> GUIDERemappingConfig:
	if context == null:
		return null
	var config := GUIDERemappingConfig.new()
	for mapping in context.mappings:
		if mapping == null or mapping.action == null:
			continue
		var binding_id: StringName = ACTION_BINDINGS.get(mapping.action.name, &"")
		if binding_id == &"":
			continue
		if versus and _is_player_binding(binding_id):
			_remap_versus_action(config, context, mapping, meta, binding_id, p1_gamepad, p2_gamepad)
		else:
			_remap_default_action(config, context, mapping, meta, binding_id)
	return config


static func _is_player_binding(binding_id: StringName) -> bool:
	return binding_id in [
		&"attack_p1", &"guard_p1", &"spell_p1",
		&"attack_p2", &"guard_p2", &"spell_p2",
	]


static func _is_p1_binding(binding_id: StringName) -> bool:
	return binding_id in [&"attack_p1", &"guard_p1", &"spell_p1"]


static func _mouse_button(binding_id: StringName) -> MouseButton:
	if binding_id in [&"attack_p1", &"attack_p2"]:
		return MOUSE_BUTTON_LEFT
	if binding_id in [&"guard_p1", &"guard_p2"]:
		return MOUSE_BUTTON_RIGHT
	return MOUSE_BUTTON_MIDDLE


static func _remap_default_action(
	config: GUIDERemappingConfig,
	context: GUIDEMappingContext,
	mapping: GUIDEActionMapping,
	meta: MetaSave,
	binding_id: StringName
) -> void:
	var keys := KeyBindings.get_keys(meta, binding_id)
	var joy_button := KeyBindings.get_joy_button(meta, binding_id)
	var key_index := 0
	for index in mapping.input_mappings.size():
		var current: GUIDEInput = mapping.input_mappings[index].input
		if current is GUIDEInputKey:
			if key_index < keys.size():
				var key_input := GUIDEInputKey.new()
				key_input.key = keys[key_index]
				config._bind(context, mapping.action, key_input, index)
			else:
				config._unbind(context, mapping.action, index)
			key_index += 1
		elif current is GUIDEInputJoyButton:
			var joy_input := GUIDEInputJoyButton.new()
			joy_input.joy_index = (current as GUIDEInputJoyButton).joy_index
			joy_input.button = joy_button
			config._bind(context, mapping.action, joy_input, index)


static func _remap_versus_action(
	config: GUIDERemappingConfig,
	context: GUIDEMappingContext,
	mapping: GUIDEActionMapping,
	meta: MetaSave,
	binding_id: StringName,
	p1_gamepad: bool,
	p2_gamepad: bool
) -> void:
	var is_p1 := _is_p1_binding(binding_id)
	var uses_gamepad := p1_gamepad if is_p1 else p2_gamepad
	var mouse_owner := (is_p1 and not p1_gamepad) or (not is_p1 and p1_gamepad)
	var keys := KeyBindings.get_keys(meta, binding_id)
	var mouse_button := _mouse_button(binding_id)
	var joy_button := KeyBindings.get_joy_button(meta, binding_id)
	var key_index := 0
	var mouse_bound := false

	for index in mapping.input_mappings.size():
		var current: GUIDEInput = mapping.input_mappings[index].input
		if uses_gamepad:
			if index == 0:
				var joy_input := GUIDEInputJoyButton.new()
				# 只有一方手柄时用第一只手柄（joy_index 0）；双方手柄时 P1=0、P2=1。
				joy_input.joy_index = 0 if is_p1 or not p1_gamepad else 1
				joy_input.button = joy_button
				config._bind(context, mapping.action, joy_input, index)
			else:
				config._unbind(context, mapping.action, index)
			continue

		if current is GUIDEInputKey:
			if key_index < keys.size():
				var key_input := GUIDEInputKey.new()
				key_input.key = keys[key_index]
				config._bind(context, mapping.action, key_input, index)
			else:
				config._unbind(context, mapping.action, index)
			key_index += 1
		elif current is GUIDEInputMouseButton or current is GUIDEInputJoyButton:
			if mouse_owner and not mouse_bound:
				var mouse_input := GUIDEInputMouseButton.new()
				mouse_input.button = mouse_button
				config._bind(context, mapping.action, mouse_input, index)
				mouse_bound = true
			else:
				config._unbind(context, mapping.action, index)
