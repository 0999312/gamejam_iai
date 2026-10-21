class_name DuelAi
extends RefCounted

## 对手 AI：只读取双方状态与帧号，不读取玩家输入。
## 决策频率由 AiProfile 控制；所有动作都通过 DuelSim 的公开输入接口。

## 起构安全判断的兜底：玩家一直待机超过这么久，AI 也必须主动开口（否则变成傻子）。
const IDLE_INITIATIVE_FRAMES: int = 120

var side: int = DuelTypes.Side.P2
var profile: AiProfile
var rng: RandomNumberGenerator

var _next_think_frame: int = 0
var _feint_at_frame: int = -1
var _guard_planned: bool = false
var _guard_will: bool = false
var _phase2: bool = false
## 二阶段加成只存在本 AI 内部，不改外部 AiProfile Resource（审计 P2）。
var _aggression_offset: float = 0.0
var _feint_offset: float = 0.0
var _react_offset: int = 0
var _decide_offset: int = 0
var _sim: DuelSim
var _attack_ready_frame: int = 0
## 本回合连续被命中的次数：AI 会据此提高防御意愿（信息全部公开，不作弊）。
var _consecutive_hits_taken: int = 0
## 符卡每场只有 1 次，用过就不再考虑（不会连点）。
var _spell_spent: bool = false
## 确定反：每个「惩罚窗口」（对手一次硬直）只掷一次骰。
var _counter_window_start: int = -1
var _counter_will: bool = false
## 玩家连续待机的帧数（起构安全判断的兜底计时）。
var _foe_idle_frames: int = 0


func _init(p_side: int, p_profile: AiProfile, seed_value: int = 0) -> void:
	side = p_side
	profile = p_profile
	rng = RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value


func tick(sim: DuelSim) -> void:
	if sim != _sim:
		# 换 sim（重开 / 换场）必须重连信号：旧写法用 _hit_connected 置位后永不重连，
		# 第二次对局 AI 的间合与读招全部失效（审计 P2）。
		_disconnect_sim()
		_sim = sim
		sim.hit_landed.connect(_on_hit_landed)
		sim.attack_blocked.connect(_on_attack_blocked)
		sim.spell_failed.connect(_on_spell_failed)
	if sim.finished:
		return
	if sim.frame < sim.opening_lock_frames:
		return
	if sim.frame < profile.opening_grace_frames:
		return

	var me := sim.get_fighter(side)
	var foe := sim.opponent_of(me)

	if foe.state == DuelTypes.State.IDLE:
		_foe_idle_frames += 1
	else:
		_foe_idle_frames = 0

	# 读招状态必须在「对手离开构」时立刻清零。
	# 2026-10-21 修复：原先只在下面的 IDLE 分支里清零，而 AI 被打中/收招时会提前
	# return，于是一次失败的骰子会粘住整场——AI 再也不架，无脑连砍几乎不付代价。
	if foe.state != DuelTypes.State.COMMIT:
		_guard_planned = false
		_guard_will = false

	# 二阶段（关底）：血量低于比例时节奏加快、虚招更多。
	# 偏移只作用于本实例，不写回共享的 profile 资源。
	var phase_ratio := profile.two_phase_at_ratio
	if phase_ratio > 0.0 and not _phase2 and me.hp <= int(round(me.data.max_hp * phase_ratio)):
		_phase2 = true
		_aggression_offset = 0.15
		_feint_offset = 0.15
		_react_offset = -2
		_decide_offset = -2

	# 「构」中按计划取消（虚招）。
	if me.state == DuelTypes.State.COMMIT:
		if _feint_at_frame >= 0 and sim.frame >= _feint_at_frame:
			sim.cancel_commit(side)
			_feint_at_frame = -1
		return

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
		if not _guard_planned and elapsed >= mini(_reaction_frames(), read_deadline):
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

	# 确定反（路径 A）：对手空挥/被架时立刻出反斩。
	# 2026-10-21：脱离决策节拍、只保留一次性骰——原先「等节拍 + 掷概率」让惩罚刀
	# 经常来不及落下，无脑连砍因此几乎不付代价（见 balance-pass-02-plan §3.2）。
	if foe.state == DuelTypes.State.RECOVERY or foe.state == DuelTypes.State.GUARD_REC:
		_try_counter(sim, foe)
		return

	if sim.frame < _next_think_frame:
		return
	_next_think_frame = sim.frame + _decision_interval()

	# 关底符卡：在最「值得」的一刻发动，而不是随机丢。
	if _try_spell(sim, me, foe):
		return

	if foe.state == DuelTypes.State.GUARD:
		return

	var roll := rng.randf()
	var aggression := _aggression()
	if roll < aggression and _safe_to_commit(foe):
		_start_attack(sim)
	elif roll < aggression + 0.15:
		sim.press(side, DuelTypes.Action.GUARD)


