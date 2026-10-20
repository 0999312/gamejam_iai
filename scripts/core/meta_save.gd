class_name MetaSave
extends RefCounted

## 局外存档：金币、解锁、设置、统计。纯数据 + JSON 读写，不依赖场景。
## 失败/损坏时回退默认值，不阻塞游戏。

const VERSION := 1
const DEFAULT_PATH := "user://meta_save.json"

var version: int = VERSION
var gold: int = 0
var unlocks: Array[StringName] = [&"char_a"]
var settings: Dictionary = {
	"volume_master": 0.8,
	"volume_sfx": 0.8,
	"volume_ambient": 0.7,
	"mute": false,
	"fullscreen": false,
	"hard_mode": false,
	"language": "zh_CN",
	"keys": {},
	"joy_buttons": {},
	"screen_shake": 1.0,
	"hint_level": 1,
}
var stats: Dictionary = {
	"runs": 0,
	"clears": 0,
	"best_index": 0,
}

## 为空表示只在内存里用（测试 / 预览），不落盘。
var save_path: String = ""


static func load_from(path: String = DEFAULT_PATH) -> MetaSave:
	var meta := MetaSave.new()
	meta.save_path = path
	if not FileAccess.file_exists(path):
		return meta
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return meta
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return meta
	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return meta
	meta._from_dict(parsed as Dictionary)
	return meta


func save() -> bool:
	if save_path.is_empty():
		return false
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("MetaSave: cannot write %s" % save_path)
		return false
	file.store_string(JSON.stringify(_to_dict(), "\t"))
	return true


func has_unlock(id: StringName) -> bool:
	return unlocks.has(id)


func add_unlock(id: StringName) -> void:
	if not unlocks.has(id):
		unlocks.append(id)


## 扣金币；成功返回 true。调用方负责随后 save()。
func spend(cost: int) -> bool:
	if cost < 0 or gold < cost:
		return false
	gold -= cost
	return true


func record_run(cleared: bool, best_index: int) -> void:
	stats["runs"] = int(stats.get("runs", 0)) + 1
	stats["best_index"] = maxi(int(stats.get("best_index", 0)), best_index)
	if cleared:
		stats["clears"] = int(stats.get("clears", 0)) + 1


func _to_dict() -> Dictionary:
	return {
		"version": version,
		"gold": gold,
		"unlocks": _unlock_strings(),
		"settings": settings.duplicate(true),
		"stats": stats.duplicate(true),
	}


func _from_dict(data: Dictionary) -> void:
	version = int(data.get("version", VERSION))
	gold = maxi(0, int(data.get("gold", 0)))

	var raw_unlocks: Variant = data.get("unlocks", [])
	if typeof(raw_unlocks) == TYPE_ARRAY:
		unlocks.clear()
		for item in raw_unlocks as Array:
			unlocks.append(StringName(str(item)))
	if not unlocks.has(&"char_a"):
		unlocks.push_front(&"char_a")

	var raw_settings: Variant = data.get("settings", {})
	if typeof(raw_settings) == TYPE_DICTIONARY:
		for key in settings.keys():
			if (raw_settings as Dictionary).has(key):
				settings[key] = (raw_settings as Dictionary)[key]
	KeyBindings.normalize(settings)

	var raw_stats: Variant = data.get("stats", {})
	if typeof(raw_stats) == TYPE_DICTIONARY:
		for key in stats.keys():
			if (raw_stats as Dictionary).has(key):
				stats[key] = int((raw_stats as Dictionary)[key])


func _unlock_strings() -> Array[String]:
	var result: Array[String] = []
	for id in unlocks:
		result.append(String(id))
	return result
