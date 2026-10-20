extends GutTest

## MetaSave：默认值、JSON 往返、损坏回退、扣费、统计。

const TEST_PATH := "user://test_meta_save.json"


func before_each() -> void:
	_delete_test_file()


func after_each() -> void:
	_delete_test_file()


func test_defaults() -> void:
	var meta := MetaSave.new()
	assert_eq(meta.version, MetaSave.VERSION)
	assert_eq(meta.gold, 0)
	assert_eq(meta.unlocks, [&"char_a"])
	assert_true(meta.settings.has("volume_master"))
	assert_eq(meta.stats["runs"], 0)


func test_round_trip() -> void:
	var meta := MetaSave.new()
	meta.save_path = TEST_PATH
	meta.gold = 42
	meta.add_unlock(&"char_b")
	meta.settings["volume_master"] = 0.5
	meta.record_run(true, 5)
	assert_true(meta.save())

	var loaded := MetaSave.load_from(TEST_PATH)
	assert_eq(loaded.gold, 42)
	assert_true(loaded.has_unlock(&"char_a"))
	assert_true(loaded.has_unlock(&"char_b"))
	assert_almost_eq(float(loaded.settings["volume_master"]), 0.5, 0.001)
	assert_eq(loaded.stats["runs"], 1)
	assert_eq(loaded.stats["clears"], 1)
	assert_eq(loaded.stats["best_index"], 5)


func test_corrupt_file_falls_back() -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("{ this is not json")
	file = null
	var loaded := MetaSave.load_from(TEST_PATH)
	assert_eq(loaded.gold, 0)
	assert_eq(loaded.unlocks, [&"char_a"])


func test_spend() -> void:
	var meta := MetaSave.new()
	meta.gold = 50
	assert_false(meta.spend(70))
	assert_eq(meta.gold, 50)
	assert_true(meta.spend(40))
	assert_eq(meta.gold, 10)
	assert_false(meta.spend(-1))


func test_record_run() -> void:
	var meta := MetaSave.new()
	meta.record_run(false, 2)
	meta.record_run(true, 5)
	assert_eq(meta.stats["runs"], 2)
	assert_eq(meta.stats["clears"], 1)
	assert_eq(meta.stats["best_index"], 5)


func _delete_test_file() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
