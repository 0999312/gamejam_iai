extends Node

## 启动引导（autoload）：注册 MSF 注册表条目、加载本地化。
## 只做数据/框架接线，不承载玩法逻辑。

const REGISTRY_NAME := "upgrade"
const UNLOCK_REGISTRY_NAME := "unlock"
const UNLOCK_DIR := "res://resources/unlocks"
const NAMESPACE := "iai"
const DEFAULT_LANGUAGE := "zh_CN"
const I18N_FILES: Dictionary = {
	"zh_CN": "res://localization/zh_CN.json",
	"en": "res://localization/en.json",
}

## 10 个心得。effect 由 RunState 解释，amount 为效果数值。
const UPGRADE_DEFS := [
	{"id": "u01", "effect": "guard_duration", "amount": 2},
	{"id": "u02", "effect": "commit", "amount": -2},
	{"id": "u03", "effect": "perfect_gain", "amount": 18},
	{"id": "u04", "effect": "start_flow", "amount": 10},
	{"id": "u05", "effect": "hint_lead", "amount": 4},
	{"id": "u06", "effect": "see_through", "amount": 1},
	{"id": "u07", "effect": "pursuit", "amount": 1},
	{"id": "u08", "effect": "guts", "amount": 1},
	{"id": "u09", "effect": "opening_commit", "amount": -3},
	{"id": "u10", "effect": "heal_bonus", "amount": 2},
]

## 局外存档由 autoload 持有，菜单/对局只读引用。
var meta: MetaSave

## 菜单选择：run / versus；由 duel_controller 在 _ready 读取。
var pending_mode: StringName = &"run"

## 菜单选择：char_a / char_b / char_c；由 RunState 读取。
var pending_character: StringName = &"char_a"

## 困难模式：局外解锁 + 设置开关。
var hard_mode: bool = false


func _ready() -> void:
	_ensure_ui_gamepad_actions()
	_ensure_registry(REGISTRY_NAME)
	_ensure_registry(UNLOCK_REGISTRY_NAME)
	_register_upgrades()
	_register_unlocks()
	meta = MetaSave.load_from()
	KeyBindings.normalize(meta.settings)
	_load_i18n(current_language())
	hard_mode = bool(meta.settings.get("hard_mode", false))
	_ensure_audio_buses()
	apply_settings()
	_refresh_guide_joy_devices.call_deferred()


## Godot 可能在 autoload 初始化帧还没枚举完已连接的手柄，GUIDE 的
## joy_index -> device_id 表就会为空，表现为“手柄完全没反应”。下一帧再刷新一次。
func _refresh_guide_joy_devices() -> void:
	if GUIDE == null or GUIDE._input_state == null:
		return
	GUIDE._input_state._refresh_joy_device_ids(0, 0)


