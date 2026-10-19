# 金色文件测试：把存档/关卡状态序列化成 JSON，与 res://tests/goldens/ 下的参考文件比对。
# 审批流程：首次运行生成参考 → 有意变更后重新生成 → 人工 diff → 提交新文件。绝不手改字节。
extends GutTest

const GOLDEN_DIR: String = "res://tests/goldens"


func before_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GOLDEN_DIR))


func _golden_path(snapshot_name: String) -> String:
	return "%s/%s.json" % [GOLDEN_DIR, snapshot_name]


func _save_golden(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file, "无法写入金色文件: " + path)
	file.store_string(JSON.stringify(value, "\t") + "\n")
	file.close()


func _load_golden(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func _sanitize(value: Variant) -> Variant:
	# 浮点/瞬时值不要进金色文件，先取整或剔除，否则每次跑都 diff。
	if value is float:
		return snappedf(value, 0.001)
	if value is Array:
		var out: Array = []
		for item in value:
			out.append(_sanitize(item))
		return out
	if value is Dictionary:
		var out_dict: Dictionary = {}
		for key in value:
			out_dict[key] = _sanitize(value[key])
		return out_dict
	return value


# update=true 时强制重写参考文件（用于有意变更后重新生成）。
func assert_golden(snapshot_name: String, actual: Variant, update: bool = false) -> void:
	var path: String = _golden_path(snapshot_name)
	var value: Variant = _sanitize(actual)

	if update or not FileAccess.file_exists(path):
		_save_golden(path, value)
		pass_test(("updated " if update else "created ") + path)
		return

	assert_eq(value, _load_golden(path), "金色文件不一致: " + path + "（确认改动后重新生成）")


func test_duel_result_snapshot() -> void:
	var result := {
		"winner": "player",
		"rounds": [
			{"index": 1, "hp_left": 2, "frames_taken": 143},
		],
		"flow_peak": 87,
	}

	assert_golden("duel_result", result)
