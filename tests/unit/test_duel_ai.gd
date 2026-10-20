extends GutTest

## DuelAi 行为测试：只通过公开状态与输入接口验证，不依赖渲染。

var sim: DuelSim
var ai: DuelAi


func before_each() -> void:
	sim = DuelSim.new(FighterData.player_a(), FighterData.opponent_teaching(), 7)
	ai = DuelAi.new(DuelTypes.Side.P2, AiProfile.teaching(), 7)


func test_ai_attacks_within_a_few_seconds() -> void:
	var saw_commit := false
	for i in 240:
		ai.tick(sim)
		sim.tick()
		if sim.p2.state == DuelTypes.State.COMMIT:
			saw_commit = true
	assert_true(saw_commit)


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

	assert_eq(sim.p2.hp, 3)
	assert_eq(sim.p1.flow, 28)


func test_ai_feints_when_configured() -> void:
	var profile := AiProfile.teaching()
	profile.aggression = 1.0
	profile.feint_rate = 1.0
	profile.decision_interval = 1
	profile.guard_chance = 0.0
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
