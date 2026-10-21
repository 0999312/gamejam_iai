class_name MetaSave
extends RefCounted

## 局外存档：金币、解锁、设置、统计。
## 序列化走 mc_game_framework 的 Codec（record + JsonOps）：字段级 schema
## 校验、缺失字段回落默认值、损坏字段保留其余部分并给出诊断路径；
## 设置/统计是「键集合由运行时决定」的字典，交给 AnyCodec 透传。
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

static var _save_codec: Codec = null


## 存档 schema：顶层字段必选/可选 + 类型，缺字段用默认值补齐。
static func save_codec() -> Codec:
	if _save_codec == null:
		var unlocks_codec: Codec = Codec.STRING().list_of()
		var loose_map: Codec = Codec.map_of(Codec.STRING(), AnyCodec.new())
		_save_codec = Codec.record(MapCodec.build([
			Codec.INT().optional_field_of("version", VERSION).for_getter(
					func(obj: Dictionary) -> Variant: return obj.get("version", VERSION)),
			Codec.INT().optional_field_of("gold", 0).for_getter(
					func(obj: Dictionary) -> Variant: return obj.get("gold", 0)),
			unlocks_codec.optional_field_of("unlocks", []).for_getter(
					func(obj: Dictionary) -> Variant: return obj.get("unlocks", [])),
			loose_map.optional_field_of("settings", {}).for_getter(
					func(obj: Dictionary) -> Variant: return obj.get("settings", {})),
			loose_map.optional_field_of("stats", {}).for_getter(
					func(obj: Dictionary) -> Variant: return obj.get("stats", {})),
		], func(p_version: int, p_gold: int, p_unlocks: Array, p_settings: Dictionary, p_stats: Dictionary) -> Dictionary:
			return {
				"version": p_version,
				"gold": p_gold,
				"unlocks": p_unlocks,
				"settings": p_settings,
				"stats": p_stats,
			}
		))
	return _save_codec


static func load_from(path: String = DEFAULT_PATH) -> MetaSave:
	var meta := MetaSave.new()
	meta.save_path = path
	if not FileAccess.file_exists(path):
		return meta
	# 文本解析用 JSON.parse（返回错误码而不是打引擎错误），
	# 结构校验交给 Codec：损坏的 JSON 与「合法 JSON 但字段错」走同一条诊断路径。
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_warning("MetaSave: JSON 解析失败（第 %d 行：%s），使用默认存档" % [json.get_error_line(), json.get_error_message()])
		return meta
	var decoded := save_codec().decode(json.data, JsonOps.INSTANCE)
	if decoded.is_error():
		push_warning("MetaSave: 存档字段校验失败（%s），使用默认存档" % decoded.get_error())
		return meta
	if decoded.is_partial():
		push_warning("MetaSave: 存档部分字段损坏（%s），其余字段照常载入" % decoded.get_error())
	var value: Variant = decoded.get_value()
	if typeof(value) != TYPE_DICTIONARY:
		return meta
	meta._from_dict(value as Dictionary)
	return meta


func save() -> bool:
	if save_path.is_empty():
		return false
	var encoded := save_codec().encode(_to_dict(), JsonOps.INSTANCE)
	if encoded.is_error():
		push_warning("MetaSave: 编码失败（%s），本次不写入" % encoded.get_error())
		return false
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("MetaSave: cannot write %s" % save_path)
		return false
	file.store_string(JsonOps.to_json_string(encoded.get_value(), "\t"))
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
		for key in (raw_settings as Dictionary).keys():
			settings[key] = (raw_settings as Dictionary)[key]
	KeyBindings.normalize(settings)

	var raw_stats: Variant = data.get("stats", {})
	if typeof(raw_stats) == TYPE_DICTIONARY:
		for key in (raw_stats as Dictionary).keys():
			stats[key] = (raw_stats as Dictionary)[key]
	for key in stats.keys():
		stats[key] = int(stats[key])


func _unlock_strings() -> Array[String]:
	var result: Array[String] = []
	for id in unlocks:
		result.append(String(id))
	return result
