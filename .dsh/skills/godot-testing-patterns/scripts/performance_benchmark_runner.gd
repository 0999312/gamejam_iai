# 性能基准门控：用引擎 Performance 监视器取样，预算留足余量，避免 flaky。
# 基准测试不要卡死 CI：先只告警（pending），稳定后再升级为断言。
extends GutTest

const FRAME_BUDGET_MS: float = 8.0   # 60 FPS = 16.67 ms；取一半作为 process 时间预算
const WARMUP_FRAMES: int = 30
const SAMPLE_FRAMES: int = 120


func test_process_time_stays_within_budget() -> void:
	await wait_frames(WARMUP_FRAMES)   # 预热，跳过首帧资源加载

	var worst_ms: float = 0.0
	var total_ms: float = 0.0
	for i in SAMPLE_FRAMES:
		await wait_frames(1)
		var frame_ms: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		worst_ms = maxf(worst_ms, frame_ms)
		total_ms += frame_ms

	var average_ms: float = total_ms / float(SAMPLE_FRAMES)
	assert_lt(worst_ms, FRAME_BUDGET_MS, "最差单帧 process 时间 %.2f ms 超过预算 %.2f ms" % [worst_ms, FRAME_BUDGET_MS])
	assert_lt(average_ms, FRAME_BUDGET_MS * 0.5, "平均 process 时间 %.2f ms 偏高" % average_ms)


func test_object_count_does_not_grow_per_frame() -> void:
	await wait_frames(WARMUP_FRAMES)
	var baseline: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))

	await wait_frames(30)

	var after: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	assert_true(after - baseline < 50, "空转 30 帧对象数增长 %d，疑似每帧泄漏" % (after - baseline))
