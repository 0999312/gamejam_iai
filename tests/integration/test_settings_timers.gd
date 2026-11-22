extends GutTest

## 设置面板重建 UI 时不能把防抖计时器一起释放，否则每次 value_changed
## 都会退化成 tmp→bak→rename 三次同步写盘（审计 P2-14）。

const SETTINGS_SCENE := preload("res://scenes/ui/settings.tscn")

var _old_meta: MetaSave
var _panel: Control


func before_each() -> void:
	_old_meta = GameBootstrap.meta
	GameBootstrap.meta = MetaSave.new()
	_panel = SETTINGS_SCENE.instantiate() as Control
	add_child_autofree(_panel)
	await wait_process_frames(2)


func after_each() -> void:
	GameBootstrap.meta = _old_meta


func test_timers_survive_ui_rebuilds() -> void:
	var save_timer := _panel.get("_save_timer") as Timer
	var wipe_timer := _panel.get("_wipe_timer") as Timer
	assert_not_null(save_timer)
	assert_not_null(wipe_timer)
	_panel.call("_build_ui")
	await wait_process_frames(1)
	assert_true(is_instance_valid(save_timer), "防抖计时器不能被 _build_ui 释放")
	assert_true(is_instance_valid(wipe_timer), "清档计时器不能被 _build_ui 释放")
	assert_true(save_timer.is_inside_tree())
	assert_true(wipe_timer.is_inside_tree())


func test_volume_change_uses_the_debounced_timer() -> void:
	var save_timer := _panel.get("_save_timer") as Timer
	assert_not_null(save_timer)
	if save_timer == null:
		return
	_panel.call("_on_volume_changed", 50.0, "volume_master")
	assert_gt(save_timer.time_left, 0.0, "音量变化应进入防抖窗口，而不是立刻 save_meta")
	await wait_for_signal(save_timer.timeout, 1.0)
	assert_eq(save_timer.time_left, 0.0)
