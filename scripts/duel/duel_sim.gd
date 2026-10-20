class_name DuelSim
extends RefCounted

## 纯逻辑对决模拟：一次 tick 前进一个 60 Hz 物理帧。
## 不依赖场景树、输入系统或渲染；表现层订阅信号即可。

signal state_changed(side: int, from_state: int, to_state: int)
signal hit_landed(attacker_side: int, defender_side: int, damage: int)
signal attack_blocked(attacker_side: int, defender_side: int, perfect: bool)
signal clash_happened(side_a: int, side_b: int)
signal flow_changed(side: int, old_value: int, new_value: int)
signal guard_whiffed(side: int)
signal feint_seen(observer_side: int)
signal duel_finished(winner_side: int)
signal damage_negated(side: int)

const HIT_DAMAGE := 1
const HIT_FLOW_LOSS := 15
const BLOCK_FLOW_GAIN := 7
const PERFECT_BLOCK_FLOW_GAIN := 12
const PERFECT_BLOCK_WINDOW := 3
const PERFECT_STREAK_BONUS := 3
const PERFECT_STREAK_BONUS_CAP := 9
const BLOCKED_FLOW_LOSS := 8
const WHIFF_GUARD_FLOW_LOSS := 8
const GUARD_COST := 5
const FEINT_SEEN_GAIN := 10
const CLASH_FLOW_GAINS := [6, 4, 2, 0]
const COMMIT_WAIT_INTERVAL := 20
const COMMIT_WAIT_CAP := 15
const NO_INPUT_GRACE := 180
const NO_INPUT_PENALTY_INTERVAL := 20
const WHIFF_LOCK_FRAMES := 120

var p1: FighterState
var p2: FighterState
var rng: RandomNumberGenerator

var frame: int = 0
var finished: bool = false
var winner: int = -1

## 开场「礼」：双方都不可主动攻击/架，避免礼让期偷袭。0 表示不启用（单测）。
var opening_lock_frames: int = 0

## 局内心得提供的修正（由 RunState.mods() 注入；单测可留空）。
var mods: Dictionary = {}
var _see_through_used: bool = false
var _pursuit_used: bool = false
var _pursuit_armed_until: int = 0
var _guts_until: int = 0

var _pending: Array = [DuelTypes.Action.NONE, DuelTypes.Action.NONE]


func _init(p1_data: FighterData = null, p2_data: FighterData = null, seed_value: int = 0) -> void:
	p1 = FighterState.new()
	p1.side = DuelTypes.Side.P1
	p1.data = p1_data if p1_data != null else FighterData.player_a()

	p2 = FighterState.new()
	p2.side = DuelTypes.Side.P2
	p2.data = p2_data if p2_data != null else FighterData.player_a()

	rng = RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value

	reset()


func reset(seed_value: int = 0) -> void:
	frame = 0
	finished = false
	winner = -1
	p1.reset_for_duel()
	p2.reset_for_duel()
	_pending = [DuelTypes.Action.NONE, DuelTypes.Action.NONE]
	_see_through_used = false
	_pursuit_used = false
	_pursuit_armed_until = 0
	_guts_until = 0
	if seed_value != 0:
		rng.seed = seed_value


func get_fighter(side: int) -> FighterState:
	return p1 if side == DuelTypes.Side.P1 else p2


func opponent_of(fighter: FighterState) -> FighterState:
	return p2 if fighter.side == DuelTypes.Side.P1 else p1


## 每帧调用一次；guard 优先于 attack（同帧斩+架时架生效）。
func set_input(side: int, attack_pressed: bool, guard_pressed: bool) -> void:
	var fighter := get_fighter(side)
	if finished or frame < opening_lock_frames or fighter.state == DuelTypes.State.DOWN:
		return
	var action := DuelTypes.Action.NONE
	if guard_pressed:
		action = DuelTypes.Action.GUARD
	elif attack_pressed:
		action = DuelTypes.Action.ATTACK
	if action == DuelTypes.Action.NONE:
		return
	_pending[side] = action
	fighter.last_input_frame = frame


## 测试/脚本用的单动作入口。
func press(side: int, action: int) -> void:
	set_input(side, action == DuelTypes.Action.ATTACK, action == DuelTypes.Action.GUARD)


func tick() -> void:
	if finished:
		return

	frame += 1
	p1.entered_slash = false
	p2.entered_slash = false

	_apply_pending_input(p1)
	_apply_pending_input(p2)

	_advance(p1)
	_advance(p2)

	# 缓冲在状态推进之后消费：恢复结束的第一帧就能接上输入。
	_consume_buffered_input(p1)
	_consume_buffered_input(p2)

	if p1.entered_slash:
		_resolve_slash(p1)
	if p2.entered_slash:
		_resolve_slash(p2)

	_passive_flow(p1)
	_passive_flow(p2)

	_check_end()


