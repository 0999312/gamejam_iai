extends GutTest

## 审计 P0-1：三个音量滑条曾把 I18N 键（"settings.master"）当设置键写入存档，
## 而 apply_settings() 读的是 volume_master → 滑条零生效且写脏存档。
## 这里钉住「写入的键」与「读取的键」是同一套。

var _old_meta: MetaSave


func before_each() -> void:
	_old_meta = GameBootstrap.meta
	GameBootstrap.meta = MetaSave.new()


func after_each() -> void:
	GameBootstrap.meta = _old_meta


func test_volume_changed_writes_volume_keys() -> void:
	var panel: Control = preload("res://scenes/ui/settings.tscn").instantiate()
	add_child_autofree(panel)
	await wait_process_frames(2)

	panel._on_volume_changed(50.0, "volume_master")
	panel._on_volume_changed(25.0, "volume_sfx")
	panel._on_volume_changed(75.0, "volume_ambient")

	var meta := GameBootstrap.meta
	assert_almost_eq(float(meta.settings.get("volume_master", -1.0)), 0.5, 0.001,
			"主音量应写入 volume_master")
	assert_almost_eq(float(meta.settings.get("volume_sfx", -1.0)), 0.25, 0.001,
			"音效应写入 volume_sfx")
	assert_almost_eq(float(meta.settings.get("volume_ambient", -1.0)), 0.75, 0.001,
			"环境音应写入 volume_ambient")


func test_i18n_keys_never_land_in_settings() -> void:
	var panel: Control = preload("res://scenes/ui/settings.tscn").instantiate()
	add_child_autofree(panel)
	await wait_process_frames(2)

	var meta := GameBootstrap.meta
	for i18n_key in ["settings.master", "settings.sfx", "settings.ambient"]:
		assert_false(meta.settings.has(i18n_key),
				"设置字典里不得出现 I18N 键 %s" % i18n_key)


## apply_settings 读取的键必须存在（否则滑条存了也没人读）。
func test_apply_settings_reads_volume_keys() -> void:
	var meta := GameBootstrap.meta
	meta.settings["volume_master"] = 0.3
	meta.settings["volume_sfx"] = 0.4
	meta.settings["volume_ambient"] = 0.5
	GameBootstrap.apply_settings()
	assert_almost_eq(float(meta.settings.get("volume_master", 0.0)), 0.3, 0.001)
	assert_almost_eq(float(meta.settings.get("volume_sfx", 0.0)), 0.4, 0.001)
	assert_almost_eq(float(meta.settings.get("volume_ambient", 0.0)), 0.5, 0.001)
