extends GutTest

## DuelSim 判定矩阵与帧窗单元测试（60 Hz 整数帧）。
## 自平衡 02 起血量 ×10（char_a 30 血 / 一刀 10），因此断言里的 HP 都是两位数。

var sim: DuelSim


func before_each() -> void:
	# 用固定的测试帧数据（13/14/25）验证判定逻辑本身；
	# 当前平衡值（18/20/32）由 test_player_a_balance_values 单独断言。
	var p1_data := FighterData.for_character(&"char_a")
	p1_data.base_commit = 13
	p1_data.whiff_recovery = 14
	p1_data.blocked_recovery = 25
	sim = DuelSim.new(p1_data, p1_data.duplicate(), 12345)


func test_player_a_balance_values() -> void:
	var data := FighterData.for_character(&"char_a")
	assert_eq(data.base_commit, 14, "主动出刀前摇 233ms：够对手读，又不至于让玩家觉得按了不出刀")
	assert_eq(data.whiff_recovery, 20)
	assert_eq(data.blocked_recovery, 32, "被架必须能被确定惩罚")
	assert_eq(data.guard_duration_base, 20, "架窗要能覆盖 100–300ms 的按下延迟")
	assert_eq(data.hit_damage, 10)
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


func test_opening_lock_grants_no_flow() -> void:
	# 反馈 5：开场待机的几秒不该白涨心流（之前礼让期没有 gate，白送约 +7）。
	sim.opening_lock_frames = 180
	_tick_n(179)
	assert_eq(sim.p1.flow, 40, "礼让期内不涨心流")
	assert_eq(sim.p2.flow, 40)
	_tick_n(30)
	assert_gt(sim.p1.flow, 40, "解锁后按自然恢复开始涨")
	assert_lt(sim.p1.flow, 48, "只该是自然的恢复速度")
	# 礼让结束 3 秒内不应触发「无输入惩罚」。
	_tick_n(140)
	assert_gte(sim.p1.flow, 41, "礼让刚结束就扣心流会让人莫名其妙")


func _tick_n(count: int) -> void:
	for i in count:
		sim.tick()


func test_initial_state() -> void:
	assert_eq(sim.frame, 0)
	assert_eq(sim.p1.state, DuelTypes.State.IDLE)
	assert_eq(sim.p1.hp, 30)
	assert_eq(sim.p1.flow, 40)
	assert_eq(sim.p2.hp, 30)
	assert_false(sim.finished)


func test_attack_hits_idle_opponent_on_slash_frame() -> void:
	watch_signals(sim)
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(14)

	assert_eq(sim.p2.hp, 20)
	assert_eq(sim.p2.state, DuelTypes.State.HITSTUN)
	assert_eq(sim.p1.state, DuelTypes.State.RECOVERY)
	assert_eq(sim.p2.flow, 25)
	assert_signal_emitted(sim, "hit_landed")


func test_guard_blocks_and_punishes_attacker() -> void:
	watch_signals(sim)
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.GUARD)
	_tick_n(14)

	assert_eq(sim.p2.hp, 30)
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
	_tick_n(1)
	var total: int = sim.p1.commit_total
	# 推到出刀前一帧，再按「架」：起架当帧仍在 guard_startup 内，应当被打中。
	# （guard_startup 已降到 1f，所以「同帧按下」是唯一还能撞上前摇的时机。）
	_tick_n(total - 1)
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.GUARD)
	_tick_n(1)

	assert_eq(sim.p2.hp, 20)
	assert_eq(sim.p2.state, DuelTypes.State.HITSTUN)


