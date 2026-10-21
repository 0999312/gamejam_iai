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


## 把 KeyBindings 的当前绑定套到上下文上：键盘槽按顺序替换，
## 多出来的槽显式解绑；手柄槽只换按键、保留 joy_index；鼠标槽保持资源默认。
static func build_remap_config(context: GUIDEMappingContext, meta: MetaSave) -> GUIDERemappingConfig:
	if context == null:
		return null
	var config := GUIDERemappingConfig.new()
	for mapping in context.mappings:
		if mapping == null or mapping.action == null:
			continue
		var binding_id: StringName = ACTION_BINDINGS.get(mapping.action.name, &"")
		if binding_id == &"":
			continue
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
	return config
