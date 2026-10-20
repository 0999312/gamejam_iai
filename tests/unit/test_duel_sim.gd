extends GutTest

## DuelSim 判定矩阵与帧窗单元测试（60 Hz 整数帧）。

var sim: DuelSim


func before_each() -> void:
	# 用固定的测试帧数据（13/14/25）验证判定逻辑本身；
	# 当前平衡值（18/20/32）由 test_player_a_balance_values 单独断言。
	var p1_data := FighterData.player_a()
	p1_data.base_commit = 13
	p1_data.whiff_recovery = 14
	p1_data.blocked_recovery = 25
	sim = DuelSim.new(p1_data, p1_data.duplicate(), 12345)


func test_player_a_balance_values() -> void:
	var data := FighterData.player_a()
	assert_eq(data.base_commit, 18, "主动出刀前摇应足够长，给对手反应空间")
	assert_eq(data.whiff_recovery, 20)
	assert_eq(data.blocked_recovery, 32, "被架必须能被确定惩罚")
	assert_eq(data.slash_cost, 4, "主动出刀消耗心流")
	assert_eq(data.flow_regen_interval, 24, "待机自然恢复心流")


func test_opening_lock_blocks_both_sides() -> void:
	sim.opening_lock_frames = 10
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	sim.tick()
	assert_eq(sim.p1.state, DuelTypes.State.IDLE)
	_tick_n(10)
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	sim.tick()
	assert_eq(sim.p1.state, DuelTypes.State.COMMIT)


func _tick_n(count: int) -> void:
	for i in count:
		sim.tick()


func test_initial_state() -> void:
	assert_eq(sim.frame, 0)
	assert_eq(sim.p1.state, DuelTypes.State.IDLE)
	assert_eq(sim.p1.hp, 3)
	assert_eq(sim.p1.flow, 40)
	assert_eq(sim.p2.hp, 3)
	assert_false(sim.finished)


func test_attack_hits_idle_opponent_on_slash_frame() -> void:
	watch_signals(sim)
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(14)

	assert_eq(sim.p2.hp, 2)
	assert_eq(sim.p2.state, DuelTypes.State.HITSTUN)
	assert_eq(sim.p1.state, DuelTypes.State.RECOVERY)
	assert_eq(sim.p2.flow, 25)
	assert_signal_emitted(sim, "hit_landed")


func test_guard_blocks_and_punishes_attacker() -> void:
	watch_signals(sim)
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.GUARD)
	_tick_n(14)

	assert_eq(sim.p2.hp, 3)
	assert_eq(sim.p2.state, DuelTypes.State.GUARD_REC)
	assert_eq(sim.p1.state, DuelTypes.State.RECOVERY)
	assert_eq(sim.p1.state_duration, sim.p1.data.blocked_recovery)
	assert_eq(sim.p2.flow, 47)
	assert_eq(sim.p1.flow, 28)
	assert_signal_emitted(sim, "attack_blocked")


func test_perfect_block_grants_bonus_flow() -> void:
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(11)
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.GUARD)
	_tick_n(3)

	assert_eq(sim.p2.flow, 52)
	assert_eq(sim.p1.flow, 28)
	assert_eq(sim.p2.perfect_streak, 1)


func test_guard_startup_is_hittable() -> void:
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(12)
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.GUARD)
	_tick_n(2)

	assert_eq(sim.p2.hp, 2)
	assert_eq(sim.p2.state, DuelTypes.State.HITSTUN)


func test_whiffed_guard_loses_flow() -> void:
	watch_signals(sim)
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.GUARD)
	_tick_n(15)

	assert_eq(sim.p2.flow, 32)
	assert_eq(sim.p2.state, DuelTypes.State.GUARD_REC)
	assert_signal_emitted(sim, "guard_whiffed")


func test_simultaneous_slash_clashes() -> void:
	watch_signals(sim)
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.ATTACK)
	_tick_n(14)

	assert_eq(sim.p1.state, DuelTypes.State.CLASH)
	assert_eq(sim.p2.state, DuelTypes.State.CLASH)
	assert_eq(sim.p1.flow, 42)
	assert_eq(sim.p2.flow, 42)
	assert_signal_emitted(sim, "clash_happened")


func test_feint_cancel_rewards_idle_observer() -> void:
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(3)

	var cancelled := sim.cancel_commit(DuelTypes.Side.P1)
	assert_true(cancelled)
	assert_eq(sim.p1.state, DuelTypes.State.RECOVERY)
	assert_eq(sim.p2.flow, 50)