func test_whiffed_guard_loses_flow() -> void:
	watch_signals(sim)
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.GUARD)
	# 架窗 = guard_startup + guard_duration_base + 心流档位偏移，等它自然走完。
	var guard_frames: int = sim.p2.data.guard_startup + sim.p2.data.guard_duration_base \
			+ DuelTypes.GUARD_TIER_OFFSET[DuelTypes.tier_for_flow(sim.p2.flow)]
	_tick_n(guard_frames + 1)

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
	# 窗口 = cancel_window（10f = 167ms）；第 10 帧之后再按架就变不了了。
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(11)
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.GUARD)
	_tick_n(1)
	assert_eq(sim.p1.state, DuelTypes.State.COMMIT)

	sim.reset(12345)
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(9)
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.GUARD)
	_tick_n(1)
	assert_eq(sim.p1.state, DuelTypes.State.GUARD)
	assert_eq(sim.p1.flow, 31)


## 防御转攻：架窗内按斩 = 放弃剩余格挡、立刻出刀。
func test_guard_can_cancel_into_attack() -> void:
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.GUARD)
	_tick_n(3)
	assert_eq(sim.p1.state, DuelTypes.State.GUARD)

	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(1)
	assert_eq(sim.p1.state, DuelTypes.State.COMMIT, "架中按斩应立刻收架出刀")
	assert_eq(sim.p1.flow, 31, "取消税 5 + 出刀 4")


## 架住之后：GUARD_REC 的前 GUARD_COUNTER_WINDOW 帧内按斩，取消收架反打。
func test_blocked_guard_can_counter_attack() -> void:
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.GUARD)
	_tick_n(19)
	assert_eq(sim.p2.state, DuelTypes.State.GUARD_REC)

	sim.press(DuelTypes.Side.P2, DuelTypes.Action.ATTACK)
	_tick_n(1)
	assert_eq(sim.p2.state, DuelTypes.State.COMMIT, "架住后 8f 内可以取消收架反打")


func test_slash_interrupts_commit() -> void:
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(2)
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.ATTACK)
	_tick_n(12)

	assert_eq(sim.p2.hp, 20)
	assert_eq(sim.p2.state, DuelTypes.State.HITSTUN)


func test_slash_hits_guard_recovery() -> void:
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.GUARD)
	# 先让守方接近架窗末尾，再让攻方的斩判定落在「架收招」里。
	var guard_frames: int = sim.p2.data.guard_startup + sim.p2.data.guard_duration_base \
			+ DuelTypes.GUARD_TIER_OFFSET[DuelTypes.tier_for_flow(sim.p2.flow)]
	_tick_n(guard_frames - 6)
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(sim.p1.data.base_commit + 2)

	assert_eq(sim.p2.hp, 20)
	assert_eq(sim.p2.state, DuelTypes.State.HITSTUN)


func test_slash_hits_blocked_attacker_recovery() -> void:
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.GUARD)
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.ATTACK)
	_tick_n(14)
	assert_eq(sim.p2.state, DuelTypes.State.RECOVERY)

	_tick_n(8)
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(14)

	assert_eq(sim.p2.hp, 20)
	assert_eq(sim.p2.state, DuelTypes.State.HITSTUN)


func test_riposte_shortens_commit_in_foe_recovery() -> void:
	# 反斩（平衡 02 §1.5）：对手空架/空挥的硬直里出刀，前摇缩短，
	# 让「读招 → 架住 → 惩罚」这条链真的来得及。
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.GUARD)
	var guard_frames: int = sim.p2.data.guard_startup + sim.p2.data.guard_duration_base \
			+ DuelTypes.GUARD_TIER_OFFSET[DuelTypes.tier_for_flow(sim.p2.flow)]
	_tick_n(guard_frames + 1)
	assert_eq(sim.p2.state, DuelTypes.State.GUARD_REC, "对手应处在被架收招里")

	sim.p1.data.riposte_commit_bonus = -4
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(1)

	assert_eq(sim.p1.state, DuelTypes.State.COMMIT)
	assert_true(sim.p1.riposte, "空档出刀应标记为反斩")
	assert_eq(sim.p1.commit_total, sim.p1.data.base_commit - 4, "反斩应缩短前摇")