## 确定反：每个硬直窗口掷一次骰；命中后由 sim 自动套用反斩前摇（data.riposte_commit_bonus）。
## 「确定反」概率恒为 1.0 是平衡承诺；性格差异体现在认招迟滞（counter_delay_frames）。
func _try_counter(sim: DuelSim, foe: FighterState) -> void:
	if sim.frame < _attack_ready_frame:
		return
	if _counter_window_start != foe.state_start_frame:
		_counter_window_start = foe.state_start_frame
		_counter_will = profile.counter_chance > 0.0 and rng.randf() < profile.counter_chance
	if not _counter_will:
		return
	if sim.frame - foe.state_start_frame < profile.counter_delay_frames:
		return
	_counter_will = false
	# 直接按攻击：反斩是「接在硬直上的刀」，不排虚招。
	sim.press(side, DuelTypes.Action.ATTACK)
	# 只有真的起构了才消费这次机会：自己还在硬直里时 press 会被丢弃，
	# 保留骰子等下一帧（否则被架/收势窗口里的反斩会永远错过）。
	if sim.get_fighter(side).state != DuelTypes.State.COMMIT:
		_counter_will = true


## 起构安全判断：前摇现在长达 28–30f（467–500ms），落构就是明牌。
## 所以只在「对手来不及抢刀」的窗口出刀：对手硬直里、或对手已经待机酝酿了两秒。
func _safe_to_commit(foe: FighterState) -> bool:
	if not profile.safe_start:
		return true
	match foe.state:
		DuelTypes.State.IDLE:
			# 玩家一直不动（在酝酿）时也该开口，否则 AI 变成木桩；
			# 但绝不落构去和「随时能抢刀」的对手对拼。
			return _foe_idle_frames >= IDLE_INITIATIVE_FRAMES
		DuelTypes.State.COMMIT, DuelTypes.State.SLASH, DuelTypes.State.CLASH:
			# 对攻必输：对手前摇比 AI 短得多，同时出刀死的一定是 AI。
			return false
		DuelTypes.State.GUARD:
			# 打进去会被架住，然后吃 30f 的惩罚硬直。
			return false
		_:
			return true


## 关底符卡：只在「这一招有意义」的时刻发动——能收人头、自己垂死、
## 或对峙超过 15 秒该逼一把。小兵与中段对手没有符卡，profile.spell_chance 为 0。
func _try_spell(sim: DuelSim, me: FighterState, foe: FighterState) -> bool:
	if _spell_spent or profile.spell_chance <= 0.0:
		return false
	var card: SpellCardData = me.spell_card
	if card == null or me.spell_uses_left <= 0 or me.flow < card.flow_cost:
		return false
	var foe_ratio := float(foe.hp) / float(maxi(1, foe.data.max_hp))
	var me_ratio := float(me.hp) / float(maxi(1, me.data.max_hp))
	var worth_it := foe_ratio <= 0.34 or me_ratio <= 0.34 or sim.frame >= 900
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
	if rng.randf() < _feint_rate():
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


func _aggression() -> float:
	return clampf(profile.aggression + _aggression_offset, 0.0, 1.0)


func _feint_rate() -> float:
	return clampf(profile.feint_rate + _feint_offset, 0.0, 0.9)


func _reaction_frames() -> int:
	return maxi(6, profile.reaction_frames + _react_offset)


func _decision_interval() -> int:
	return maxi(8, profile.decision_interval + _decide_offset)


func _disconnect_sim() -> void:
	if _sim == null:
		return
	if _sim.hit_landed.is_connected(_on_hit_landed):
		_sim.hit_landed.disconnect(_on_hit_landed)
	if _sim.attack_blocked.is_connected(_on_attack_blocked):
		_sim.attack_blocked.disconnect(_on_attack_blocked)
	if _sim.spell_failed.is_connected(_on_spell_failed):
		_sim.spell_failed.disconnect(_on_spell_failed)