## AI 虚招：在「构」中途取消，回 IDLE 前有一段短硬直。
## 若对手此刻保持「不动」，对手获得看破 +10。
func cancel_commit(side: int) -> bool:
	if frame < opening_lock_frames:
		return false
	var fighter := get_fighter(side)
	if fighter.state != DuelTypes.State.COMMIT:
		return false
	var foe := opponent_of(fighter)
	if foe.state == DuelTypes.State.IDLE:
		_add_flow(foe, FEINT_SEEN_GAIN)
		feint_seen.emit(foe.side)
	_enter_recovery(fighter, rng.randi_range(6, 10))
	return true


func get_snapshot() -> Dictionary:
	return {
		"frame": frame,
		"finished": finished,
		"winner": winner,
		"p1": _snapshot(p1),
		"p2": _snapshot(p2),
	}


func _snapshot(fighter: FighterState) -> Dictionary:
	return {
		"side": fighter.side,
		"state": fighter.state,
		"state_name": DuelTypes.state_name(fighter.state),
		"state_frame": fighter.state_frame,
		"hp": fighter.hp,
		"flow": fighter.flow,
		"tier": DuelTypes.tier_for_flow(fighter.flow),
		"buffer": fighter.buffer_action,
		"buffer_expire_frame": fighter.buffer_expire_frame,
	}


func _consume_buffered_input(fighter: FighterState) -> void:
	if frame < opening_lock_frames:
		return
	if fighter.state != DuelTypes.State.IDLE:
		return
	if fighter.buffer_action == DuelTypes.Action.NONE:
		return
	if frame > fighter.buffer_expire_frame:
		fighter.buffer_action = DuelTypes.Action.NONE
		fighter.buffer_expire_frame = -1
		return
	var action := fighter.buffer_action
	fighter.buffer_action = DuelTypes.Action.NONE
	fighter.buffer_expire_frame = -1
	_apply_action(fighter, action)


func _apply_pending_input(fighter: FighterState) -> void:
	var action: int = _pending[fighter.side]
	_pending[fighter.side] = DuelTypes.Action.NONE
	if frame < opening_lock_frames:
		return
	if action != DuelTypes.Action.NONE:
		_apply_action(fighter, action)


func _apply_action(fighter: FighterState, action: int) -> void:
	match fighter.state:
		DuelTypes.State.IDLE:
			if action == DuelTypes.Action.GUARD:
				_enter_guard(fighter)
			elif action == DuelTypes.Action.ATTACK:
				_enter_commit(fighter)
		DuelTypes.State.COMMIT:
			# 虚招：构的前 cancel_window 帧内按架，取消出刀并进入架（耗心流）。
			if action == DuelTypes.Action.GUARD and fighter.state_frame < fighter.data.cancel_window:
				_sub_flow(fighter, fighter.data.cancel_cost)
				_enter_guard(fighter)
		DuelTypes.State.RECOVERY, DuelTypes.State.GUARD_REC, DuelTypes.State.HITSTUN, DuelTypes.State.CLASH:
			_buffer(fighter, action)
		_:
			pass


func _buffer(fighter: FighterState, action: int) -> void:
	fighter.buffer_action = action
	fighter.buffer_expire_frame = frame + fighter.data.input_buffer


func _advance(fighter: FighterState) -> void:
	if fighter.invuln > 0:
		fighter.invuln -= 1
	if fighter.whiff_lock > 0:
		fighter.whiff_lock -= 1

	fighter.state_frame = frame - fighter.state_start_frame

	match fighter.state:
		DuelTypes.State.COMMIT:
			if fighter.state_frame >= fighter.commit_total:
				_enter_slash(fighter)
		DuelTypes.State.SLASH:
			if fighter.state_frame >= fighter.data.slash_frames:
				_enter_recovery(fighter, fighter.data.whiff_recovery)
		DuelTypes.State.GUARD:
			if fighter.state_frame >= fighter.data.guard_startup + fighter.guard_duration:
				_finish_guard(fighter)
		DuelTypes.State.RECOVERY, DuelTypes.State.GUARD_REC, DuelTypes.State.HITSTUN, DuelTypes.State.CLASH:
			if fighter.state_frame >= fighter.state_duration:
				_enter_idle(fighter)
		_:
			pass


func _enter(fighter: FighterState, new_state: int, duration: int) -> void:
	var old_state := fighter.state
	fighter.state = new_state
	fighter.state_start_frame = frame
	fighter.state_frame = 0
	fighter.state_duration = duration
	if old_state != new_state:
		state_changed.emit(fighter.side, old_state, new_state)


