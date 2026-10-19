# 帧步进与时序：用 wait_frames / wait_physics_frames 推进，绝不 sleep。
# 判定窗口一律用物理帧计数断言，不要用毫秒估算。
extends GutTest

const MELEE_ACTIVE_START: int = 4
const MELEE_ACTIVE_END: int = 7


class MeleeWindow:
	extends Node

	var frame: int = 0

	func advance() -> void:
		frame += 1

	func is_active() -> bool:
		return frame >= MELEE_ACTIVE_START and frame <= MELEE_ACTIVE_END


func test_wait_frames_advances_render_frames() -> void:
	var start: int = Engine.get_process_frames()

	await wait_frames(3)

	var elapsed: int = Engine.get_process_frames() - start
	assert_between(elapsed, 3, 4, "wait_frames(3) 应推进 3 个渲染帧（允许 ±1 边界）")


func test_wait_physics_frames_advances_physics_frames() -> void:
	var start: int = Engine.get_physics_frames()

	await wait_physics_frames(5)

	var elapsed: int = Engine.get_physics_frames() - start
	assert_between(elapsed, 5, 6, "wait_physics_frames(5) 应推进 5 个物理帧")


func test_melee_window_only_opens_between_start_and_end() -> void:
	var window := MeleeWindow.new()
	autofree(window)
	var active_frames: Array[int] = []

	for i in 12:
		window.advance()
		if window.is_active():
			active_frames.append(window.frame)

	assert_eq(active_frames, [4, 5, 6, 7], "判定只在第 4–7 帧激活")


func test_frame_progress_is_independent_of_wall_clock() -> void:
	var window := MeleeWindow.new()
	autofree(window)

	window.advance()
	await wait_frames(1)
	window.advance()

	assert_eq(window.frame, 2, "帧号只随 advance() 增加，与真实时间无关")
