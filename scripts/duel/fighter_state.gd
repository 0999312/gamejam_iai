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

## 心流自然恢复的计时（仅 IDLE 累计）。
var flow_regen_frames: int = 0

## 本帧是否刚进入 SLASH，用于接触结算。
var entered_slash: bool = false


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
	flow_regen_frames = 0
	entered_slash = false
