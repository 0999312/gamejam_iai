extends SceneTree

## 单局帧日志（调试模拟器用）：打印 AI 状态变化、玩家出刀与血量变化。
## 用法：godot --headless --path . -s tools/sim_trace.gd

const DELAY := 9
const STAGE := 0
const SEED := 2000


func _initialize() -> void:
	var p1 := FighterData.for_character(&"char_a")
	var p2 := FighterData.for_character(FighterData.stage_enemy_id(STAGE))
	var sim := DuelSim.new(p1, p2, SEED)
	var profile := AiProfile.for_persona(p2.persona_id)
	var ai := DuelAi.new(DuelTypes.Side.P2, profile, SEED)
	var pending := -1
	var attack_cd := 0
	var frames := 0
	var prev_me := -1
	var prev_foe := -1
	var prev_p1_hp := sim.p1.hp
	var prev_p2_hp := sim.p2.hp
	while not sim.finished and frames < 900:
		var me := sim.p1
		var foe := sim.p2
		if attack_cd > 0:
			attack_cd -= 1
		if me.state == DuelTypes.State.IDLE and foe.state == DuelTypes.State.COMMIT:
			var remaining := foe.state_duration - foe.state_frame
			if remaining <= DuelTypes.SLASH_WARN_FRAMES and pending < 0:
				pending = DELAY
		if pending >= 0:
			if pending == 0:
				sim.press(DuelTypes.Side.P1, DuelTypes.Action.GUARD)
				pending = -1
			else:
				pending -= 1
		if foe.state != DuelTypes.State.COMMIT and pending >= 0:
			pending = -1
		if me.state == DuelTypes.State.IDLE and attack_cd == 0 \
				and (foe.state == DuelTypes.State.RECOVERY \
					or foe.state == DuelTypes.State.GUARD_REC \
					or foe.state == DuelTypes.State.HITSTUN):
			sim.press(DuelTypes.Side.P1, DuelTypes.Action.ATTACK)
			attack_cd = 15
			print("f%4d  玩家出刀（foe %s 剩 %d）" % [
				frames, DuelTypes.state_name(foe.state), foe.state_duration - foe.state_frame])
		ai.tick(sim)
		sim.tick()
		frames += 1
		if me.state != prev_me:
			print("f%4d  P1 %s → %s" % [frames, DuelTypes.state_name(prev_me), DuelTypes.state_name(me.state)])
			prev_me = me.state
		if foe.state != prev_foe:
			print("f%4d  P2 %s → %s" % [frames, DuelTypes.state_name(prev_foe), DuelTypes.state_name(foe.state)])
			prev_foe = foe.state
		if sim.p1.hp != prev_p1_hp:
			print("f%4d  P1 hp %d → %d" % [frames, prev_p1_hp, sim.p1.hp])
			prev_p1_hp = sim.p1.hp
		if sim.p2.hp != prev_p2_hp:
			print("f%4d  P2 hp %d → %d" % [frames, prev_p2_hp, sim.p2.hp])
			prev_p2_hp = sim.p2.hp
	print("结果：winner=%d  frames=%d  p1.hp=%d  p2.hp=%d" % [sim.winner, frames, sim.p1.hp, sim.p2.hp])
	quit()
