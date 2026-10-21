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
signal spell_cast(side: int, effect: int)
signal spell_failed(side: int)
## 符卡蓄力被一刀驱散：抢刀打断是关底符卡的唯一正解。
signal spell_interrupted(side: int)
## 「构」进入落刀前 SLASH_WARN_FRAMES 帧的确认信号，只给表现层用。
signal slash_imminent(side: int)

## 单刀伤害改由 FighterData.hit_damage 决定（重剑 2 / 其余 1）。
const HIT_FLOW_LOSS := 15
const BLOCK_FLOW_GAIN := 7
const PERFECT_BLOCK_FLOW_GAIN := 12
const PERFECT_BLOCK_WINDOW := 3
const PERFECT_STREAK_BONUS := 3
const PERFECT_STREAK_BONUS_CAP := 9
const BLOCKED_FLOW_LOSS := 8
const WHIFF_GUARD_FLOW_LOSS := 8
const GUARD_COST := 5
## 架住之后的「反击预备」窗口：从格挡成功那一帧起算，30f = 500ms。
## 覆盖人类的反应时间（约 250ms）+ 输入，同时不会让整个收架过程都能反打。
const GUARD_COUNTER_WINDOW := 30
## 顺势斩：架住之后的下一刀前摇修正（负数 = 更快）。
## 刀刚挡住对方的刀，不需要重新起手；这是「防御转攻」能成立的关键。
const GUARD_COUNTER_COMMIT_BONUS := -6
## 主动收架（松手）的收势帧数：2f = 33ms。架子跑满上限的收势仍走 guard_recovery。
const RELEASE_GUARD_RECOVERY := 2
const FEINT_SEEN_GAIN := 10
const CLASH_FLOW_GAINS := [6, 4, 2, 0]
const COMMIT_WAIT_INTERVAL := 20
const COMMIT_WAIT_CAP := 15
const NO_INPUT_GRACE := 180
const NO_INPUT_PENALTY_INTERVAL := 20
const WHIFF_LOCK_FRAMES := 120
## 「构」的下限帧数：心流 + 疾势叠加后不允许短到无法被读到。
const COMMIT_MIN_FRAMES := 8
## 「崩山」类符卡命中时追加的硬直。
const SPELL_CRUSH_STAGGER := 12
## 「架势」符卡有效期内，架窗至少这么长（保证必完美判定有余量）。
const SPELL_STANCE_GUARD_FRAMES := 30
## 符卡蓄力被打断时追加的惩罚硬直：一次符卡白给，必须疼。
const SPELL_INTERRUPT_PENALTY := 12

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
var _pending_spell: Array = [false, false]
## 架是否仍被按住：-1 = 未提供（AI/脚本单次 press，架子跑满上限），
## 0 = 已松手（主动收架），1 = 按住（架子保持到上限）。
var _guard_held: Array[int] = [-1, -1]


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
	_pending_spell = [false, false]
	_guard_held = [-1, -1]
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
## guard_held：-1 = 未提供（AI/脚本），0 = 已松手，1 = 按住。
## 松手会立刻收架（短硬直、不扣心流），按住则架子保持到「单次架上限」。
func set_input(side: int, attack_pressed: bool, guard_pressed: bool,
		guard_held: int = -1) -> void:
	var fighter := get_fighter(side)
	if guard_held >= 0:
		_guard_held[side] = guard_held
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
	if action == DuelTypes.Action.SPELL:
		set_spell(side)
		return
	set_input(side, action == DuelTypes.Action.ATTACK, action == DuelTypes.Action.GUARD)


## 按下符卡键；真正的判定在下一帧 tick 内消费（与斩/架同帧排序一致）。
## 没有输入缓冲：按下时若不在 IDLE，下一帧直接判失败（HUD 闪红），不会排队稍后自动放。
func set_spell(side: int) -> void:
	if finished or frame < opening_lock_frames:
		return
	_pending_spell[side] = true


func tick() -> void:
	if finished:
		return

	frame += 1
	p1.entered_slash = false
	p2.entered_slash = false

	_apply_pending_input(p1)
	_apply_pending_input(p2)
	_apply_pending_spell(p1)
	_apply_pending_spell(p2)

	_advance(p1)
	_advance(p2)

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
		"spell_uses": fighter.spell_uses_left,
		"spell_ready": fighter.spell_card != null and fighter.spell_uses_left > 0 \
				and fighter.flow >= fighter.spell_card.flow_cost,
		"spell_charging": _has_spell_charge(fighter),
		"spell_perfect": fighter.spell_perfect_until_frame > frame,
	}


