class_name KeyBindings
extends RefCounted

## 按键绑定：默认值与读写都集中在这里。
## settings["keys"] 用字符串 id 作为键，值为 int 数组，便于 JSON 持久化。
## settings["joy_buttons"] 用字符串 id 作为键，值为 JoyButton 的 int。

const DEFAULT_KEYS: Dictionary = {
	&"attack_p1": [KEY_J],
	&"guard_p1": [KEY_K],
	&"attack_p2": [KEY_KP_1, KEY_I],
	&"guard_p2": [KEY_KP_2, KEY_O],
	&"pause": [KEY_ESCAPE],
	&"restart": [KEY_R],
}

const DEFAULT_JOY_BUTTONS: Dictionary = {
	&"attack_p1": JOY_BUTTON_A,
	&"guard_p1": JOY_BUTTON_B,
	&"attack_p2": JOY_BUTTON_A,
	&"guard_p2": JOY_BUTTON_B,
	&"pause": JOY_BUTTON_START,
	&"restart": JOY_BUTTON_BACK,
}

const ACTION_ORDER: Array[StringName] = [
	&"attack_p1",
	&"guard_p1",
	&"attack_p2",
	&"guard_p2",
	&"pause",
	&"restart",
]

const JOY_LABELS: Dictionary = {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_BACK: "Back",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_DPAD_UP: "D-Up",
	JOY_BUTTON_DPAD_DOWN: "D-Down",
	JOY_BUTTON_DPAD_LEFT: "D-Left",
	JOY_BUTTON_DPAD_RIGHT: "D-Right",
}


## 补齐缺失项，并把旧存档里的 int/float 统一成 int 数组。
static func normalize(settings: Dictionary) -> void:
	if not settings.has("keys") or typeof(settings["keys"]) != TYPE_DICTIONARY:
		settings["keys"] = {}
	var keys: Dictionary = settings["keys"]
	for id in DEFAULT_KEYS.keys():
		var raw: Variant = keys.get(String(id), DEFAULT_KEYS[id])
		keys[String(id)] = _int_array(raw)

	if not settings.has("joy_buttons") or typeof(settings["joy_buttons"]) != TYPE_DICTIONARY:
		settings["joy_buttons"] = {}
	var joy: Dictionary = settings["joy_buttons"]
	for id in DEFAULT_JOY_BUTTONS.keys():
		var raw_joy: Variant = joy.get(String(id), DEFAULT_JOY_BUTTONS[id])
		joy[String(id)] = int(raw_joy) if _valid_joy_button(raw_joy) else int(DEFAULT_JOY_BUTTONS[id])


static func _int_array(raw: Variant) -> Array:
	var result: Array = []
	if typeof(raw) == TYPE_ARRAY:
		for value in raw as Array:
			result.append(int(value))
	return result


static func _valid_joy_button(raw: Variant) -> bool:
	if typeof(raw) != TYPE_INT and typeof(raw) != TYPE_FLOAT:
		return false
	var value := int(raw)
	return value >= 0 and value < JOY_BUTTON_MAX


static func get_keys(meta: MetaSave, id: StringName) -> Array[Key]:
	var result: Array[Key] = []
	if meta != null:
		normalize(meta.settings)
		var raw: Array = meta.settings["keys"].get(String(id), [])
		for value in raw:
			result.append(int(value))
		if not result.is_empty():
			return result
	for value in DEFAULT_KEYS.get(id, []):
		result.append(int(value))
	return result


## 把某个动作改成单键；与其它动作冲突时返回 false。
static func set_key(meta: MetaSave, id: StringName, key: Key) -> bool:
	if meta == null or not DEFAULT_KEYS.has(id):
		return false
	if is_bound(meta, key, id):
		return false
	normalize(meta.settings)
	meta.settings["keys"][String(id)] = [int(key)]
	return true


static func is_bound(meta: MetaSave, key: Key, except_id: StringName = &"") -> bool:
	for id in ACTION_ORDER:
		if id == except_id:
			continue
		if get_keys(meta, id).has(key):
			return true
	return false


static func get_joy_button(meta: MetaSave, id: StringName) -> int:
	if meta != null:
		normalize(meta.settings)
		return int(meta.settings["joy_buttons"].get(String(id), DEFAULT_JOY_BUTTONS.get(id, JOY_BUTTON_A)))
	return int(DEFAULT_JOY_BUTTONS.get(id, JOY_BUTTON_A))


## 手柄键冲突只会在同一手柄作用域内检查：
## P1 动作彼此冲突；P2 动作彼此冲突；暂停/重开是全局键，和所有人都冲突。
## P1 与 P2 可以都用 A/B，因为他们使用不同手柄。
static func set_joy_button(meta: MetaSave, id: StringName, button: int) -> bool:
	if meta == null or not DEFAULT_JOY_BUTTONS.has(id):
		return false
	if not _valid_joy_button(button):
		return false
	normalize(meta.settings)
	if _joy_conflict(meta, id, button) != &"":
		return false
	meta.settings["joy_buttons"][String(id)] = button
	return true


static func joy_conflict(meta: MetaSave, id: StringName, button: int) -> StringName:
	return _joy_conflict(meta, id, button)


static func _joy_conflict(meta: MetaSave, id: StringName, button: int) -> StringName:
	for other in ACTION_ORDER:
		if other == id:
			continue
		if not _same_joy_scope(id, other):
			continue
		if get_joy_button(meta, other) == button:
			return other
	return &""


static func _same_joy_scope(a: StringName, b: StringName) -> bool:
	if a == b:
		return true
	if _is_global(a) or _is_global(b):
		return true
	return _is_p1(a) == _is_p1(b)


static func _is_p1(id: StringName) -> bool:
	return id == &"attack_p1" or id == &"guard_p1"


static func _is_global(id: StringName) -> bool:
	return id == &"pause" or id == &"restart"


static func reset(meta: MetaSave) -> void:
	if meta == null:
		return
	meta.settings["keys"] = {}
	meta.settings["joy_buttons"] = {}
	normalize(meta.settings)


static func label(meta: MetaSave, id: StringName) -> String:
	var names: PackedStringArray = []
	for key in get_keys(meta, id):
		names.append(OS.get_keycode_string(key))
	return " / ".join(names)


static func label_joy(meta: MetaSave, id: StringName) -> String:
	var button := get_joy_button(meta, id)
	return String(JOY_LABELS.get(button, "Btn %d" % button))


static func label_key(id: StringName) -> String:
	return "settings.key_%s" % String(id)
