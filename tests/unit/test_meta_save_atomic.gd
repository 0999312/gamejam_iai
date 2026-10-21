extends GutTest

## 存档写入策略（审计 P1-6）：原子写、坏档隔离、人工清档、version 落盘。

const TEST_PATH := "user://test_meta_atomic.json"
const SUFFIXES: Array[String] = ["", ".tmp", ".bak", ".corrupt"]


func before_each() -> void:
	_cleanup()


func after_each() -> void:
	_cleanup()


func _cleanup() -> void:
	for suffix in SUFFIXES:
		var path := TEST_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func test_save_then_load_round_trips() -> void:
	var meta := MetaSave.new()
	meta.save_path = TEST_PATH
	meta.gold = 123
	meta.add_unlock(&"char_b")
	assert_true(meta.save(), "写入应成功")
	assert_true(FileAccess.file_exists(TEST_PATH), "正式档应存在")
	var loaded := MetaSave.load_from(TEST_PATH)
	assert_eq(loaded.gold, 123, "金币应持久化")
	assert_true(loaded.has_unlock(&"char_b"), "解锁应持久化")


## 审计 P1-6：MapCodec 会裁剪「等于默认值」的可选字段，
## version 曾因默认值写成 VERSION 而永远不落盘。
func test_version_is_written_to_disk() -> void:
	var meta := MetaSave.new()
	meta.save_path = TEST_PATH
	meta.gold = 1
	assert_true(meta.save())
	var text := FileAccess.get_file_as_string(TEST_PATH)
	var json := JSON.new()
	assert_eq(json.parse(text), OK, "存档必须是合法 JSON")
	var data: Dictionary = json.data
	assert_true(data.has("version"), "version 必须落盘")
	assert_eq(int(data["version"]), MetaSave.VERSION)


## 审计 P1-6：坏档必须隔离而不是被下一次 save 用默认值覆盖。
func test_corrupt_save_is_quarantined_not_overwritten() -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("{ this is not json")
	file.close()

	var loaded := MetaSave.load_from(TEST_PATH)
	assert_eq(loaded.gold, 0, "坏档应回落默认值")
	assert_false(FileAccess.file_exists(TEST_PATH), "坏档应被移出正式路径")
	assert_true(FileAccess.file_exists(TEST_PATH + MetaSave.CORRUPT_SUFFIX),
			"坏档应保留为 .corrupt 供人工捞取")


func test_wipe_removes_all_artifacts() -> void:
	var meta := MetaSave.new()
	meta.save_path = TEST_PATH
	meta.gold = 5
	assert_true(meta.save())
	assert_true(MetaSave.has_save(TEST_PATH), "保存后应判定为有存档")
	assert_true(MetaSave.wipe(TEST_PATH), "清档应成功")
	assert_false(MetaSave.has_save(TEST_PATH), "清档后不应再有存档")
	for suffix in SUFFIXES:
		assert_false(FileAccess.file_exists(TEST_PATH + suffix),
				"清档必须删掉 %s" % suffix)


## 旧档（没有 version 字段）应能读，且缺失的设置键补默认值。
func test_missing_version_reads_as_zero_and_fills_defaults() -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("{\"gold\": 42}")
	file.close()

	var loaded := MetaSave.load_from(TEST_PATH)
	assert_eq(loaded.gold, 42, "旧档金币应保留")
	assert_eq(loaded.version, 0, "缺失 version 一律读作 0")
	assert_true(loaded.settings.has("volume_master"), "缺失设置应补默认值")
	assert_true(loaded.stats.has("runs"), "缺失统计应补默认值")