func _apply_pending_input(fighter: FighterState) -> void:
	var action: int = _pending[fighter.side]
	_pending[fighter.side] = DuelTypes.Action.NONE
	if frame < opening_lock_frames:
		return
	if action == DuelTypes.Action.NONE:
		# 按住防御键是「持续意图」，不能只在按下那一帧（上升沿）生效。
		# 原先起架唯一入口是 guard_pressed，于是三种常见操作都架不上：
		# ① 礼让期就按着防（礼让期内输入被丢，之后没有新边沿）；
		# ② 硬直 / 构 / 架中按下并按住（边沿被丢弃，之后一直按着也不会再起架）；
		# ③ 架满上限后仍按着（收架回 IDLE 后无边沿）。
		# 玩家感知就是「敌人出刀时按防没反应」。这里只补 IDLE：
		# 构中取消出刀仍需一次明确的按下，避免「按住防御键就永远出不了刀」。
		if _guard_held[fighter.side] == 1 and fighter.state == DuelTypes.State.IDLE:
			action = DuelTypes.Action.GUARD
	if action != DuelTypes.Action.NONE:
		_apply_action(fighter, action)


func _apply_pending_spell(fighter: FighterState) -> void:
	if not _pending_spell[fighter.side]:
		return
	if frame < opening_lock_frames:
		return
	if fighter.state != DuelTypes.State.IDLE:
		# 没有输入缓冲：不在 IDLE 就当场判失败，不排队。
		_pending_spell[fighter.side] = false
		spell_failed.emit(fighter.side)
		return
	_pending_spell[fighter.side] = false
	if not _cast_spell(fighter):
		spell_failed.emit(fighter.side)


## 真正的符卡发动；返回 false 表示条件不足（心流/次数/没有符卡）。
## 唯一入口是 set_spell / _apply_pending_spell，不存在第二条路径。
func _cast_spell(fighter: FighterState) -> bool:
	var card: SpellCardData = fighter.spell_card
	if card == null or fighter.spell_uses_left <= 0 or fighter.flow < card.flow_cost:
		return false

	fighter.spell_uses_left -= 1
	_sub_flow(fighter, card.flow_cost)
	match card.effect:
		SpellCardData.Effect.GUARD_STANCE:
			fighter.spell_perfect_until_frame = frame + card.amount
			_enter(fighter, DuelTypes.State.SPELL, card.cast_frames)
		SpellCardData.Effect.BLADE_RUSH:
			fighter.spell_power_amount = card.amount
			fighter.spell_unblockable = card.unblockable
			fighter.spell_pending_slash = true
			_enter(fighter, DuelTypes.State.SPELL, card.cast_frames)
		SpellCardData.Effect.CRUSH:
			fighter.spell_power_amount = card.amount
			fighter.spell_stagger_bonus = SPELL_CRUSH_STAGGER
			fighter.spell_unblockable = card.unblockable
			fighter.spell_pending_slash = true
			_enter(fighter, DuelTypes.State.SPELL, card.cast_frames)
	spell_cast.emit(fighter.side, card.effect)
	return true


func _apply_action(fighter: FighterState, action: int) -> void:
	match fighter.state:
		DuelTypes.State.IDLE:
			if action == DuelTypes.Action.GUARD:
				_enter_guard(fighter)
			elif action == DuelTypes.Action.ATTACK:
				if not _try_counter_strike(fighter):
					_enter_commit(fighter)
		DuelTypes.State.COMMIT:
			# 虚招：构的前 cancel_window 帧内按架，取消出刀并进入架（耗心流）。
			# 构中按斩不缓存——没有输入缓冲，错过时机就是错过。
			if action == DuelTypes.Action.GUARD and fighter.state_frame < fighter.data.cancel_window:
				_sub_flow(fighter, fighter.data.cancel_cost)
				_enter_guard(fighter)
		DuelTypes.State.GUARD:
			# 架中转攻：架窗还没结束就按斩，等于放弃剩下的格挡机会强行出刀。
			# 2026-10-21：原先 GUARD 状态直接丢弃输入，导致「防御转攻」根本打不出来。
			if action == DuelTypes.Action.ATTACK:
				if not _try_counter_strike(fighter):
					_guard_to_attack(fighter, true)
		DuelTypes.State.GUARD_REC:
			# 架住之后：反击预备窗口内按斩 = 顺势斩；窗口外按下即作废。
			if action == DuelTypes.Action.ATTACK:
				_try_counter_strike(fighter)
		_:
			pass


