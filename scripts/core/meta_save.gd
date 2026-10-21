class_name MetaSave
extends RefCounted

## 局外存档：金币、解锁、设置、统计。
## 序列化走 mc_game_framework 的 Codec（record + JsonOps）：字段级 schema
## 校验、缺失字段回落默认值、损坏字段保留其余部分并给出诊断路径；
## 设置/统计是「键集合由运行时决定」的字典，交给 AnyCodec 透传。
## 失败/损坏时回退默认值，不阻塞游戏。
##
## 写入策略（2026-10-21 审计 P1-6）：
##   1. 先写 `meta_save.json.tmp`，写完整并确认无错误；
##   2. 旧档改名为 `meta_save.json.bak`；
##   3. 临时档改名为正式档；任一步失败则回滚，旧档永远可用。
## 这样断电/崩溃/磁盘满都不会留下半截存档。损坏档在加载时会被隔离成 `.corrupt`，
## 不会被随后的 save() 用默认值静默覆盖。

## 存档格式版本。1 = 现行结构（修复 version 被裁剪之前写出的档读作 0）。
const VERSION := 1
const DEFAULT_PATH := "user://meta_save.json"

const TMP_SUFFIX := ".tmp"
const BAK_SUFFIX := ".bak"
const CORRUPT_SUFFIX := ".corrupt"

