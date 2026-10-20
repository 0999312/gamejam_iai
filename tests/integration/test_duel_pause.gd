extends GutTest

## 对决内暂停：Esc/按钮进入后 sim 不再推进；继续后恢复。
## 不测场景切换，避免测试互相污染。

var ctrl
var _old_meta: MetaSave


func before_each() -> void:
	_old_meta = GameBootstrap.meta
	GameBootstrap.meta = MetaSave.new()
	ctrl = preload("res://scenes/duel/duel.tscn").instantiate()
	add_child_autofree(ctrl)
	await wait_process_frames(2)
	await wait_physics_frames(2)


func after_each() -> void:
	GameBootstrap.meta = _old_meta


func test_pause_stops_simulation_until_resume() -> void:
	var frame_before: int = ctrl.sim.frame
	ctrl._on_pause_pressed()
	assert_true(ctrl._paused)
	await wait_physics_frames(4)
	assert_eq(ctrl.sim.frame, frame_before)

	ctrl._on_resume_requested()
	await wait_physics_frames(3)
	assert_false(ctrl._paused)
	assert_gt(ctrl.sim.frame, frame_before)


func test_pause_restart_resets_current_duel() -> void:
	for _i in 8:
		await wait_physics_frames(1)
	var frame_before: int = ctrl.sim.frame
	assert_gt(frame_before, 0)
	ctrl._on_pause_pressed()
	ctrl._on_pause_restart_requested()
	await wait_physics_frames(1)

	assert_false(ctrl._paused)
	assert_lt(ctrl.sim.frame, frame_before)
	assert_eq(ctrl.run.phase, RunState.Phase.DUEL)
