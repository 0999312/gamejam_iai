extends GutTest

## 符卡（技能）与平衡 02：重剑 15 伤 + 破势、心流档位放大、血量 ×10。
## 2026-10-20（v0.20）：符卡统一为「每场一次、收益与风险都大」的规则级技能——
## A 必完美格挡、B/C 蓄力后自动出刀、打断有惩罚硬直、非 IDLE 输入进缓冲。

var sim: DuelSim


func _tick_n(count: int) -> void:
	for i in count:
		sim.tick()


func _make(p1_data: FighterData, p2_data: FighterData, seed_value: int = 5) -> void:
	sim = DuelSim.new(p1_data, p2_data, seed_value)


func test_heavy_sword_deals_fifteen_and_staggers() -> void:
	var light := FighterData.for_character(&"char_a")
	var fast := FighterData.for_character(&"char_b")
	var heavy := FighterData.for_character(&"char_c")
	assert_eq(light.hit_damage, 10, "均衡一剑 10 伤")
	assert_eq(fast.hit_damage, 7, "快剑靠速度吃饭，单发伤害最低")
	assert_eq(heavy.hit_damage, 15, "重剑一剑 15 伤，才配得上更长的前摇")
	assert_eq(heavy.stagger, 12, "破势：受击硬直 24 → 36f")


func test_heavy_sword_leaves_half_hp() -> void:
	_make(FighterData.for_character(&"char_c"), FighterData.for_character(&"char_a"))
	sim.p1.flow = 100
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(20)
	assert_eq(sim.p2.hp, 15, "30 HP 对手被重剑一刀削去一半")


func test_flow_tier_offsets_are_perceptible() -> void:
	assert_eq(DuelTypes.COMMIT_TIER_OFFSET, [6, 0, -6], "进攻端两端差 12f（200ms），可感知")
	assert_eq(DuelTypes.GUARD_TIER_OFFSET, [0, 4, 8], "防守端只差 8f，权重低于进攻")
	assert_eq(DuelTypes.PERFECT_TIER_OFFSET, [0, 1, 2], "完美格挡窗也随档位放宽")
	var attack_swing: int = DuelTypes.COMMIT_TIER_OFFSET[0] - DuelTypes.COMMIT_TIER_OFFSET[2]
	var guard_swing: int = DuelTypes.GUARD_TIER_OFFSET[2] - DuelTypes.GUARD_TIER_OFFSET[0]
	assert_true(attack_swing > guard_swing, "心流对进攻方的影响必须大于防守方")


func test_spell_data_is_bound_to_character() -> void:
	for id in [&"char_a", &"char_b", &"char_c"]:
		var data := FighterData.for_character(id)
		assert_true(data.spell_id != &"", "%s 应绑定符卡" % id)
		var card := SpellCardData.for_character_id(data.spell_id)
		assert_not_null(card, "%s 的符卡数据必须存在" % id)
		assert_eq(card.character_id, id, "符卡与角色硬绑定")


func test_character_can_cast_from_start_flow() -> void:
	# 符卡是本场的底牌，开局就必须用得出来——否则它等于不存在。
	for data in [FighterData.for_character(&"char_a"), FighterData.for_character(&"char_b"),
			FighterData.for_character(&"char_c")]:
		var card := SpellCardData.for_character_id(data.spell_id)
		assert_true(data.start_flow >= card.flow_cost,
				"%s 的起始心流 %d 必须够付符卡 %d" % [data.id, data.start_flow, card.flow_cost])


