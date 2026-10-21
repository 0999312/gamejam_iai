extends GutTest

## DuelAi 行为测试：只通过公开状态与输入接口验证，不依赖渲染。
## 自平衡 02 起对手血量 ×10，且 AI 有「起构安全判断」与「确定反」。

var sim: DuelSim
var ai: DuelAi


func before_each() -> void:
	sim = DuelSim.new(FighterData.for_character(&"char_a"),
			FighterData.opponent_teaching(), 7)
	ai = DuelAi.new(DuelTypes.Side.P2, AiProfile.teaching(), 7)


func test_ai_attacks_within_a_few_seconds() -> void:
	var saw_commit := false
	for i in 360:
		ai.tick(sim)
		sim.tick()
		if sim.p2.state == DuelTypes.State.COMMIT:
			saw_commit = true
	assert_true(saw_commit)


func test_ai_waits_before_opening_against_idle_foe() -> void:
	# 起构安全判断：对手站着不动时，AI 的长前摇就是活靶子，
	# 所以先忍一手（IDLE_INITIATIVE_FRAMES），到点再主动开口。
	var profile := AiProfile.teaching()
	profile.aggression = 1.0
	profile.decision_interval = 1
	profile.feint_rate = 0.0
	ai = DuelAi.new(DuelTypes.Side.P2, profile, 7)

	var attacked_early := false
	for i in DuelAi.IDLE_INITIATIVE_FRAMES:
		ai.tick(sim)
		sim.tick()
		if sim.p2.state == DuelTypes.State.COMMIT:
			attacked_early = true
	assert_false(attacked_early, "对手待机未满兜底时长时不该落构")

	var opened := false
	for i in 30:
		ai.tick(sim)
		sim.tick()
		if sim.p2.state == DuelTypes.State.COMMIT:
			opened = true
	assert_true(opened, "兜底到时必须主动出刀，不能变成木桩")


func test_ai_guards_player_commit_when_reaction_is_fast() -> void:
	var profile := AiProfile.teaching()
	profile.aggression = 0.0
	profile.guard_chance = 1.0
	profile.reaction_frames = 0
	ai = DuelAi.new(DuelTypes.Side.P2, profile, 7)

	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	for i in 20:
		ai.tick(sim)
		sim.tick()

	assert_eq(sim.p2.hp, 30)
	assert_eq(sim.p1.flow, 28)


func test_ai_counters_whiffed_guard() -> void:
	# 确定反（路径 A）：对手空架进入 GUARD_REC 时立刻出反斩刀，不等决策节拍。
	var profile := AiProfile.teaching()
	profile.aggression = 0.0
	profile.counter_chance = 1.0
	ai = DuelAi.new(DuelTypes.Side.P2, profile, 7)

	sim.press(DuelTypes.Side.P1, DuelTypes.Action.GUARD)
	for i in 30:
		ai.tick(sim)
		sim.tick()

	assert_eq(sim.p2.state, DuelTypes.State.COMMIT, "空架窗口应被确定反抓住")


func test_ai_feints_when_configured() -> void:
	var profile := AiProfile.teaching()
	profile.aggression = 1.0
	profile.feint_rate = 1.0
	profile.decision_interval = 1
	profile.guard_chance = 0.0
	# 这里测的是虚招本身，先关掉起构安全判断。
	profile.safe_start = false
	ai = DuelAi.new(DuelTypes.Side.P2, profile, 11)

	var saw_commit := false
	var saw_cancel := false
	for i in 60:
		ai.tick(sim)
		sim.tick()
		if sim.p2.state == DuelTypes.State.COMMIT:
			saw_commit = true
		if saw_commit and sim.p2.state == DuelTypes.State.RECOVERY:
			saw_cancel = true
	assert_true(saw_commit)
	assert_true(saw_cancel)


func test_ai_is_inert_after_duel_finished() -> void:
	sim.finished = true
	ai.tick(sim)
	sim.tick()
	assert_eq(sim.frame, 0)


