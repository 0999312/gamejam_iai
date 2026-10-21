extends SceneTree

## 临时平衡模拟器（不进版本控制，跑完可删）。
##
## 目的：把「难度」拆成可测量的两件事——
##   A. 完美信息上限：知道帧数的机器玩家能赢多少（判定逻辑是否自洽）
##   B. 反应延迟曲线：看到刀光后再等 N 帧按架，胜率如何塌陷（人类可玩性）
##
## 策略只做两件事：对手出刀时架、对手收招时砍。不主动进攻，避免把「送反斩」混进来。

const RUNS := 300
const MAX_FRAMES := 60 * 60
const DELAYS: Array[int] = [0, 4, 6, 9, 12, 15]

var _wins: Dictionary = {}
var _frames: Dictionary = {}
var _taken: Dictionary = {}


func _initialize() -> void:
	# 完美信息策略：按 state_frame 精确算「剩余帧」
	for stage in 5:
		var wins := 0
		var frames := 0
		var taken := 0
		for i in RUNS:
			var r := _run_stage(stage, 1000 + i, -1)
			if r["win"]:
				wins += 1
			frames += r["frames"]
			taken += r["damage_taken"]
		_wins[stage] = wins
		_frames[stage] = frames / RUNS
		_taken[stage] = taken / float(RUNS)
		print("perfect stage %d: %5.1f%%  avg %.0ff  dmg %.1f" % [
			stage + 1, 100.0 * float(wins) / float(RUNS), float(frames) / float(RUNS), float(taken) / float(RUNS)])

	# 反应延迟曲线：看到告警后再等 delay 帧才按
	for delay in DELAYS:
		var wins_all := 0
		var total := 0
		var timeouts := 0
		var p1_hits := 0
		var p2_hits := 0
		var blocks := 0
		var guard_entries := 0
		for stage in 5:
			for i in RUNS:
				total += 1
				var r := _run_stage(stage, 2000 + i, delay)
				if r["win"]:
					wins_all += 1
				if r["timeout"]:
					timeouts += 1
				p1_hits += r["p1_hits"]
				p2_hits += r["p2_hits"]
				blocks += r["blocks"]
				guard_entries += r["guard_entries"]
		print("delay %2df (%3dms): win %5.1f%% | timeout %4.1f%% | 我命中 %.1f | 挨打 %.1f | 起架 %.1f" % [
			delay, delay * 1000 / 60, 100.0 * float(wins_all) / float(total),
			100.0 * float(timeouts) / float(total),
			float(p1_hits) / float(total), float(p2_hits) / float(total), float(guard_entries) / float(total)])

	# AI 架刀率对照：把 guard_chance 压到不同值，看「玩家出刀被架」占多少难度
	for guard_override in [0.0, 0.15, 0.30]:
		var wins_g := 0
		var total_g := 0
		var p1_hits_g := 0
		for stage in 5:
			for i in RUNS:
				total_g += 1
				var r := _run_stage(stage, 3000 + i, 9, guard_override)
				if r["win"]:
					wins_g += 1
				p1_hits_g += r["p1_hits"]
		print("guard %.2f (delay 9f): win %5.1f%% | 我命中 %.1f" % [
			guard_override, 100.0 * float(wins_g) / float(total_g), float(p1_hits_g) / float(total_g)])
	quit()


func _run_stage(stage: int, seed_value: int, delay_frames: int, guard_override: float = -1.0) -> Dictionary:
	var p1 := FighterData.for_character(&"char_a")
	var p2 := FighterData.for_character(FighterData.stage_enemy_id(stage))
	var sim := DuelSim.new(p1, p2, seed_value)
	var profile := AiProfile.for_persona(p2.persona_id)
	if guard_override >= 0.0:
		profile.guard_chance = guard_override
	var ai := DuelAi.new(DuelTypes.Side.P2, profile, seed_value)
	var start_hp := sim.p1.hp
	var start_hp2 := sim.p2.hp
	var frames := 0
	var pending := -1
	var attack_cd := 0
	var blocks := 0
	var guard_entries := 0
	var prev_state := -1
	while not sim.finished and frames < MAX_FRAMES:
		var me := sim.p1
		var foe := sim.p2
		if attack_cd > 0:
			attack_cd -= 1
		if (me.state == DuelTypes.State.IDLE or me.state == DuelTypes.State.RECOVERY) \
				and foe.state == DuelTypes.State.COMMIT:
			var remaining := foe.state_duration - foe.state_frame
			if delay_frames < 0:
				# 完美信息：剩余 3~10 帧按，覆盖判定点又不过期
				if remaining >= 3 and remaining <= 10:
					sim.press(DuelTypes.Side.P1, DuelTypes.Action.GUARD)
			else:
				# 人类模型：只有「告警亮起」这一条信息，等 delay 帧再按
				if remaining <= DuelTypes.SLASH_WARN_FRAMES and pending < 0:
					pending = delay_frames
		elif me.state == DuelTypes.State.IDLE \
				and (foe.state == DuelTypes.State.RECOVERY \
					or foe.state == DuelTypes.State.GUARD_REC \
					or foe.state == DuelTypes.State.HITSTUN):
			if attack_cd == 0:
				sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
				attack_cd = 15
		if pending >= 0:
			if pending == 0:
				sim.press(DuelTypes.Side.P1, DuelTypes.Action.GUARD)
				pending = -1
			else:
				pending -= 1
		if pending > 0 and foe.state != DuelTypes.State.COMMIT and delay_frames >= 0:
			pending = -1
		ai.tick(sim)
		sim.tick()
		frames += 1
		if me.state != prev_state:
			if me.state == DuelTypes.State.GUARD:
				guard_entries += 1
			prev_state = me.state
	return {
		"win": sim.winner == DuelTypes.Side.P1,
		"frames": frames,
		"damage_taken": start_hp - sim.p1.hp,
		"timeout": not sim.finished,
		"p1_hits": maxi(0, (start_hp2 - sim.p2.hp) / 10),
		"p2_hits": maxi(0, (start_hp - sim.p1.hp) / 10),
		"blocks": blocks,
		"guard_entries": guard_entries,
	}