## 架住之后的顺势斩：窗口内把按下的斩变成一刀更快的前摇。
func _try_counter_strike(fighter: FighterState) -> bool:
	if fighter.counter_until_frame < 0 or frame > fighter.counter_until_frame:
		return false
	fighter.counter_until_frame = -1
	_guard_to_attack(fighter, false, true)
	return true


## 架 → 斩：取消架子（或架住后的收架），直接进入出刀前摇。
## 代价 = 取消税 + 正常出刀心流。主动收架抢刀仍可吃反斩；架住后的反击不吃，
## 因为「挡住一刀」本身已经换来对手的硬直，再叠反斩会把架变成白送一刀。
func _guard_to_attack(fighter: FighterState, allow_riposte: bool,
		counter_strike: bool = false) -> void:
	_sub_flow(fighter, fighter.data.cancel_cost)
	if counter_strike:
		fighter.pending_commit_bonus = GUARD_COUNTER_COMMIT_BONUS
	_enter_commit(fighter, allow_riposte)


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
			elif fighter.state_frame == fighter.commit_total - DuelTypes.SLASH_WARN_FRAMES:
				slash_imminent.emit(fighter.side)
		DuelTypes.State.SLASH:
			if fighter.state_frame >= fighter.data.slash_frames:
				_enter_recovery(fighter, fighter.data.whiff_recovery)
		DuelTypes.State.GUARD:
			# 松手立刻收架（2f、无惩罚）；按住则架子保持到「单次架上限」。
			if _guard_held[fighter.side] == 0 \
					and fighter.state_frame >= fighter.data.guard_startup:
				_release_guard(fighter)
			elif fighter.state_frame >= fighter.data.guard_startup + fighter.guard_duration:
				_finish_guard(fighter)
		DuelTypes.State.RECOVERY, DuelTypes.State.GUARD_REC, DuelTypes.State.HITSTUN, DuelTypes.State.CLASH:
			if fighter.state_frame >= fighter.state_duration:
				_enter_idle(fighter)
		DuelTypes.State.SPELL:
			if fighter.state_frame >= fighter.state_duration:
				# 斩类符卡：蓄力结束自动落刀，不需要再按一次。
				if fighter.spell_pending_slash:
					fighter.spell_pending_slash = false
					_enter_slash(fighter)
				else:
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


## 开场心得（u09）的生效窗口：礼让结束后的 5 秒。
## 注意不能写成「礼让期内」——礼让期内按键会被 set_input 直接丢弃，心得等于不存在。
const OPENING_COMMIT_WINDOW: int = 300