## 回归：修复前 AI 用 `elapsed >= reaction_frames` 判「读招」，
## 「快剑 + 疾势」把前摇压到 14f，而 reaction 是 15/16，AI 永远等不到，
## 一刀不挡 → 无脑连砍。现在按「最晚决定帧」读招，短前摇也必须能架。
func test_ai_can_guard_fourteen_frame_commit() -> void:
	var fast := FighterData.for_character(&"char_b")
	fast.base_commit = 14
	sim = DuelSim.new(fast, FighterData.opponent_teaching(), 7)
	var profile := AiProfile.teaching()
	profile.aggression = 0.0
	profile.guard_chance = 1.0
	profile.reaction_frames = 15
	ai = DuelAi.new(DuelTypes.Side.P2, profile, 7)

	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	for i in 20:
		ai.tick(sim)
		sim.tick()

	assert_eq(sim.p2.hp, 30, "14f 前摇也必须能被读到并架住")
	assert_eq(sim.p1.state, DuelTypes.State.RECOVERY, "出刀被架后进入惩罚硬直")


## 连挨刀会抬高 AI 的防御意愿，但不会超过 0.75 的上限。
func test_guard_chance_rises_after_consecutive_hits() -> void:
	var profile := AiProfile.teaching()
	profile.guard_chance = 0.3
	ai = DuelAi.new(DuelTypes.Side.P2, profile, 7)
	assert_almost_eq(ai._guard_chance_now(), 0.3, 0.001)
	ai._consecutive_hits_taken = 1
	assert_almost_eq(ai._guard_chance_now(), 0.45, 0.001)
	ai._consecutive_hits_taken = 99
	assert_almost_eq(ai._guard_chance_now(), 0.75, 0.001, "上限 0.75")


func test_ai_pauses_after_landing_a_hit() -> void:
	sim.opening_lock_frames = 10
	ai.tick(sim)
	sim.frame = 120
	ai._on_hit_landed(DuelTypes.Side.P2, DuelTypes.Side.P1, 1)
	assert_eq(ai._attack_ready_frame, 120 + ai.profile.post_hit_pause_frames)

	ai._start_attack(sim)
	sim.tick()
	assert_eq(sim.p2.state, DuelTypes.State.IDLE, "命中后的间合内不再出刀")

	sim.frame = ai._attack_ready_frame
	ai._start_attack(sim)
	sim.tick()
	assert_eq(sim.p2.state, DuelTypes.State.COMMIT, "间合结束后恢复出刀")


## AI 架住/完美格挡会涨心流，若吃高档 −6f 就会把 18f 压成 12f（200ms），
## 玩家看见也来不及。对手必须只吃低心流的 +6 惩罚。
func test_ai_commit_ignores_flow_speedup() -> void:
	var foe := FighterData.opponent_for_stage(4)
	assert_false(foe.flow_speeds_commit, "对手数据必须关掉心流加速")
	sim = DuelSim.new(FighterData.for_character(&"char_a"), foe, 7)
	sim.p2.flow = 100
	sim.press(DuelTypes.Side.P2, DuelTypes.Action.ATTACK)
	sim.tick()
	assert_eq(sim.p2.commit_total, foe.base_commit,
			"AI 在高档心流下前摇仍是 base_commit，不会掉到 12f")

	# 玩家侧保留加速：这是心流的主要爽点。
	var me := DuelSim.new(FighterData.for_character(&"char_a"),
			FighterData.opponent_for_stage(0), 7)
	me.p1.flow = 100
	me.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	me.tick()
	assert_eq(me.p1.commit_total,
			FighterData.for_character(&"char_a").base_commit
					+ DuelTypes.COMMIT_TIER_OFFSET[DuelTypes.Tier.FLOW],
			"玩家高档心流仍缩短 6f")


## 回归：AI 被打中/收招时会提前 return，若读招状态只在 IDLE 分支里清零，
## 一次失败的骰子就会粘住整场——AI 再也不架。这正是 02 之前「无脑连砍」的主因。
func test_guard_roll_resets_while_ai_is_busy() -> void:
	var profile := AiProfile.teaching()
	profile.aggression = 0.0
	profile.guard_chance = 0.0
	profile.safe_start = false
	ai = DuelAi.new(DuelTypes.Side.P2, profile, 7)

	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	for i in 3:
		ai.tick(sim)
		sim.tick()
	assert_true(ai._guard_planned, "构中已掷过骰（结果失败）")

	# 越过落刀与收招：AI 处在受击硬直，期间不可能走 IDLE 分支。
	for i in 30:
		ai.tick(sim)
		sim.tick()
	assert_false(ai._guard_planned, "对手离开构后必须重置，否则整场不再架")
