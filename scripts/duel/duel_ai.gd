class_name DuelAi
extends RefCounted

## 对手 AI：只读取双方状态与帧号，不读取玩家输入。
## 决策频率由 AiProfile 控制；所有动作都通过 DuelSim 的公开输入接口。

var side: int = DuelTypes.Side.P2
var profile: AiProfile
var rng: RandomNumberGenerator

var _next_think_frame: int = 0
var _feint_at_frame: int = -1
var _guard_planned: bool = false
var _guard_will: bool = false
var _phase2: bool = false
var _sim: DuelSim
var _hit_connected: bool = false
var _attack_ready_frame: int = 0


func _init(p_side: int, p_profile: AiProfile, seed_value: int = 0) -> void:
	side = p_side
	profile = p_profile
	rng = RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value


func tick(sim: DuelSim) -> void:
	if not _hit_connected:
		_sim = sim
		sim.hit_landed.connect(_on_hit_landed)
		_hit_connected = true
	if sim.finished:
		return
	if sim.frame < sim.opening_lock_frames:
		return
	if sim.frame < profile.opening_grace_frames:
		return

	var me := sim.get_fighter(side)
	var foe := sim.opponent_of(me)

	# 关底二阶段：HP ≤2 时节奏加快、虚招更多。
	if profile.id == &"boss" and not _phase2 and me.hp <= 2:
		_phase2 = true
		profile.aggression = minf(1.0, profile.aggression + 0.15)
		profile.feint_rate = minf(0.9, profile.feint_rate + 0.15)
		profile.reaction_frames = maxi(6, profile.reaction_frames - 2)
		profile.decision_interval = maxi(8, profile.decision_interval - 2)

	# 「构」中按计划取消（虚招）。
	if me.state == DuelTypes.State.COMMIT:
		if _feint_at_frame >= 0 and sim.frame >= _feint_at_frame:
			sim.cancel_commit(side)
			_feint_at_frame = -1
		return

	# 已排程的架：到点且仍可行动才按下。
	if me.state != DuelTypes.State.IDLE:
		return

	# 对手正在「构」：按反应时间「读」一次，读到后在斩落下前不久才架。
	# 架有 12f 持续，起手 2f：过早按会先收架，正好被 18f 的构惩罚。
	if foe.state == DuelTypes.State.COMMIT:
		var elapsed := sim.frame - foe.state_start_frame
		if not _guard_planned and elapsed >= profile.reaction_frames:
			_guard_planned = true
			_guard_will = rng.randf() < profile.guard_chance
		if _guard_will:
			var remaining := foe.commit_total - elapsed
			if remaining <= me.data.guard_duration_base + me.data.guard_startup - 2:
				sim.press(side, DuelTypes.Action.GUARD)
				_guard_will = false
		return

	_guard_planned = false
	_guard_will = false

	# 惩罚窗口：对手硬直/收架时出刀。
	if foe.state == DuelTypes.State.RECOVERY or foe.state == DuelTypes.State.GUARD_REC:
		if sim.frame >= _next_think_frame and rng.randf() < profile.counter_chance:
			_next_think_frame = sim.frame + profile.decision_interval
			_start_attack(sim)
		return

	if sim.frame < _next_think_frame:
		return
	_next_think_frame = sim.frame + profile.decision_interval

	if foe.state == DuelTypes.State.GUARD:
		return

	var roll := rng.randf()
	if roll < profile.aggression:
		_start_attack(sim)
	elif roll < profile.aggression + 0.15:
		sim.press(side, DuelTypes.Action.GUARD)


func _start_attack(sim: DuelSim) -> void:
	if sim.frame < _attack_ready_frame:
		return
	sim.press(side, DuelTypes.Action.ATTACK)
	if rng.randf() < profile.feint_rate:
		# 只在可取消窗内（0..4f）取消；下一帧起算，取 3–4。
		_feint_at_frame = sim.frame + rng.randi_range(3, 4)


func _on_hit_landed(attacker: int, _defender: int, _damage: int) -> void:
	if attacker != side or _sim == null:
		return
	# 命中后强制「间合」：保留压制力，但不给连续追砍到死的窗口。
	_attack_ready_frame = _sim.frame + profile.post_hit_pause_frames