func _enter_commit(fighter: FighterState, allow_riposte: bool = true) -> void:
	var tier := DuelTypes.tier_for_flow(fighter.flow)
	var tier_offset: int = DuelTypes.COMMIT_TIER_OFFSET[tier]
	if not fighter.data.flow_speeds_commit:
		# 对手只吃低心流的惩罚，不吃高档加速：否则「流」档会把 18f 压到 12f，
		# 玩家看见也来不及，变成纯粹的面板伤害。
		tier_offset = maxi(0, tier_offset)
	var opening_offset: int = 0
	if fighter.side == DuelTypes.Side.P1 \
			and frame < opening_lock_frames + OPENING_COMMIT_WINDOW:
		opening_offset = int(mods.get("opening_commit", 0))
	# 反斩：对手正处在「空挥 / 被架」硬直时可确定惩罚，且不受间合惩罚。
	# 见 docs/dev-example/balance-pass-02-plan.md §1.5 代价 1。
	# 架住之后的「取消收架」不算反斩：刀刚被挡住，得重新起手（否则架住=白送一刀）。
	var ripe := allow_riposte and _is_riposte_window(fighter)
	var riposte_offset: int = 0
	if ripe and fighter.data.riposte_commit_bonus != 0:
		riposte_offset = mini(-1, fighter.data.riposte_commit_bonus)
	# 连斩惩罚（间合）：1000ms 内再次出刀，前摇加长，最多叠 2 次。
	var repeat_offset: int = 0
	if not ripe:
		var gap: int = frame - fighter.last_commit_frame
		if gap <= FighterData.REPEAT_WINDOW_FRAMES:
			fighter.repeat_streak = mini(fighter.repeat_streak + 1, FighterData.REPEAT_STACK_CAP)
		else:
			fighter.repeat_streak = 0
		repeat_offset = fighter.data.repeat_commit_penalty * fighter.repeat_streak
	else:
		fighter.repeat_streak = 0
	fighter.riposte = ripe
	fighter.repeat_penalty_frames = repeat_offset
	# 顺势斩：架住后的一次性加速，进「构」时消费。
	var counter_offset: int = fighter.pending_commit_bonus
	fighter.pending_commit_bonus = 0
	fighter.last_commit_frame = frame
	fighter.commit_total = maxi(COMMIT_MIN_FRAMES,
			fighter.data.base_commit + tier_offset + opening_offset + riposte_offset
					+ repeat_offset + counter_offset)
	# 出刀本身消耗心流；档位按付出前计算，避免同一刀因扣费反而变快。
	_sub_flow(fighter, fighter.data.slash_cost)
	_enter(fighter, DuelTypes.State.COMMIT, fighter.commit_total)


## 对手此刻是否处于「可被反斩」的硬直（空挥恢复 / 被架恢复）。
func _is_riposte_window(fighter: FighterState) -> bool:
	var foe := opponent_of(fighter)
	return foe.state == DuelTypes.State.RECOVERY or foe.state == DuelTypes.State.GUARD_REC


func _enter_slash(fighter: FighterState) -> void:
	_enter(fighter, DuelTypes.State.SLASH, fighter.data.slash_frames)
	fighter.entered_slash = true


func _enter_recovery(fighter: FighterState, duration: int) -> void:
	_enter(fighter, DuelTypes.State.RECOVERY, duration)


func _enter_guard(fighter: FighterState) -> void:
	var tier := DuelTypes.tier_for_flow(fighter.flow)
	# 档位偏移 + 心得/残心叠加（guard_duration_base 已含 U01 与残心加成）。
	fighter.guard_duration = fighter.data.guard_duration_base \
			+ DuelTypes.GUARD_TIER_OFFSET[tier]
	# 架势符卡有效期内架窗不低于 SPELL_STANCE_GUARD_FRAMES，给必完美判定留余量。
	if fighter.spell_perfect_until_frame > frame:
		fighter.guard_duration = maxi(fighter.guard_duration, SPELL_STANCE_GUARD_FRAMES)
	fighter.guard_blocked = false
	_enter(fighter, DuelTypes.State.GUARD, fighter.data.guard_startup + fighter.guard_duration)


func _enter_guard_rec(fighter: FighterState) -> void:
	_enter(fighter, DuelTypes.State.GUARD_REC, fighter.data.guard_recovery)


## 下一次出刀的预计总帧数：与 _enter_commit 同一套公式，但不产生任何副作用。
## HUD 用它显示「下一刀」，避免表现层再抄一份公式而漂移（审计 P1-2）。
func projected_commit_frames(fighter: FighterState) -> int:
	if fighter == null or fighter.data == null:
		return COMMIT_MIN_FRAMES
	var tier := DuelTypes.tier_for_flow(fighter.flow)
	var tier_offset: int = DuelTypes.COMMIT_TIER_OFFSET[tier]
	if not fighter.data.flow_speeds_commit:
		tier_offset = maxi(0, tier_offset)
	var opening_offset: int = 0
	if fighter.side == DuelTypes.Side.P1 \
			and frame < opening_lock_frames + OPENING_COMMIT_WINDOW:
		opening_offset = int(mods.get("opening_commit", 0))
	var ripe := _is_riposte_window(fighter)
	var riposte_offset: int = 0
	if ripe and fighter.data.riposte_commit_bonus != 0:
		riposte_offset = mini(-1, fighter.data.riposte_commit_bonus)
	var repeat_offset: int = 0
	if not ripe:
		var gap: int = frame - fighter.last_commit_frame
		var streak: int = mini(fighter.repeat_streak + 1, FighterData.REPEAT_STACK_CAP) \
				if gap <= FighterData.REPEAT_WINDOW_FRAMES else 0
		repeat_offset = fighter.data.repeat_commit_penalty * streak
	return maxi(COMMIT_MIN_FRAMES,
			fighter.data.base_commit + tier_offset + opening_offset + riposte_offset
					+ repeat_offset + fighter.pending_commit_bonus)


