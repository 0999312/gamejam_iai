extends GutTest

## 心得对 DuelSim 的运行时影响（U03/U06/U07/U08/U09）。
## 平衡 02：血量 ×10，追击追加伤害同步放大到 10。

const OPENING_LOCK := 180


func _make_sim(mods: Dictionary = {}) -> DuelSim:
	var sim := DuelSim.new(FighterData.for_character(&"char_a"),
			FighterData.for_character(&"char_a"), 99)
	sim.mods = mods
	return sim


func _tick_n(sim: DuelSim, count: int) -> void:
	for i in count:
		sim.tick()


func test_u03_perfect_block_grants_18() -> void:
	var sim := _make_sim({"perfect_gain": 18})
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	# 构 14f：第 15 帧落刀；第 12 帧起架（startup 1）→ 生效 2 帧后挡下，算完美。
	_tick_n(sim, 11)
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.GUARD)
	_tick_n(sim, 4)
	assert_eq(sim.p2.flow, 58)
	assert_eq(sim.p2.perfect_streak, 1)


func test_u09_opening_commit_is_faster() -> void:
	# 开场心得只在礼让期（frame < opening_lock_frames）生效。
	var sim := _make_sim({"opening_commit": -3})
	sim.opening_lock_frames = OPENING_LOCK
	_tick_n(sim, OPENING_LOCK)
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	sim.tick()
	assert_eq(sim.p1.state, DuelTypes.State.COMMIT)
	assert_eq(sim.p1.commit_total, FighterData.for_character(&"char_a").base_commit - 3)


func test_u06_see_through_negates_damage() -> void:
	var sim := _make_sim({"see_through": true})
	sim.p1.flow = 60
	watch_signals(sim)
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.ATTACK)
	_tick_n(sim, 19)
	assert_eq(sim.p1.hp, 30)
	assert_eq(sim.p1.flow, 30)
	assert_signal_emitted(sim, "damage_negated")


func test_u07_pursuit_second_hit_deals_ten_more() -> void:
	var sim := _make_sim({"pursuit": true})
	watch_signals(sim)
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(sim, 19)
	assert_eq(sim.p2.hp, 20)

	_tick_n(sim, 21)
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(sim, 40)
	assert_eq(sim.p2.hp, 0, "追击第二刀多 10 伤害")
	assert_signal_emitted(sim, "hit_landed")


func test_u08_guts_blocks_flow_loss_after_hit() -> void:
	var sim := _make_sim({"guts": true})
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.ATTACK)
	_tick_n(sim, 19)
	assert_eq(sim.p1.hp, 20)
	assert_eq(sim.p1.flow, 25)

	_tick_n(sim, 25)
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.GUARD)
	_tick_n(sim, 15)
	assert_eq(sim.p1.flow, 25, "中刀后 5 秒内的心流损失被胆力挡住")