## A：60f 内所有架都判完美格挡，且架窗抬到 30f。
func test_spell_a_grants_perfect_block_window() -> void:
	_make(FighterData.for_character(&"char_a"), FighterData.for_character(&"char_a"))
	watch_signals(sim)
	sim.p1.flow = 60
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.SPELL)
	sim.tick()
	assert_eq(sim.p1.state, DuelTypes.State.SPELL, "发动时有 10f 硬直")
	assert_signal_emitted(sim, "spell_cast")
	assert_eq(sim.p1.spell_uses_left, 0)
	assert_true(sim.p1.spell_perfect_until_frame > 0, "安全区已开启")

	_tick_n(11)
	assert_eq(sim.p1.state, DuelTypes.State.IDLE)

	sim.press(DuelTypes.Side.P1, DuelTypes.Action.GUARD)
	sim.tick()
	assert_eq(sim.p1.state, DuelTypes.State.GUARD)
	assert_eq(sim.p1.guard_duration, DuelSim.SPELL_STANCE_GUARD_FRAMES,
			"安全区内的架窗固定 30f，不再看档位")

	# 对手从零开始出刀：落刀时仍在安全区内，必须判为完美格挡。
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.ATTACK)
	_tick_n(20)
	assert_signal_emitted_with_parameters(sim, "attack_blocked",
			[DuelTypes.Side.P2, DuelTypes.Side.P1, true])
	assert_eq(sim.p1.perfect_streak, 1, "完美格挡连击成立")


## B：8f 蓄力后自动出刀，穿防 20 伤。蓄力期可被抢刀打断。
func test_spell_b_charges_then_slashes_through_guard() -> void:
	_make(FighterData.for_character(&"char_b"), FighterData.for_character(&"char_a"))
	sim.p1.flow = 80
	_tick_n(3)
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.GUARD)
	sim.tick()
	assert_eq(sim.p2.state, DuelTypes.State.GUARD, "守方已进入有效架窗")

	sim.press(DuelTypes.Side.P1, DuelTypes.Action.SPELL)
	sim.tick()
	assert_eq(sim.p1.state, DuelTypes.State.SPELL, "疾风连斩先蓄力 8f，不再是瞬发")
	assert_true(sim.p1.spell_pending_slash, "蓄满后会自动落刀")

	_tick_n(8)
	assert_eq(sim.p2.hp, 10, "这一刀无视架，20 伤害直接兑现")


## C：20f 长蓄力后自动出刀，30 伤 + 破势。
func test_spell_c_crush_auto_slashes_for_three() -> void:
	_make(FighterData.for_character(&"char_c"), FighterData.for_character(&"char_a"))
	sim.p1.flow = 100
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.SPELL)
	sim.tick()
	assert_eq(sim.p1.spell_power_amount, 30)

	_tick_n(20)
	assert_eq(sim.p2.hp, 0, "崩山：蓄力结束自动落刀，30 伤")
	assert_ne(sim.p1.state, DuelTypes.State.SPELL, "已经出刀，不再停留在蓄力")


func test_spell_requires_enough_flow() -> void:
	_make(FighterData.for_character(&"char_a"), FighterData.for_character(&"char_a"))
	watch_signals(sim)
	sim.p1.flow = 20
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.SPELL)
	sim.tick()
	assert_signal_emitted(sim, "spell_failed")
	assert_eq(sim.p1.state, DuelTypes.State.IDLE)
	assert_eq(sim.p1.spell_uses_left, 1, "心流不足时不消耗次数")


func test_spell_is_once_per_duel() -> void:
	_make(FighterData.for_character(&"char_a"), FighterData.for_character(&"char_a"))
	watch_signals(sim)
	sim.p1.flow = 90
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.SPELL)
	sim.tick()
	_tick_n(11)
	assert_eq(sim.p1.state, DuelTypes.State.IDLE)
	sim.p1.flow = 90
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.SPELL)
	sim.tick()
	assert_signal_emitted(sim, "spell_failed")
	assert_eq(sim.p1.spell_uses_left, 0, "每场只有 1 次")