func test_commit_without_riposte_keeps_full_startup() -> void:
	# 对手站着不动时没有反斩加成：前摇必须保持满值，否则反应窗口又没了。
	sim.p1.data.riposte_commit_bonus = -4
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(1)
	assert_false(sim.p1.riposte)
	assert_eq(sim.p1.commit_total, sim.p1.data.base_commit)


func test_repeat_commit_is_penalized() -> void:
	# 间合惩罚（平衡 02 §2）：1 秒内连续出刀前摇变长，最多叠 2 层。
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(1)
	assert_eq(sim.p1.commit_total, sim.p1.data.base_commit)
	assert_eq(sim.p1.repeat_penalty_frames, 0)

	_tick_n(sim.p1.state_duration + sim.p1.data.whiff_recovery + 1)
	assert_eq(sim.p1.state, DuelTypes.State.IDLE, "第一刀应已收势")

	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(1)
	assert_eq(sim.p1.repeat_streak, 1)
	assert_eq(sim.p1.repeat_penalty_frames, sim.p1.data.repeat_commit_penalty)
	assert_eq(sim.p1.commit_total,
			sim.p1.data.base_commit + sim.p1.data.repeat_commit_penalty,
			"连斩的前摇应被拉长")


func test_repeat_penalty_caps_at_two_stacks() -> void:
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(1)
	for i in 3:
		_tick_n(sim.p1.state_duration + sim.p1.data.whiff_recovery + 1)
		sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
		_tick_n(1)
	assert_eq(sim.p1.repeat_streak, 2, "间合惩罚只叠 2 层")


## 没有输入缓冲：硬直里按下的斩就是作废，不会排队到能动的那一帧。
## 缓冲会让「几秒前按的一刀自己冒出来」，玩家感觉角色在延迟执行指令。
func test_input_during_recovery_is_dropped() -> void:
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.GUARD)
	_tick_n(26)
	assert_eq(sim.p1.state, DuelTypes.State.RECOVERY, "刀被架住，正在收招")

	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(30)
	assert_eq(sim.p1.state, DuelTypes.State.IDLE, "收招结束就回待机，不会自动接上那一刀")


## 构中连按的第二刀同样作废：要么当场生效，要么丢掉，不延后执行。
func test_input_during_commit_is_dropped() -> void:
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(2)
	assert_eq(sim.p1.state, DuelTypes.State.COMMIT)
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(40)
	assert_eq(sim.p1.state, DuelTypes.State.IDLE, "构中连按的第二刀不会在收招后自己冒出来")


## 待机时按下立刻生效（这是「无缓冲」下唯一该出刀的时刻）。
func test_input_while_idle_acts_on_next_frame() -> void:
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(1)
	assert_eq(sim.p1.state, DuelTypes.State.COMMIT)


## 架住后 15f（250ms 反应）按斩：仍在 30f 反击窗内，前摇 -6f（顺势斩）。
func test_counter_strike_shortens_commit() -> void:
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.GUARD)
	_tick_n(19)
	assert_eq(sim.p2.state, DuelTypes.State.GUARD_REC)

	_tick_n(14)
	assert_eq(sim.p2.state, DuelTypes.State.IDLE, "收架已结束，但反击预备还没过期")
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.ATTACK)
	_tick_n(1)
	assert_eq(sim.p2.state, DuelTypes.State.COMMIT)
	assert_eq(sim.p2.commit_total,
			maxi(DuelSim.COMMIT_MIN_FRAMES, sim.p2.data.base_commit - 6), "顺势斩前摇 -6f")


## 超过 500ms 才按：回到普通出刀（没有 -6f），否则等于无限反击窗。
func test_counter_strike_expires_after_window() -> void:
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.GUARD)
	_tick_n(19)
	_tick_n(32)

	sim.press(DuelTypes.Side.P2, DuelTypes.Action.ATTACK)
	_tick_n(1)
	assert_eq(sim.p2.state, DuelTypes.State.COMMIT)
	assert_eq(sim.p2.commit_total, sim.p2.data.base_commit, "窗口外没有顺势斩加成")