## 下一次架刀的有效帧数：与 _enter_guard 同源，不产生副作用（审计 P1-2）。
func projected_guard_frames(fighter: FighterState) -> int:
	if fighter == null or fighter.data == null:
		return 0
	var tier := DuelTypes.tier_for_flow(fighter.flow)
	var duration: int = fighter.data.guard_duration_base + DuelTypes.GUARD_TIER_OFFSET[tier]
	if fighter.spell_perfect_until_frame > frame:
		duration = maxi(duration, SPELL_STANCE_GUARD_FRAMES)
	return duration


func _finish_guard(fighter: FighterState) -> void:
	if not fighter.guard_blocked:
		if fighter.whiff_lock <= 0:
			_sub_flow(fighter, WHIFF_GUARD_FLOW_LOSS)
		fighter.perfect_streak = 0
		guard_whiffed.emit(fighter.side)
	_enter_guard_rec(fighter)


## 主动收架（松手）：2f 收势、不扣心流、不打断完美连击。
## 这样「点按架」是低成本的试探，只有按满上限才会吃空架惩罚。
func _release_guard(fighter: FighterState) -> void:
	_enter(fighter, DuelTypes.State.GUARD_REC, RELEASE_GUARD_RECOVERY)


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
		DuelTypes.State.IDLE, DuelTypes.State.COMMIT, DuelTypes.State.RECOVERY, DuelTypes.State.GUARD_REC, DuelTypes.State.SPELL:
			_do_hit(attacker, defender)
		DuelTypes.State.GUARD:
			if attacker.spell_unblockable:
				# 符卡「破防」：这一刀无视架，直接结算命中。
				attacker.spell_unblockable = false
				_do_hit(attacker, defender)
			elif defender.state_frame >= defender.data.guard_startup:
				_do_block(attacker, defender)
			else:
				_do_hit(attacker, defender)
		DuelTypes.State.HITSTUN, DuelTypes.State.CLASH, DuelTypes.State.DOWN:
			pass
		_:
			pass


## U07 追击的追加伤害（血量 ×10 后与普攻同量级，否则「伤害 +1」等于没有）。
const PURSUIT_BONUS_DAMAGE: int = 10


func _do_hit(attacker: FighterState, defender: FighterState) -> void:
	# 角色基础伤害（重剑 15 / 均衡 10 / 快剑 7）+ 破势硬直。
	var damage := attacker.data.hit_damage
	var stagger := attacker.data.stagger
	if attacker.spell_power_amount > 0:
		damage = maxi(damage, attacker.spell_power_amount)
		stagger += attacker.spell_stagger_bonus
		attacker.spell_power_amount = 0
		attacker.spell_stagger_bonus = 0
	attacker.spell_unblockable = false

	# U07 追击：第一次命中标记 3 秒窗口；窗口内的下一刀追加伤害（每场 1 次）。
	if attacker.side == DuelTypes.Side.P1 and bool(mods.get("pursuit", false)) and not _pursuit_used:
		if _pursuit_armed_until > 0 and frame <= _pursuit_armed_until:
			damage += PURSUIT_BONUS_DAMAGE
			_pursuit_used = true
			_pursuit_armed_until = 0
		else:
			_pursuit_armed_until = frame + 180

	# U06 见切：受击时心流 ≥50，消耗 30 抵消该次伤害（每场 1 次）。
	if defender.side == DuelTypes.Side.P1 and bool(mods.get("see_through", false)) \
			and not _see_through_used and defender.flow >= 50:
		_see_through_used = true
		_sub_flow(defender, 30)
		defender.perfect_streak = 0
		defender.guard_blocked = false
		_enter(defender, DuelTypes.State.GUARD_REC, defender.data.guard_recovery)
		_enter_recovery(attacker, attacker.data.whiff_recovery)
		damage_negated.emit(defender.side)
		return

	defender.hp -= damage
	defender.perfect_streak = 0
	defender.guard_blocked = false
	defender.whiff_lock = WHIFF_LOCK_FRAMES
	# 一刀把符卡蓄力驱散：蓄力期间被抓到就是白付心流 + 追加惩罚硬直。
	var spell_broken := _has_spell_charge(defender)
	if spell_broken:
		_clear_spell_charge(defender)
		spell_interrupted.emit(defender.side)
	# 残心：抬高心流下限之外，还让这一刀掉的心流变少，高档位才守得住。
	_sub_flow(defender, maxi(0, HIT_FLOW_LOSS - defender.data.flow_loss_reduction))
	if defender.side == DuelTypes.Side.P1 and bool(mods.get("guts", false)):
		_guts_until = frame + 300

	_enter(defender, DuelTypes.State.HITSTUN, defender.data.hitstun + stagger \
			+ (SPELL_INTERRUPT_PENALTY if spell_broken else 0))
	defender.invuln = defender.data.invuln
	_enter_recovery(attacker, attacker.data.whiff_recovery)

	hit_landed.emit(attacker.side, defender.side, damage)