## 收刀硬直里按下不算「没按」：先缓冲，不要立刻报失败。
func test_spell_input_is_buffered_while_busy() -> void:
	_make(FighterData.for_character(&"char_a"), FighterData.for_character(&"char_a"))
	watch_signals(sim)
	sim.p1.flow = 90
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	_tick_n(19)
	assert_eq(sim.p1.state, DuelTypes.State.RECOVERY)

	sim.press(DuelTypes.Side.P1, DuelTypes.Action.SPELL)
	sim.tick()
	assert_signal_not_emitted(sim, "spell_failed", "缓冲期内不报失败，玩家不会以为按键坏了")

	_tick_n(5)
	assert_signal_emitted(sim, "spell_failed", "缓冲过期才报失败")
	assert_eq(sim.p1.spell_uses_left, 1, "失败不消耗次数")


func test_fighter_without_spell_cannot_cast() -> void:
	_make(FighterData.for_character(&"char_a"), FighterData.opponent_teaching())
	watch_signals(sim)
	sim.p2.flow = 100
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.SPELL)
	sim.tick()
	assert_signal_emitted(sim, "spell_failed")
	assert_null(sim.p2.spell_card, "AI 对手没有符卡")


func test_only_boss_holds_a_spell() -> void:
	for stage in [0, 1, 2, 3]:
		assert_eq(FighterData.opponent_for_stage(stage).spell_id, &"",
				"第 %d 场是常规对手，不带符卡" % (stage + 1))
	var boss := FighterData.opponent_for_stage(4)
	assert_eq(boss.spell_id, &"spell_boss", "关底持有自己的符卡")
	var card := SpellCardData.for_character_id(boss.spell_id)
	assert_not_null(card)
	assert_eq(card.character_id, &"char_boss", "关底符卡与 BOSS 硬绑定")
	assert_eq(card.cast_frames, 14, "14f 是全场最长的可读前摇：正确解是抢刀而不是架")
	assert_true(card.unblockable, "关底符卡穿防")


func test_boss_spell_crushes_through_guard() -> void:
	_make(FighterData.for_character(&"char_a"), FighterData.opponent_for_stage(4))
	sim.p2.flow = 100
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.SPELL)
	sim.tick()
	assert_eq(sim.p2.spell_power_amount, 30)
	assert_true(sim.p2.spell_unblockable)

	# 玩家架住也无效：蓄力 14f 结束后自动落刀，穿防。
	sim.press(DuelTypes.Side.P1, DuelTypes.Action.GUARD)
	_tick_n(15)
	assert_eq(sim.p1.hp, 0, "30 伤穿防，架不住")


func test_boss_ai_casts_spell_when_cornered() -> void:
	_make(FighterData.for_character(&"char_a"), FighterData.opponent_for_stage(4))
	var ai := DuelAi.new(DuelTypes.Side.P2, AiProfile.for_stage(4), 7)
	sim.p2.hp = 1
	sim.p2.flow = 100
	var cast_frame: int = -1
	for i in 240:
		ai.tick(sim)
		if sim.p2.state == DuelTypes.State.SPELL:
			cast_frame = sim.frame
			break
		sim.tick()
	assert_true(cast_frame > 0, "关底在残血时会发动符卡")
	assert_eq(sim.p2.spell_uses_left, 0, "每场 1 次")


## 蓄力被打断：驱散 + 追加惩罚硬直（一次符卡白给，必须疼）。
func test_hit_interrupts_spell_charge_with_penalty() -> void:
	_make(FighterData.for_character(&"char_a"), FighterData.for_character(&"char_a"))
	sim.p1.spell_power_amount = 30
	sim.p1.spell_unblockable = true
	watch_signals(sim)
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.ATTACK)
	_tick_n(22)
	assert_signal_emitted(sim, "spell_interrupted")
	assert_eq(sim.p1.spell_power_amount, 0, "被斩中会驱散蓄力")
	assert_false(sim.p1.spell_unblockable)
	assert_eq(sim.p1.state, DuelTypes.State.HITSTUN)
	assert_eq(sim.p1.state_duration,
			sim.p1.data.hitstun + DuelSim.SPELL_INTERRUPT_PENALTY,
			"打断额外加 12f 惩罚硬直")
