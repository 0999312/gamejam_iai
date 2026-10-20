class_name FighterData
extends Resource

## 一位剑客的全部帧数据与心流参数。
## 原型期由静态工厂提供默认值；后续可保存为 .tres 做调参资源。

@export var id: StringName = &"player_a"
@export var max_hp: int = 3

@export_group("Attack")
## 「构」前摇基准帧；心流档位会在此基础上 +2 / 0 / -2。
## 2026-10-19 调参：13 → 18f（300ms），让对手有反应/架招的余地，攻击本身成为大破绽。
@export var base_commit: int = 18
## 斩判定窗帧数；双方同时进入判定窗用于判刃鸣。
@export var slash_frames: int = 5
## 取消出刀进「架」的窗口（构的前 N 帧）。
@export var cancel_window: int = 5
## 取消进架消耗的心流。
@export var cancel_cost: int = 5

@export_group("Recovery")
## 2026-10-19 调参：空挥 14 → 20f，被架 25 → 32f；主动出刀失败必须可被确定惩罚。
@export var whiff_recovery: int = 20
@export var blocked_recovery: int = 32
@export var hitstun: int = 24
@export var invuln: int = 12

@export_group("Guard")
@export var guard_startup: int = 2
@export var guard_duration_base: int = 12
@export var guard_recovery: int = 8

@export_group("Clash")
@export var clash_frames: int = 12

@export_group("Flow")
@export var start_flow: int = 40
@export var max_flow: int = 100
@export var flow_floor: int = 15
@export var input_buffer: int = 4
## 主动出刀（进入「构」）消耗的心流：攻击本身是资源与风险的双重支出。
@export var slash_cost: int = 4
## 心流自然恢复：IDLE 时每 N 帧 +M；新一场由 reset_for_duel 重置。
@export var flow_regen_interval: int = 24
@export var flow_regen_amount: int = 1


static func player_a() -> FighterData:
	var data := FighterData.new()
	data.id = &"player_a"
	data.max_hp = 3
	data.base_commit = 18
	data.slash_frames = 5
	data.cancel_window = 5
	data.cancel_cost = 5
	data.whiff_recovery = 20
	data.blocked_recovery = 32
	data.hitstun = 24
	data.invuln = 12
	data.guard_startup = 2
	data.guard_duration_base = 12
	data.guard_recovery = 8
	data.clash_frames = 12
	data.start_flow = 40
	data.max_flow = 100
	data.flow_floor = 15
	data.input_buffer = 4
	data.slash_cost = 4
	data.flow_regen_interval = 24
	data.flow_regen_amount = 1
	return data


## 角色 B「快剑」：前摇短、判定窄、收招快，容错低但抢一瞬更强。
static func player_b() -> FighterData:
	var data := player_a()
	data.id = &"player_b"
	data.max_hp = 3
	data.base_commit = 16
	data.slash_frames = 4
	data.whiff_recovery = 18
	data.blocked_recovery = 28
	data.guard_startup = 1
	data.guard_duration_base = 11
	data.guard_recovery = 7
	data.start_flow = 46
	data.slash_cost = 4
	data.flow_regen_interval = 22
	return data


## 角色 C「重剑」：前摇长、判定宽、血厚、收招慢，靠读招与一次决胜。
static func player_c() -> FighterData:
	var data := player_a()
	data.id = &"player_c"
	data.max_hp = 4
	data.base_commit = 21
	data.slash_frames = 6
	data.whiff_recovery = 24
	data.blocked_recovery = 36
	data.guard_startup = 3
	data.guard_duration_base = 14
	data.guard_recovery = 9
	data.start_flow = 36
	data.slash_cost = 5
	data.flow_regen_interval = 26
	return data


static func for_character(character_id: StringName) -> FighterData:
	match character_id:
		&"char_b":
			return player_b()
		&"char_c":
			return player_c()
		_:
			return player_a()


static func opponent_teaching() -> FighterData:
	var data := player_a()
	data.id = &"opponent_1_teaching"
	data.max_hp = 3
	data.base_commit = 20
	return data


## 五场阶梯的对手数据（内部代号 1–5；正式名称/立绘由人类后补）。
static func opponent_for_stage(stage: int) -> FighterData:
	var data := player_a()
	match stage:
		0:
			data.id = &"opponent_1_teaching"
			data.max_hp = 3
			data.base_commit = 20
		1:
			data.id = &"opponent_2_aggressive"
			data.max_hp = 3
			data.base_commit = 14
		2:
			data.id = &"opponent_3_veteran"
			data.max_hp = 4
			data.base_commit = 15
		3:
			data.id = &"opponent_4_deceptive"
			data.max_hp = 4
			data.base_commit = 13
		_:
			data.id = &"opponent_5_boss"
			data.max_hp = 4
			data.base_commit = 12
	return data