## Godot 内置 ui_accept / ui_cancel 默认只含键盘；补上手柄 A / B，
## 让菜单、商店、设置、暂停和奖励选择都能纯手柄操作。
func _ensure_ui_gamepad_actions() -> void:
	_add_joy_event("ui_accept", JOY_BUTTON_A)
	_add_joy_event("ui_cancel", JOY_BUTTON_B)
	_add_joy_event("ui_up", JOY_BUTTON_DPAD_UP)
	_add_joy_event("ui_down", JOY_BUTTON_DPAD_DOWN)
	_add_joy_event("ui_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_event("ui_right", JOY_BUTTON_DPAD_RIGHT)


func _add_joy_event(action: StringName, button_index: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button_index
	if InputMap.action_has_event(action, event):
		return
	InputMap.action_add_event(action, event)


func current_language() -> String:
	if meta == null:
		return DEFAULT_LANGUAGE
	var lang := String(meta.settings.get("language", DEFAULT_LANGUAGE))
	return lang if I18N_FILES.has(lang) else DEFAULT_LANGUAGE


func set_language(lang: String) -> bool:
	if meta == null or not I18N_FILES.has(lang):
		return false
	meta.settings["language"] = lang
	I18NManager.set_language(lang)
	save_meta()
	return true


func save_meta() -> void:
	if meta != null:
		meta.save()


func apply_settings() -> void:
	if meta == null:
		return
	var master := clampf(float(meta.settings.get("volume_master", 0.8)), 0.0, 1.0)
	var sfx := clampf(float(meta.settings.get("volume_sfx", 0.8)), 0.0, 1.0)
	var ambient := clampf(float(meta.settings.get("volume_ambient", 0.7)), 0.0, 1.0)
	var muted := bool(meta.settings.get("mute", false))
	var master_index := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_index, linear_to_db(maxf(master, 0.0001)))
	AudioServer.set_bus_mute(master_index, muted)
	if SoundManager != null:
		SoundManager.set_sound_volume(sfx)
		SoundManager.set_ambient_sound_volume(ambient)
	hard_mode = bool(meta.settings.get("hard_mode", false))
	_set_fullscreen(bool(meta.settings.get("fullscreen", false)))


func _set_fullscreen(enabled: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


## sound_manager 默认把 music/sfx/ui 都放在 Master 上，会触发共享总线警告。
## 建立 SFX / UI / Ambient / Music 四条子总线，并让 SoundManager 使用它们。
func _ensure_audio_buses() -> void:
	for bus_name in ["SFX", "UI", "Ambient", "Music"]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")
	if SoundManager == null:
		return
	SoundManager.set_default_sound_bus("SFX")
	SoundManager.set_default_ui_sound_bus("UI")
	SoundManager.set_default_ambient_sound_bus("Ambient")
	SoundManager.set_default_music_bus("Music")


func _ensure_registry(registry_name: String) -> void:
	if RegistryManager.has_registry(registry_name):
		var existing := RegistryManager.get_registry(registry_name)
		if existing != null:
			existing.clear()
		return
	RegistryManager.register_registry(registry_name, RegistryBase.new())


func _register_upgrades() -> void:
	var registry := RegistryManager.get_registry(REGISTRY_NAME)
	if registry == null:
		push_error("GameBootstrap: upgrade registry is missing")
		return
	for def in UPGRADE_DEFS:
		var data := UpgradeData.new()
		var id := StringName(def["id"])
		data.id = id
		data.name_key = "upgrade.%s.name" % id
		data.desc_key = "upgrade.%s.desc" % id
		data.effect = StringName(def["effect"])
		data.amount = int(def["amount"])
		registry.register(ResourceLocation.new(NAMESPACE, String(id)), data)


## 商店条目完全由数据驱动：扫描 res://resources/unlocks/*.tres，
## 每个 UnlockItem 以 id 注册到 "unlock" 注册表。新增条目不需要改代码。
func _register_unlocks() -> void:
	var registry := RegistryManager.get_registry(UNLOCK_REGISTRY_NAME)
	if registry == null:
		push_error("GameBootstrap: unlock registry is missing")
		return
	var dir := DirAccess.open(UNLOCK_DIR)
	if dir == null:
		push_error("GameBootstrap: missing %s" % UNLOCK_DIR)
		return
	for file_name in dir.get_files():
		# 导出后资源可能变成 .res 或带 .remap，统一还原成可 load 的逻辑路径。
		var logical_name := file_name.trim_suffix(".remap")
		if not (logical_name.ends_with(".tres") or logical_name.ends_with(".res")):
			continue
		var item := load("%s/%s" % [UNLOCK_DIR, logical_name]) as UnlockItem
		if item == null or item.id == &"":
			push_warning("GameBootstrap: invalid unlock resource %s" % file_name)
			continue
		registry.register(ResourceLocation.new(NAMESPACE, String(item.id)), item)


func _load_i18n(lang: String) -> void:
	for code in I18N_FILES.keys():
		var path := String(I18N_FILES[code])
		if not I18NManager.load_translation(String(code), path):
			push_error("GameBootstrap: failed to load %s" % path)
	I18NManager.set_language(lang)
