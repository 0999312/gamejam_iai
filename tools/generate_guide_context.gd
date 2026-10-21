extends SceneTree

## 编辑期工具：生成 GUIDE 的动作与上下文资源（运行期不执行）。
## 用法：godot --headless --path . -s tools/generate_guide_context.gd
##
## 资源只描述「结构 + 默认绑定」：键盘默认值取自 KeyBindings.DEFAULT_KEYS，
## 手柄默认值取自 KeyBindings.DEFAULT_JOY_BUTTONS，避免两套默认值漂移；
## 玩家改键在运行期通过 GUIDERemappingConfig 覆盖，不改这些资源。

const ACTION_DIR := "res://input/actions"
const CONTEXT_DIR := "res://input/contexts"

const ACTIONS: Array[Dictionary] = [
	{"id": &"duel_attack_p1", "binding": &"attack_p1"},
	{"id": &"duel_guard_p1", "binding": &"guard_p1"},
	{"id": &"duel_spell_p1", "binding": &"spell_p1"},
	{"id": &"duel_attack_p2", "binding": &"attack_p2"},
	{"id": &"duel_guard_p2", "binding": &"guard_p2"},
	{"id": &"duel_spell_p2", "binding": &"spell_p2"},
	{"id": &"duel_restart", "binding": &"restart"},
	{"id": &"duel_pause", "binding": &"pause"},
	{"id": &"duel_offer_1", "binding": &""},
	{"id": &"duel_offer_2", "binding": &""},
	{"id": &"duel_offer_3", "binding": &""},
]

const MOUSE_BUTTONS: Dictionary = {
	&"duel_attack_p1": MOUSE_BUTTON_LEFT,
	&"duel_guard_p1": MOUSE_BUTTON_RIGHT,
	&"duel_spell_p1": MOUSE_BUTTON_MIDDLE,
}

const P2_ACTIONS: Array[StringName] = [&"duel_attack_p2", &"duel_guard_p2", &"duel_spell_p2"]

const GLOBAL_ACTIONS: Array[StringName] = [&"duel_restart", &"duel_pause"]

const OFFER_IDS: Array[StringName] = [&"duel_offer_1", &"duel_offer_2", &"duel_offer_3"]
const OFFER_KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ACTION_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CONTEXT_DIR))
	var actions := _write_actions()
	_write_context("duel_run", actions, false)
	_write_context("duel_versus", actions, true)
	print("generate_guide_context: 已生成 %d 个动作 + 2 个上下文" % actions.size())
	quit()


func _write_actions() -> Dictionary:
	var actions: Dictionary = {}
	for spec in ACTIONS:
		var id: StringName = spec["id"]
		var action := GUIDEAction.new()
		action.name = id
		action.action_value_type = GUIDEAction.GUIDEActionValueType.BOOL
		action.display_name = String(id)
		action.is_remappable = spec["binding"] != &""
		var path := "%s/%s.tres" % [ACTION_DIR, String(id)]
		var err := ResourceSaver.save(action, path)
		if err != OK:
			push_error("generate_guide_context: 保存 %s 失败（%d）" % [path, err])
			continue
		actions[id] = load(path)
	return actions


func _write_context(mode: String, actions: Dictionary, versus: bool) -> void:
	var context := GUIDEMappingContext.new()
	context.display_name = mode
	for spec in ACTIONS:
		var id: StringName = spec["id"]
		var binding: StringName = spec["binding"]
		if OFFER_IDS.has(id):
			var index := OFFER_IDS.find(id)
			context.mappings.append(_mapping(actions[id], [OFFER_KEYS[index]], [], []))
			continue
		if P2_ACTIONS.has(id) and not versus:
			# 单人模式也要保留 P2 的键盘动作（历史上就存在，按下无效果但不该报错）。
			context.mappings.append(_mapping(actions[id], _keys(binding), [], []))
			continue
		var joys: Array[int] = []
		if P2_ACTIONS.has(id):
			joys = [1]
		elif GLOBAL_ACTIONS.has(id):
			joys.append(0)
			if versus:
				joys.append(1)
		else:
			joys = [0]
		var mouse: Array[MouseButton] = []
		if MOUSE_BUTTONS.has(id):
			mouse = [MOUSE_BUTTONS[id]]
		context.mappings.append(_mapping(actions[id], _keys(binding), mouse, joys, binding))
	var path := "%s/%s.tres" % [CONTEXT_DIR, mode]
	var err := ResourceSaver.save(context, path)
	if err != OK:
		push_error("generate_guide_context: 保存 %s 失败（%d）" % [path, err])


func _keys(binding: StringName) -> Array[Key]:
	var result: Array[Key] = []
	for value in KeyBindings.DEFAULT_KEYS.get(binding, []):
		result.append(int(value))
	return result


func _mapping(action: GUIDEAction, keys: Array[Key], mouse: Array[MouseButton],
		joys: Array[int], binding: StringName = &"") -> GUIDEActionMapping:
	var mapping := GUIDEActionMapping.new()
	mapping.action = action
	for key in keys:
		var input_mapping := GUIDEInputMapping.new()
		var key_input := GUIDEInputKey.new()
		key_input.key = key
		input_mapping.input = key_input
		mapping.input_mappings.append(input_mapping)
	for button in mouse:
		var input_mapping := GUIDEInputMapping.new()
		var mouse_input := GUIDEInputMouseButton.new()
		mouse_input.button = button
		input_mapping.input = mouse_input
		mapping.input_mappings.append(input_mapping)
	if binding != &"":
		for joy_index in joys:
			var input_mapping := GUIDEInputMapping.new()
			var joy_input := GUIDEInputJoyButton.new()
			joy_input.joy_index = joy_index
			joy_input.button = int(KeyBindings.DEFAULT_JOY_BUTTONS[binding])
			input_mapping.input = joy_input
			mapping.input_mappings.append(input_mapping)
	return mapping