## 是否有「已付心流、还没兑现」的符卡蓄力。
func _has_spell_charge(fighter: FighterState) -> bool:
	return fighter.spell_power_amount > 0 \
			or fighter.spell_stagger_bonus > 0 \
			or fighter.spell_pending_slash \
			or fighter.spell_perfect_until_frame > frame \
			or fighter.spell_unblockable


func _clear_spell_charge(fighter: FighterState) -> void:
	fighter.spell_power_amount = 0
	fighter.spell_stagger_bonus = 0
	fighter.spell_perfect_until_frame = 0
	fighter.spell_pending_slash = false
	fighter.spell_unblockable = false


func _do_block(attacker: FighterState, defender: FighterState) -> void:
	var frames_since_active := defender.state_frame - defender.data.guard_startup
	# 心流档位也放宽「完美格挡」判定窗（+0/+1/+2f），让高心流的回报可感知。
	var perfect_window: int = PERFECT_BLOCK_WINDOW \
			+ DuelTypes.PERFECT_TIER_OFFSET[DuelTypes.tier_for_flow(defender.flow)]
	# 架势符卡有效期内：任意时刻的架都判定为完美格挡。
	var stance_active: bool = defender.spell_perfect_until_frame > frame
	var perfect: bool = stance_active or frames_since_active <= perfect_window

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
	# 反击预备：格挡成功起算 500ms 内按斩 = 顺势斩（前摇 -6f）。
	defender.counter_until_frame = frame + GUARD_COUNTER_WINDOW
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
	# 开场礼让期内既不算「最近有操作」，也不累计惩罚：玩家还没法操作。
	var unlocked := frame >= opening_lock_frames
	# 礼让结束的一帧把「最近操作」时间重置，让无输入惩罚从真正能操作时开始计时。
	if unlocked and fighter.last_input_frame < opening_lock_frames:
		fighter.last_input_frame = opening_lock_frames

	# 自然恢复：仅「待机」且最近有操作时累计，每 24f +1；完全干等会转入下面的惩罚。
	var recently_active := unlocked and frame - fighter.last_input_frame <= NO_INPUT_GRACE
	if fighter.state == DuelTypes.State.IDLE and recently_active:
		fighter.flow_regen_frames += 1
		if fighter.flow_regen_frames >= fighter.data.flow_regen_interval:
			fighter.flow_regen_frames = 0
			_add_flow(fighter, fighter.data.flow_regen_amount)
	else:
		fighter.flow_regen_frames = 0

	# 对手处于「构」时保持不动：每 20f +1，单场上限 +15。
	if unlocked and fighter.state == DuelTypes.State.IDLE and foe.state == DuelTypes.State.COMMIT:
		fighter.commit_wait_frames += 1
		if fighter.commit_wait_frames >= COMMIT_WAIT_INTERVAL and fighter.commit_wait_gain < COMMIT_WAIT_CAP:
			fighter.commit_wait_frames -= COMMIT_WAIT_INTERVAL
			fighter.commit_wait_gain += 1
			_add_flow(fighter, 1)
	else:
		fighter.commit_wait_frames = 0

	# 连续 3 秒没有任何输入：每 30f -1（约 -2/秒）。
	if unlocked and fighter.state == DuelTypes.State.IDLE \
			and frame - fighter.last_input_frame > NO_INPUT_GRACE:
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
