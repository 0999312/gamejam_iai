class_name FighterState
extends RefCounted

## 单侧剑客在对决中的可变状态。
## 只存数据与计时，不含任何表现层节点。

var side: int = 0
var data: FighterData

var state: int = DuelTypes.State.IDLE
var state_start_frame: int = 0
var state_frame: int = 0
var state_duration: int = 0

var hp: int = 3
var flow: int = 40

## 当前「构」的总帧数（含心流档位偏移）。
var commit_total: int = 0
## 当前「架」的有效持续帧数（已含心流档位）。
var guard_duration: int = 12
var guard_blocked: bool = false

var invuln: int = 0
var whiff_lock: int = 0

var buffer_action: int = DuelTypes.Action.NONE
## 输入缓冲的有效截止帧（含）；-1 表示没有缓存。
var buffer_expire_frame: int = -1

var last_input_frame: int = 0

var perfect_streak: int = 0
var clash_count: int = 0

var commit_wait_frames: int = 0
var commit_wait_gain: int = 0

## 连斩惩罚（间合）：上一次进入「构」的帧与连续出刀数。
var last_commit_frame: int = -9999
var repeat_streak: int = 0
## 本次「构」是否走了反斩（对手正处于空挥/被架硬直）。
var riposte: bool = false
## 本次「构」被连斩惩罚加了多少帧（HUD/调试用）。
var repeat_penalty_frames: int = 0
## 架住之后的反击预备：此帧之前按斩可以「顺势斩」（前摇更短）。
## 从格挡成功那一帧起算，覆盖人类的反应时间；-1/0 表示没有预备。
var counter_until_frame: int = -1
## 下一刀的一次性前摇修正（顺势斩用，进「构」时消费）。
var pending_commit_bonus: int = 0

## 心流自然恢复的计时（仅 IDLE 累计）。
var flow_regen_frames: int = 0

## 本帧是否刚进入 SLASH，用于接触结算。
var entered_slash: bool = false

## 符卡（技能）：由 DuelSim.set_spell 消费，与角色硬绑定。
var spell_card: SpellCardData
var spell_uses_left: int = 0
## 「架势」符卡：此帧之前的所有架都判定为完美格挡（0 表示未发动）。
var spell_perfect_until_frame: int = 0
## 「斩」类符卡：下一刀伤害覆盖值（0 表示不生效）。
var spell_power_amount: int = 0
## 下一刀无视「架」（破防）。
var spell_unblockable: bool = false
## 下一刀额外硬直。
var spell_stagger_bonus: int = 0
## 蓄力结束时自动出刀（斩类符卡）。
var spell_pending_slash: bool = false
## 符卡输入的缓冲截止帧；-1 表示没有缓存。
var spell_buffer_expire_frame: int = -1


func reset_for_duel() -> void:
	state = DuelTypes.State.IDLE
	state_start_frame = 0
	state_frame = 0
	state_duration = 0
	hp = data.max_hp
	flow = data.start_flow
	commit_total = 0
	guard_duration = data.guard_duration_base
	guard_blocked = false
	invuln = 0
	whiff_lock = 0
	buffer_action = DuelTypes.Action.NONE
	buffer_expire_frame = -1
	last_input_frame = 0
	perfect_streak = 0
	clash_count = 0
	commit_wait_frames = 0
	commit_wait_gain = 0
	last_commit_frame = -9999
	repeat_streak = 0
	riposte = false
	repeat_penalty_frames = 0
	counter_until_frame = -1
	pending_commit_bonus = 0
	flow_regen_frames = 0
	entered_slash = false
	spell_perfect_until_frame = 0
	spell_power_amount = 0
	spell_unblockable = false
	spell_stagger_bonus = 0
	spell_pending_slash = false
	spell_buffer_expire_frame = -1
	if data != null:
		spell_card = SpellCardData.for_character_id(data.spell_id)
		spell_uses_left = 0 if spell_card == null else spell_card.uses_per_duel
	else:
		spell_card = null
		spell_uses_left = 0