func _enter_idle(fighter: FighterState) -> void:
	fighter.guard_blocked = false
	fighter.commit_total = 0
	_enter(fighter, DuelTypes.State.IDLE, 0)


func _enter_commit(fighter: FighterState) -> void:
	var tier := DuelTypes.tier_for_flow(fighter.flow)
	var opening_offset: int = 0
	if fighter.side == DuelTypes.Side.P1 and frame < 180:
		opening_offset = int(mods.get("opening_commit", 0))
	fighter.commit_total = maxi(1, fighter.data.base_commit + DuelTypes.COMMIT_TIER_OFFSET[tier] + opening_offset)
	# 出刀本身消耗心流；档位按付出前计算，避免同一刀因扣费反而变快。
	_sub_flow(fighter, fighter.data.slash_cost)
	_enter(fighter, DuelTypes.State.COMMIT, fighter.commit_total)


func _enter_slash(fighter: FighterState) -> void:
	_enter(fighter, DuelTypes.State.SLASH, fighter.data.slash_frames)
	fighter.entered_slash = true


func _enter_recovery(fighter: FighterState, duration: int) -> void:
	_enter(fighter, DuelTypes.State.RECOVERY, duration)


func _enter_guard(fighter: FighterState) -> void:
	var tier := DuelTypes.tier_for_flow(fighter.flow)
	fighter.guard_duration = DuelTypes.GUARD_TIER_FRAMES[tier]
	fighter.guard_blocked = false
	_enter(fighter, DuelTypes.State.GUARD, fighter.data.guard_startup + fighter.guard_duration)


func _enter_guard_rec(fighter: FighterState) -> void:
	_enter(fighter, DuelTypes.State.GUARD_REC, fighter.data.guard_recovery)


func _finish_guard(fighter: FighterState) -> void:
	if not fighter.guard_blocked:
		if fighter.whiff_lock <= 0:
			_sub_flow(fighter, WHIFF_GUARD_FLOW_LOSS)
		fighter.perfect_streak = 0
		guard_whiffed.emit(fighter.side)
	_enter_guard_rec(fighter)


func _resolve_slash(attacker: FighterState) -> void:
	attacker.entered_slash = false
	if attacker.state != DuelTypes.State.SLASH:
		return

	var defender := opponent_of(attacker)

	# 刃鸣优先：双方都在斩判定窗内，先判弹开。
	if defender.state == DuelTypes.State.SLASH:
		_do_clash(attacker, defender)
		return

	match defender.state:
		DuelTypes.State.IDLE, DuelTypes.State.COMMIT, DuelTypes.State.RECOVERY, DuelTypes.State.GUARD_REC:
			_do_hit(attacker, defender)
		DuelTypes.State.GUARD:
			if defender.state_frame >= defender.data.guard_startup:
				_do_block(attacker, defender)
			else:
				_do_hit(attacker, defender)
		DuelTypes.State.HITSTUN, DuelTypes.State.CLASH, DuelTypes.State.DOWN:
			pass
		_:
			pass


func _do_hit(attacker: FighterState, defender: FighterState) -> void:
	var damage := HIT_DAMAGE

	# U07 追击：第一次命中标记 3 秒窗口；窗口内的下一刀 +1 伤害（每场 1 次）。
	if attacker.side == DuelTypes.Side.P1 and bool(mods.get("pursuit", false)) and not _pursuit_used:
		if _pursuit_armed_until > 0 and frame <= _pursuit_armed_until:
			damage += 1
			_pursuit_used = true
			_pursuit_armed_until = 0
		else:
			_pursuit_armed_until = frame + 180

	# U06 见切：受击时心流 ≥50，消耗 30 抵消该次伤害（每场 1 次）。
	if defender.side == DuelTypes.Side.P1 and bool(mods.get("see_through", false)) \
			and not _see_through_used and defender.flow >= 50:
		_see_through_used = true
		_sub_flow(defender, 30)
		defender.buffer_action = DuelTypes.Action.NONE
		defender.buffer_expire_frame = -1
		defender.perfect_streak = 0
		defender.guard_blocked = false
		_enter(defender, DuelTypes.State.GUARD_REC, defender.data.guard_recovery)
		_enter_recovery(attacker, attacker.data.whiff_recovery)
		damage_negated.emit(defender.side)
		return

	defender.hp -= damage
	defender.buffer_action = DuelTypes.Action.NONE
	defender.buffer_expire_frame = -1
	defender.perfect_streak = 0
	defender.guard_blocked = false
	defender.whiff_lock = WHIFF_LOCK_FRAMES
	_sub_flow(defender, HIT_FLOW_LOSS)
	if defender.side == DuelTypes.Side.P1 and bool(mods.get("guts", false)):
		_guts_until = frame + 300

	_enter(defender, DuelTypes.State.HITSTUN, defender.data.hitstun)
	defender.invuln = defender.data.invuln
	_enter_recovery(attacker, attacker.data.whiff_recovery)

	hit_landed.emit(attacker.side, defender.side, damage)


