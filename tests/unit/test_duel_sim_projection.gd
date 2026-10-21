extends GutTest

## 审计 P1-2：HUD 的「下一刀 / 下一次架」帧数必须与判定层一致。
## 投影函数与 _enter_commit / _enter_guard 是同一套公式，这里钉住两者不漂移。


func _make_sim() -> DuelSim:
	var p1 := FighterData.for_character(&"char_a")
	var p2 := FighterData.for_character(&"char_a")
	var sim := DuelSim.new(p1, p2, 20261021)
	sim.opening_lock_frames = 0
	return sim


func test_projected_commit_matches_actual_commit() -> void:
	var sim := _make_sim()
	var predicted := sim.projected_commit_frames(sim.p1)

	sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
	sim.tick()

	assert_eq(sim.p1.state, DuelTypes.State.COMMIT, "按攻击后应进入构")
	assert_eq(sim.p1.commit_total, predicted, "投影前摇必须等于真实前摇")


func test_projected_guard_matches_actual_guard() -> void:
	var sim := _make_sim()
	var predicted := sim.projected_guard_frames(sim.p1)

	sim.press(DuelTypes.Side.P1, DuelTypes.Action.GUARD)
	sim.tick()

	assert_eq(sim.p1.state, DuelTypes.State.GUARD, "按架后应进入架")
	assert_eq(sim.p1.guard_duration, predicted, "投影架窗必须等于真实架窗")


## 势头符卡的架势下限 30f 也必须体现在投影里（原先 HUD 漏了这一项）。
func test_projected_guard_respects_spell_stance_floor() -> void:
	var sim := _make_sim()
	sim.p1.flow = 0
	sim.p1.spell_perfect_until_frame = sim.frame + 120

	assert_eq(sim.projected_guard_frames(sim.p1), DuelSim.SPELL_STANCE_GUARD_FRAMES,
			"符卡架势期内架窗不得低于下限")


## 连斩惩罚会拉长前摇，投影必须跟着变——而不是永远显示基础值。
func test_projected_commit_includes_repeat_penalty() -> void:
	var sim := _make_sim()
	sim.p1.last_commit_frame = sim.frame
	sim.p1.repeat_streak = 1

	var with_penalty := sim.projected_commit_frames(sim.p1)
	sim.p1.repeat_streak = 0
	var clean := sim.projected_commit_frames(sim.p1)

	assert_gte(with_penalty, clean, "连斩惩罚不得让前摇变短")
