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
## 本回合连续被命中的次数：AI 会据此提高防御意愿（信息全部公开，不作弊）。
var _consecutive_hits_taken: int = 0
## 符卡每场只有 1 次，用过就不再考虑（不会连点）。
var _spell_spent: bool = false


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
		sim.attack_blocked.connect(_on_attack_blocked)
		sim.spell_failed.connect(_on_spell_failed)
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

	# 对手正在「构」：按反应时间「读」一次，读到后在斩落判定帧前刚好架住。
	# 2026-10-20 修复：原实现要求 elapsed >= reaction_frames，使「快剑 + 疾势」
	# 这类前摇 14f 的构永远读不到（reaction 15/16），AI 一刀不挡 → 无脑连砍。
	# 现在按「最晚决定帧」读招：只要架的有效窗能覆盖判定帧即可，
	# 读招难度仍受 reaction_frames 限制，短前摇被迫更早预读、更容易被虚招骗。
	if foe.state == DuelTypes.State.COMMIT:
		var elapsed := sim.frame - foe.state_start_frame
		var guard_len := me.data.guard_duration_base \
				+ DuelTypes.GUARD_TIER_OFFSET[DuelTypes.tier_for_flow(me.flow)]
		var cover := guard_len + me.data.guard_startup
		var read_deadline := maxi(0, foe.commit_total - cover)
		if not _guard_planned and elapsed >= mini(profile.reaction_frames, read_deadline):
			_guard_planned = true
			_guard_will = rng.randf() < _guard_chance_now()
		if _guard_will:
			var remaining := foe.commit_total - elapsed
			if remaining <= guard_len:
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

	# 关底符卡：在最「值得」的一刻发动，而不是随机丢。
	if _try_spell(sim, me, foe):
		return

	if foe.state == DuelTypes.State.GUARD:
		return

	var roll := rng.randf()
	if roll < profile.aggression:
		_start_attack(sim)
	elif roll < profile.aggression + 0.15:
		sim.press(side, DuelTypes.Action.GUARD)


## 关底符卡：只在「这一招有意义」的时刻发动——能收人头、自己垂死、
## 或对峙超过 15 秒该逼一把。小兵与中段对手没有符卡，profile.spell_chance 为 0。
func _try_spell(sim: DuelSim, me: FighterState, foe: FighterState) -> bool:
	if _spell_spent or profile.spell_chance <= 0.0:
		return false
	var card: SpellCardData = me.spell_card
	if card == null or me.spell_uses_left <= 0 or me.flow < card.flow_cost:
		return false
	var worth_it := foe.hp <= 1 or me.hp <= 1 or sim.frame >= 900
	if not worth_it:
		return false
	if rng.randf() >= profile.spell_chance:
		return false
	_spell_spent = true
	sim.press(side, DuelTypes.Action.SPELL)
	return true


func _start_attack(sim: DuelSim) -> void:
	if sim.frame < _attack_ready_frame:
		return
	sim.press(side, DuelTypes.Action.ATTACK)
	if rng.randf() < profile.feint_rate:
		# 只在可取消窗内（0..4f）取消；下一帧起算，取 3–4。
		_feint_at_frame = sim.frame + rng.randi_range(3, 4)


func _on_hit_landed(attacker: int, defender: int, _damage: int) -> void:
	if _sim == null:
		return
	# 被命中：记录连挨刀数，下次读招更愿意架。
	if defender == side:
		_consecutive_hits_taken += 1
		return
	if attacker != side:
		return
	# 命中后强制「间合」：保留压制力，但不给连续追砍到死的窗口。
	_attack_ready_frame = _sim.frame + profile.post_hit_pause_frames


func _on_attack_blocked(_attacker: int, defender: int, _perfect: bool) -> void:
	if defender == side:
		_consecutive_hits_taken = 0


## 发动失败（例如按下瞬间已不在 IDLE）：把这一次机会还回去，下个决策点再试。
func _on_spell_failed(failed_side: int) -> void:
	if failed_side == side:
		_spell_spent = false


## 连挨刀会抬高 AI 的防御意愿；上限 0.75，保证任何前摇都存在被架住的可能。
func _guard_chance_now() -> float:
	var bias := 0.15 * mini(_consecutive_hits_taken, 3)
	return clampf(profile.guard_chance + bias, 0.0, 0.75)