func _do_block(attacker: FighterState, defender: FighterState) -> void:
	var frames_since_active := defender.state_frame - defender.data.guard_startup
	var perfect := frames_since_active <= PERFECT_BLOCK_WINDOW

	var gain := BLOCK_FLOW_GAIN
	if perfect:
		defender.perfect_streak += 1
		var bonus := mini((defender.perfect_streak - 1) * PERFECT_STREAK_BONUS, PERFECT_STREAK_BONUS_CAP)
		gain = int(mods.get("perfect_gain", PERFECT_BLOCK_FLOW_GAIN)) + bonus
	else:
		defender.perfect_streak = 0

	_add_flow(defender, gain)
	_sub_flow(attacker, BLOCKED_FLOW_LOSS)

	defender.guard_blocked = true
	_enter_guard_rec(defender)
	_enter_recovery(attacker, attacker.data.blocked_recovery)

	attack_blocked.emit(attacker.side, defender.side, perfect)


func _do_clash(a: FighterState, b: FighterState) -> void:
	var gain_a := _clash_gain(a)
	var gain_b := _clash_gain(b)

	_add_flow(a, gain_a)
	_add_flow(b, gain_b)
	a.clash_count += 1
	b.clash_count += 1

	_enter(a, DuelTypes.State.CLASH, a.data.clash_frames)
	_enter(b, DuelTypes.State.CLASH, b.data.clash_frames)

	clash_happened.emit(a.side, b.side)


func _clash_gain(fighter: FighterState) -> int:
	var index := mini(fighter.clash_count, CLASH_FLOW_GAINS.size() - 1)
	return CLASH_FLOW_GAINS[index]


func _passive_flow(fighter: FighterState) -> void:
	var foe := opponent_of(fighter)

	# 自然恢复：仅「待机」且最近有操作时累计，每 24f +1；完全干等会转入下面的惩罚。
	var recently_active := frame - fighter.last_input_frame <= NO_INPUT_GRACE
	if fighter.state == DuelTypes.State.IDLE and recently_active:
		fighter.flow_regen_frames += 1
		if fighter.flow_regen_frames >= fighter.data.flow_regen_interval:
			fighter.flow_regen_frames = 0
			_add_flow(fighter, fighter.data.flow_regen_amount)
	else:
		fighter.flow_regen_frames = 0

	# 对手处于「构」时保持不动：每 20f +1，单场上限 +15。
	if fighter.state == DuelTypes.State.IDLE and foe.state == DuelTypes.State.COMMIT:
		fighter.commit_wait_frames += 1
		if fighter.commit_wait_frames >= COMMIT_WAIT_INTERVAL and fighter.commit_wait_gain < COMMIT_WAIT_CAP:
			fighter.commit_wait_frames -= COMMIT_WAIT_INTERVAL
			fighter.commit_wait_gain += 1
			_add_flow(fighter, 1)
	else:
		fighter.commit_wait_frames = 0

	# 连续 3 秒没有任何输入：每 30f -1（约 -2/秒）。
	if fighter.state == DuelTypes.State.IDLE and frame - fighter.last_input_frame > NO_INPUT_GRACE:
		if (frame - fighter.last_input_frame) % NO_INPUT_PENALTY_INTERVAL == 0:
			_sub_flow(fighter, 1)


func _add_flow(fighter: FighterState, amount: int) -> void:
	var old_value := fighter.flow
	fighter.flow = clampi(fighter.flow + amount, fighter.data.flow_floor, fighter.data.max_flow)
	if fighter.flow != old_value:
		flow_changed.emit(fighter.side, old_value, fighter.flow)


func _sub_flow(fighter: FighterState, amount: int) -> void:
	if fighter.side == DuelTypes.Side.P1 and bool(mods.get("guts", false)) and frame < _guts_until:
		return
	_add_flow(fighter, -amount)


func _check_end() -> void:
	if finished:
		return
	var p1_down := p1.hp <= 0
	var p2_down := p2.hp <= 0
	if not p1_down and not p2_down:
		return

	finished = true
	if p1_down and p2_down:
		winner = -1
	elif p1_down:
		winner = p2.side
	else:
		winner = p1.side

	if p1_down:
		_enter(p1, DuelTypes.State.DOWN, 0)
	if p2_down:
		_enter(p2, DuelTypes.State.DOWN, 0)

	duel_finished.emit(winner)