## 点按架：松手后 2f 收势、不扣心流、不算空架。
func test_tap_guard_releases_without_penalty() -> void:
	var flow_before: int = sim.p1.flow
	sim.set_input(DuelTypes.Side.P1, false, true, 1)
	sim.tick()
	assert_eq(sim.p1.state, DuelTypes.State.GUARD)

	sim.set_input(DuelTypes.Side.P1, false, false, 0)
	sim.tick()
	sim.tick()
	sim.tick()
	assert_eq(sim.p1.state, DuelTypes.State.IDLE, "松手后 2f 收势")
	assert_eq(sim.p1.flow, flow_before, "主动收架不扣心流")


## 按住架：架子保持到「单次架上限」，不会因为没再按边沿就掉。
func test_held_guard_keeps_stance() -> void:
	sim.set_input(DuelTypes.Side.P1, false, true, 1)
	sim.tick()
	for _i in range(10):
		sim.set_input(DuelTypes.Side.P1, false, false, 1)
		sim.tick()
	assert_eq(sim.p1.state, DuelTypes.State.GUARD, "按住时架子保持")
	assert_eq(sim.p1.guard_blocked, false)


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
	assert_eq(sim.p2.hp, 20)

	_tick_n(26)
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.GUARD)
	_tick_n(14)
	assert_eq(sim.p2.flow, 25)


func test_passive_flow_while_opponent_commits() -> void:
	var teaching := DuelSim.new(FighterData.for_character(&"char_a"),
			FighterData.opponent_teaching(), 7)
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
	assert_eq(sim.p1.hp, 30)
	assert_eq(sim.p2.hp, 30)
	assert_eq(sim.p1.flow, 40)
	assert_eq(sim.p1.state, DuelTypes.State.IDLE)
	assert_eq(sim.p1.repeat_streak, 0)
	assert_false(sim.p1.riposte)


## 回归：按住防御键是「持续意图」，礼让期就按着也要能在礼让结束后架起来。
## 原实现只认「按下」那一帧，礼让期内输入被丢，之后一直按着就永远架不上。
func test_holding_guard_through_opening_lock_enters_guard() -> void:
	sim.opening_lock_frames = 30
	var entered := -1
	for _i in range(40):
		sim.set_input(DuelTypes.Side.P1, false, false, 1)
		sim.tick()
		if entered < 0 and sim.p1.state == DuelTypes.State.GUARD:
			entered = sim.frame
	assert_eq(entered, 30, "礼让期一结束就应自动起架")


## 回归：出刀后全程按住防，收招进 IDLE 的那一帧应自动起架。
func test_holding_guard_after_attack_enters_guard() -> void:
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	sim.tick()
	assert_eq(sim.p1.state, DuelTypes.State.COMMIT, "先确认出刀已进入构")
	var entered := -1
	for _i in range(80):
		sim.set_input(DuelTypes.Side.P1, false, false, 1)
		sim.tick()
		if entered < 0 and sim.p1.state == DuelTypes.State.GUARD:
			entered = sim.frame
	assert_gt(entered, 0, "收招结束后按住防应自动起架")


## 回归：架满上限收势后仍按着，应自动再起架（空架照常扣心流，不是无限白嫖）。
func test_holding_guard_reenters_after_expiry() -> void:
	var flow_before: int = sim.p1.flow
	sim.set_input(DuelTypes.Side.P1, false, true, 1)
	sim.tick()
	var entries := 0
	var last_state := -1
	for _i in range(120):
		sim.set_input(DuelTypes.Side.P1, false, false, 1)
		sim.tick()
		if sim.p1.state == DuelTypes.State.GUARD and last_state != DuelTypes.State.GUARD:
			entries += 1
		last_state = sim.p1.state
	assert_gt(entries, 1, "按住不放，架满收势后应自动再起架")
	assert_lt(sim.p1.flow, flow_before, "空架仍要扣心流，不能变成无限架")
