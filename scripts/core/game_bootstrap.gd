extends Node

## 启动引导（autoload）：注册 MSF 注册表条目、加载本地化。
## 只做数据/框架接线，不承载玩法逻辑。

const REGISTRY_NAME := "upgrade"
const NAMESPACE := "iai"
const LANG := "zh_CN"
const I18N_PATH := "res://localization/zh_CN.json"

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
	_ensure_registry()
	_register_upgrades()
	_load_i18n()
	meta = MetaSave.load_from()
	hard_mode = bool(meta.settings.get("hard_mode", false))
	_ensure_audio_buses()
	apply_settings()


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


func _ensure_registry() -> void:
	if RegistryManager.has_registry(REGISTRY_NAME):
		var existing := RegistryManager.get_registry(REGISTRY_NAME)
		if existing != null:
			existing.clear()
		return
	RegistryManager.register_registry(REGISTRY_NAME, RegistryBase.new())


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


func _load_i18n() -> void:
	if not I18NManager.load_translation(LANG, I18N_PATH):
		push_error("GameBootstrap: failed to load %s" % I18N_PATH)
		return
	I18NManager.set_language(LANG)
