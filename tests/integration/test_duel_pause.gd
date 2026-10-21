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


## 审计 P1-1：用 Esc/Start 二次按下关闭暂停（而不是按面板「继续」按钮）时，
## 暂停期间按下的攻击不得在恢复的第一帧被消费。
func test_escape_close_clears_queued_attack() -> void:
	ctrl._last_pause_ms = -100000
	ctrl._on_pause_pressed()
	assert_true(ctrl._paused)

	# 模拟暂停期间按了攻击：走 _input 的手柄分支会被 _paused 直接丢弃，
	# 这里直接置位队列，验证「关闭暂停」这一步本身也会兜底清空。
	ctrl._attack_queued = true

	ctrl._last_pause_ms = -100000
	ctrl._on_pause_pressed()
	assert_false(ctrl._paused, "第二次按下应关闭暂停")
	assert_false(ctrl._attack_queued, "关闭暂停必须清空按键队列")


## 审计 P1-1：暂停期间的手柄按键必须被 _paused 守卫丢弃。
func test_input_is_ignored_while_paused() -> void:
	ctrl._last_pause_ms = -100000
	ctrl._on_pause_pressed()
	assert_true(ctrl._paused)

	var meta: MetaSave = GameBootstrap.meta
	var attack_button := KeyBindings.get_joy_button(meta, &"attack_p1")
	var event := InputEventJoypadButton.new()
	event.button_index = attack_button
	event.pressed = true
	ctrl._input(event)
	assert_false(ctrl._attack_queued, "暂停期间的攻击输入必须被丢弃")