## 设置项的默认值：实例初始化与版本迁移共用同一份，避免第三份真相。
const DEFAULT_SETTINGS: Dictionary = {
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
const DEFAULT_STATS: Dictionary = {
	"runs": 0,
	"clears": 0,
	"best_index": 0,
}

var version: int = VERSION
var gold: int = 0
var unlocks: Array[StringName] = [&"char_a"]
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var stats: Dictionary = DEFAULT_STATS.duplicate(true)

## 为空表示只在内存里用（测试 / 预览），不落盘。
var save_path: String = ""

static var _save_codec: Codec = null


## 存档 schema：顶层字段必选/可选 + 类型，缺字段用默认值补齐。
static func save_codec() -> Codec:
	if _save_codec == null:
		var unlocks_codec: Codec = Codec.STRING().list_of()
		var loose_map: Codec = Codec.map_of(Codec.STRING(), AnyCodec.new())
		_save_codec = Codec.record(MapCodec.build([
			# 默认值取 0 而不是 VERSION：MapCodec 会裁剪「等于默认值」的可选字段，
			# 若默认写成 VERSION，文件里永远不会出现 version（审计 P1-6）。
			# 0 是保留值，含义是「写这份存档的版本早于版本号机制」。
			Codec.INT().optional_field_of("version", 0).for_getter(
					func(obj: Dictionary) -> Variant: return obj.get("version", 0)),
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
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		push_warning("MetaSave: 存档为空或无法读取，使用默认存档")
		_quarantine(path)
		return meta
	# 文本解析用 JSON.parse（返回错误码而不是打引擎错误），
	# 结构校验交给 Codec：损坏的 JSON 与「合法 JSON 但字段错」走同一条诊断路径。
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("MetaSave: JSON 解析失败（第 %d 行：%s），原档已隔离为 .corrupt" % [json.get_error_line(), json.get_error_message()])
		_quarantine(path)
		return meta
	var decoded := save_codec().decode(json.data, JsonOps.INSTANCE)
	if decoded.is_error():
		push_warning("MetaSave: 存档字段校验失败（%s），原档已隔离为 .corrupt" % decoded.get_error())
		_quarantine(path)
		return meta
	if decoded.is_partial():
		push_warning("MetaSave: 存档部分字段损坏（%s），其余字段照常载入" % decoded.get_error())
	var value: Variant = decoded.get_value()
	if typeof(value) != TYPE_DICTIONARY:
		push_warning("MetaSave: 存档根节点不是对象，原档已隔离为 .corrupt")
		_quarantine(path)
		return meta
	meta._from_dict(value as Dictionary)
	return meta


## 是否存在可读存档（含备份）——设置页据此决定「清除存档」是否可用。
static func has_save(path: String = DEFAULT_PATH) -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + BAK_SUFFIX)


## 人工清档：删除正式档、备份、临时档与隔离档。
## 返回 true 表示所有存在的文件都被删掉了。
static func wipe(path: String = DEFAULT_PATH) -> bool:
	var ok := true
	for target in [path, path + BAK_SUFFIX, path + TMP_SUFFIX, path + CORRUPT_SUFFIX]:
		if not FileAccess.file_exists(target):
			continue
		if DirAccess.remove_absolute(target) != OK:
			push_warning("MetaSave: 无法删除 %s" % target)
			ok = false
	return ok


func save() -> bool:
	if save_path.is_empty():
		return false
	var encoded := save_codec().encode(_to_dict(), JsonOps.INSTANCE)
	if encoded.is_error():
		push_warning("MetaSave: 编码失败（%s），本次不写入" % encoded.get_error())
		return false
	return _write_atomic(JsonOps.to_json_string(encoded.get_value(), "\t"))


## 三步原子写：写临时档 → 旧档转 .bak → 临时档转正。任一步失败都保留旧档。
func _write_atomic(payload: String) -> bool:
	var tmp_path := save_path + TMP_SUFFIX
	var bak_path := save_path + BAK_SUFFIX

	var tmp := FileAccess.open(tmp_path, FileAccess.WRITE)
	if tmp == null:
		push_warning("MetaSave: 无法写入临时存档 %s（错误码 %d）" % [tmp_path, FileAccess.get_open_error()])
		return false
	tmp.store_string(payload)
	var write_error := tmp.get_error()
	tmp.close()
	if write_error != OK:
		push_warning("MetaSave: 临时存档写入中断（错误码 %d），保留原存档" % write_error)
		_remove_file(tmp_path)
		return false

	if FileAccess.file_exists(save_path):
		_remove_file(bak_path)
		var to_bak := DirAccess.rename_absolute(save_path, bak_path)
		if to_bak != OK:
			push_warning("MetaSave: 无法备份旧存档（错误码 %d），放弃本次写入" % to_bak)
			_remove_file(tmp_path)
			return false

	var promoted := DirAccess.rename_absolute(tmp_path, save_path)
	if promoted != OK:
		push_warning("MetaSave: 无法替换存档（错误码 %d），回滚到旧存档" % promoted)
		_remove_file(tmp_path)
		if FileAccess.file_exists(bak_path):
			DirAccess.rename_absolute(bak_path, save_path)
		return false
	return true


static func _remove_file(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## 坏档隔离：改名而不是删除，人工还能捞出金币/解锁信息。
static func _quarantine(path: String) -> void:
	var target := path + CORRUPT_SUFFIX
	_remove_file(target)
	if DirAccess.rename_absolute(path, target) != OK:
		push_warning("MetaSave: 坏档隔离失败，保留原文件 %s" % path)


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
		# 写盘永远写当前格式版本；内存里的 version 保留「这份档读自哪个版本」。
		"version": VERSION,
		"gold": gold,
		"unlocks": _unlock_strings(),
		"settings": settings.duplicate(true),
		"stats": stats.duplicate(true),
	}


func _from_dict(data: Dictionary) -> void:
	var raw_version := int(data.get("version", 0))
	if raw_version > VERSION:
		# 新版本存档被旧代码读到：按当前版本读已知字段，settings/stats 是透传的，
		# 未知键不会被丢掉，下次保存仍会带回去。
		push_warning("MetaSave: 存档版本 %d 高于本程序支持的 %d，按兼容模式读取" % [raw_version, VERSION])
	# 记录来源版本：调用方/测试可据此判断这份档是否需要迁移。
	version = raw_version
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

	var raw_stats: Variant = data.get("stats", {})
	if typeof(raw_stats) == TYPE_DICTIONARY:
		for key in (raw_stats as Dictionary).keys():
			stats[key] = (raw_stats as Dictionary)[key]
	for key in stats.keys():
		stats[key] = int(stats[key])

	# 迁移放在数据读入之后：补默认键时才能看到文件里真正有哪些键。
	_migrate(raw_version)
	KeyBindings.normalize(settings)


## 版本迁移的单一入口。0 = 版本号机制之前的存档，结构与 v1 相同。
## 以后加字段/改语义时，在这里按 from_version 逐级补默认值，不要散在各处。
func _migrate(from_version: int) -> void:
	if from_version >= VERSION:
		return
	for key in DEFAULT_SETTINGS.keys():
		if not settings.has(key):
			settings[key] = DEFAULT_SETTINGS[key]
	for key in DEFAULT_STATS.keys():
		if not stats.has(key):
			stats[key] = DEFAULT_STATS[key]


func _unlock_strings() -> Array[String]:
	var result: Array[String] = []
	for id in unlocks:
		result.append(String(id))
	return result