func test_feint_cancel_fails_outside_commit() -> void:
	assert_false(sim.cancel_commit(DuelTypes.Side.P1))


func test_guard_cancel_only_in_early_commit_window() -> void:
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(6)
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.GUARD)
	_tick_n(1)
	assert_eq(sim.p1.state, DuelTypes.State.COMMIT)

	sim.reset(12345)
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(4)
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.GUARD)
	_tick_n(1)
	assert_eq(sim.p1.state, DuelTypes.State.GUARD)
	assert_eq(sim.p1.flow, 31)


func test_slash_interrupts_commit() -> void:
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(2)
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.ATTACK)
	_tick_n(12)

	assert_eq(sim.p2.hp, 2)
	assert_eq(sim.p2.state, DuelTypes.State.HITSTUN)


func test_slash_hits_guard_recovery() -> void:
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.GUARD)
	sim.tick()
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(14)

	assert_eq(sim.p2.hp, 2)
	assert_eq(sim.p2.state, DuelTypes.State.HITSTUN)


func test_slash_hits_blocked_attacker_recovery() -> void:
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.GUARD)
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.ATTACK)
	_tick_n(14)
	assert_eq(sim.p2.state, DuelTypes.State.RECOVERY)

	_tick_n(8)
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(14)

	assert_eq(sim.p2.hp, 2)
	assert_eq(sim.p2.state, DuelTypes.State.HITSTUN)


func test_input_buffer_executes_on_first_actionable_frame() -> void:
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.GUARD)
	_tick_n(14)
	assert_eq(sim.p1.state, DuelTypes.State.RECOVERY)

	# 被架硬直 25f：第 14 帧进入，第 39 帧恢复；第 37 帧按下斩（缓冲 4f）。
	_tick_n(23)
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(2)

	assert_eq(sim.p1.state, DuelTypes.State.COMMIT)


func test_input_buffer_expires_before_recovery_ends() -> void:
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.GUARD)
	_tick_n(14)

	# 第 30 帧按下（缓冲到 34），恢复第 39 帧才结束，应已过期。
	_tick_n(16)
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(9)

	assert_eq(sim.p1.state, DuelTypes.State.IDLE)


func test_same_frame_guard_has_priority() -> void:
	sim.set_input(DuelTypes.Side.P1, true, true)
	sim.tick()
	assert_eq(sim.p1.state, DuelTypes.State.GUARD)


func test_flow_floor_is_respected() -> void:
	sim.p2.flow = 20
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(14)
	assert_eq(sim.p2.flow, 15)


func test_whiff_guard_penalty_suppressed_after_hit() -> void:
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(14)
	assert_eq(sim.p2.flow, 25)
	assert_eq(sim.p2.hp, 2)

	_tick_n(26)
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.GUARD)
	_tick_n(14)
	assert_eq(sim.p2.flow, 25)


func test_passive_flow_while_opponent_commits() -> void:
	var teaching := DuelSim.new(FighterData.player_a(), FighterData.opponent_teaching(), 7)
	teaching.press(DuelTypes.Side.P2, DuelTypes.Action.ATTACK)
	for i in 20:
		teaching.tick()
	assert_eq(teaching.p1.flow, 41)


func test_no_input_penalty_after_grace() -> void:
	# 3 秒内待机自然恢复；之后停止恢复并转为惩罚，长时间干等必须净损失。
	_tick_n(400)
	assert_lt(sim.p1.flow, 40, "长时间无输入应净损失心流")
	assert_eq(sim.p1.flow, 36)


func test_lethal_hit_finishes_duel() -> void:
	sim.p2.hp = 1
	watch_signals(sim)
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(14)

	assert_true(sim.finished)
	assert_eq(sim.winner, DuelTypes.Side.P1)
	assert_eq(sim.p2.state, DuelTypes.State.DOWN)
	assert_signal_emitted(sim, "duel_finished")


func test_reset_restores_duel_state() -> void:
	sim.p2.hp = 1
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(14)
	assert_true(sim.finished)

	sim.reset(999)
	assert_false(sim.finished)
	assert_eq(sim.frame, 0)
	assert_eq(sim.p1.hp, 3)
	assert_eq(sim.p2.hp, 3)
	assert_eq(sim.p1.flow, 40)
	assert_eq(sim.p1.state, DuelTypes.State.IDLE)
