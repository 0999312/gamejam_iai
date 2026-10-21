class_name FighterData
extends Resource

## 一位剑客的全部帧数据与心流参数。
## 原型期由静态工厂提供默认值；后续可保存为 .tres 做调参资源。
##
## 2026-10-21 平衡 02：所有数值按「毫秒」重新定档（60Hz，1f ≈ 16.7ms）。
## 血量基准 ×10 → 30/40，单刀伤害改为 10 的整数倍，符卡与追击可以按「个位数」微调。

@export var id: StringName = &"char_a"
## 血量：均衡 30、快剑 30、重剑 40（对手 30/30/40/40/40）。
@export var max_hp: int = 30
## 该角色的 AI 性格 id（空表示「玩家专用」）。多角色基础：性格不再绑场次序号。
@export var persona_id: StringName = &""

@export_group("Attack")
## 「构」前摇基准帧；心流档位会在此基础上 +6 / 0 / -6（进攻端为主）。
## 2026-10-21：对手前摇抬到 28–30f（467–500ms）。可挡区间的上限恒为 (前摇-2f)，
## 300ms 前摇只能挡到 266ms，人类「0.3s 极限」因此物理上防不住——见 balance-pass-02。
@export var base_commit: int = 18
## 心流高档是否允许缩短前摇。玩家保留（这是心流的主要爽点）；
## 对手关掉——AI 架住/完美格挡会涨心流，一旦进「流」档，会被压到更短的开刀前摇，
## 变成玩家物理上无法反应的一刀。由 MatchSetup 从 AiProfile 注入，不写在角色身上。
@export var flow_speeds_commit: bool = true
## 斩判定窗帧数；双方同时进入判定窗用于判刃鸣。
@export var slash_frames: int = 5
## 取消出刀进「架」的窗口（构的前 N 帧）。10f = 167ms，让「看到对手起手再变架」
## 至少有一次按得出来的机会；5f（83ms）低于人类反应下限，等于不存在。
@export var cancel_window: int = 10
## 取消出架消耗的心流。
@export var cancel_cost: int = 10
## 单刀基础伤害（均衡/对手 10，快剑 7，重剑 15）。
@export var hit_damage: int = 10
## 「破势」：命中后额外追加给受击方的硬直帧（重剑 12f = 200ms）。
@export var stagger: int = 0
## 该角色绑定的符卡 id（空表示没有符卡）。
@export var spell_id: StringName = &""

@export_group("Riposte")
## 反斩：对手正处在「空挥硬直 / 被架硬直」时可被确定惩罚。
## 这个值是该情形下的前摇修正（负数 = 更快）。0 表示该角色没有反斩能力。
## 设计前提：刀已经被架住/挥空，攻方不需要再「构」，直接由半途斩出。
@export var riposte_commit_bonus: int = 0

@export_group("Repeat")
## 连斩惩罚（间合）：距上一次出刀不足 REPEAT_WINDOW 帧时再次出刀，本次前摇 + 该值，
## 最多叠加 REPEAT_STACK_CAP 次。反斩不受此惩罚（它本来就是「接在硬直上的刀」）。
@export var repeat_commit_penalty: int = 8

@export_group("Recovery")
@export var whiff_recovery: int = 20
@export var blocked_recovery: int = 32
@export var hitstun: int = 24
@export var invuln: int = 12

@export_group("Guard")
## 心流最低档（SPREAD）下的「架」持续帧数；档位在此基础上加 0 / 4 / 8f，
## 心得 U01 与残心再叠加，因此这里要保留为基准值而不是最终值。
## 2026-10-21：12 → 20f（333ms）。反应的瓶颈是前摇（见 base_commit），架窗修的是
## 「按早了会不会空架」；基准抬到 20f 后，心流跌到 SPREAD 也不会直接变成防不住。
@export var guard_startup: int = 1
@export var guard_duration_base: int = 24
@export var guard_recovery: int = 8
## 架窗按满也没挡到（空架）后的收势帧数。2026-10-21 决策：从 guard_recovery
## （8/7/9f）缩到 1–2f、重剑最多 4f —— 空架仍然扣心流，但不再罚站，
## 让「预判起架」失败后能无感转回，同时保留轻/重剑的切换手感差异。
@export var whiff_guard_recovery: int = 2

@export_group("Clash")
@export var clash_frames: int = 12

@export_group("Flow")
@export var start_flow: int = 40
@export var max_flow: int = 100
@export var flow_floor: int = 15
## 主动出刀（进入「构」）消耗的心流：攻击本身是资源与风险的双重支出。
@export var slash_cost: int = 4
## 心流自然恢复：IDLE 时每 N 帧 +M；新一场由 reset_for_duel 重置。
@export var flow_regen_interval: int = 24
@export var flow_regen_amount: int = 1
## 受击心流损失的减免值（残心提供）。只作用于 HIT_FLOW_LOSS，不减免出刀/架的消耗。
@export var flow_loss_reduction: int = 0

## 连斩惩罚的时间窗与叠加上限（全局常量，不随角色变化）。
const REPEAT_WINDOW_FRAMES: int = 60   ## 1000ms
const REPEAT_STACK_CAP: int = 2

## 玩家可选角色（商店/选人用）。
const PLAYABLE_IDS: Array[StringName] = [&"char_a", &"char_b", &"char_c"]
## 全部角色（含五场对手）：多角色基础——任何人都能当 P1 或 P2。
const ALL_IDS: Array[StringName] = [
	&"char_a", &"char_b", &"char_c",
	&"opponent_1_teaching", &"opponent_2_aggressive", &"opponent_3_veteran",
	&"opponent_4_deceptive", &"opponent_5_boss",
]


static func player_a() -> FighterData:
	var data := FighterData.new()
	data.id = &"char_a"
	data.max_hp = 30
	# 2026-10-21 平衡 04：玩家前摇 18 → 14f（233ms）。
	# 前摇同时是「手感延迟」和「AI 的读招余量」，18f 让主动出刀必然被读死，
	# 玩家体感是「按下去半天不出刀」。缩短后仍高于动作游戏的舒适区（~150ms），
	# 保留「构」的仪式感；对手前摇 28–30f 不受影响（见 opponent_* 的显式覆盖）。
	data.base_commit = 14
	data.slash_frames = 5
	data.cancel_window = 10
	data.cancel_cost = 10
	data.whiff_recovery = 14
	data.blocked_recovery = 28
	data.hitstun = 24
	data.invuln = 12
	data.guard_startup = 1
	data.guard_duration_base = 24
	data.guard_recovery = 8
	data.whiff_guard_recovery = 2
	data.clash_frames = 12
	data.start_flow = 40
	data.max_flow = 100
	data.flow_floor = 15
	data.slash_cost = 4
	data.flow_regen_interval = 24
	data.flow_regen_amount = 1
	data.hit_damage = 10
	data.stagger = 0
	data.spell_id = &"spell_a"
	data.repeat_commit_penalty = 8
	return data


## 快剑：最短前摇（183ms）、最短空挥/被架硬直，用来换单刀 7 伤。
## 2026-10-21：前摇 16 → 15f、架窗 20 → 18f、被架 28 → 24f、空挥 18 → 16f；
## 连斩惩罚 8 → 4（「快」的代价应该是伤害，不该再罚它连斩）。
## 平衡 04：前摇 15 → 11f，取消窗随前摇收到 8f（否则「构→架」几乎覆盖整个前摇）。
static func player_b() -> FighterData:
	var data := player_a()
	data.id = &"char_b"
	data.max_hp = 30
	data.base_commit = 11
	data.cancel_window = 8
	data.slash_frames = 4
	data.whiff_recovery = 12
	data.blocked_recovery = 22
	data.guard_duration_base = 22
	data.guard_recovery = 7
	data.whiff_guard_recovery = 1
	data.start_flow = 46
	data.flow_regen_interval = 22
	data.hit_damage = 7
	data.spell_id = &"spell_b"
	data.repeat_commit_penalty = 4
	return data


## 重剑：最长前摇（283ms）、最长被架硬直，单刀 15 伤 + 12f（200ms）破势。
## 平衡 04：前摇 21 → 17f，仍是三剑里最慢的一把，但不再是「按下后能抽完一口气」。
static func player_c() -> FighterData:
	var data := player_a()
	data.id = &"char_c"
	data.max_hp = 40
	data.base_commit = 17
	data.slash_frames = 6
	data.whiff_recovery = 18
	data.blocked_recovery = 32
	data.guard_startup = 2
	data.guard_duration_base = 26
	data.guard_recovery = 9
	data.whiff_guard_recovery = 4
	data.start_flow = 36
	data.slash_cost = 5
	data.flow_regen_interval = 26
	data.hit_damage = 15
	data.stagger = 12
	data.spell_id = &"spell_c"
	data.repeat_commit_penalty = 10
	return data


## 对手基底：与均衡同帧，但不吃心流加速、带反斩、无符卡。
static func opponent_base() -> FighterData:
	var data := player_a()
	data.flow_speeds_commit = false
	data.spell_id = &""
	data.riposte_commit_bonus = -10
	return data


static func opponent_teaching() -> FighterData:
	return for_character(&"opponent_1_teaching")


## 五场阶梯的对手数据（内部代号 1–5；正式名称/立绘由人类后补）。
## 2026-10-21：前摇 18–20f（300–333ms）→ 28–30f（467–500ms）。
## 依据见 docs/dev-example/balance-pass-02-plan.md §1：可挡上限 = 前摇 − 2f。
static func opponent_for_stage(stage: int) -> FighterData:
	return for_character(stage_enemy_id(stage))


## 场次 → 对手角色 id。多角色基础：这是唯一一处「场次」与「角色」的绑定，
## 之后要做选人/收服时只改这张表，不动判定与数据。
static func stage_enemy_id(stage: int) -> StringName:
	match stage:
		0:
			return &"opponent_1_teaching"
		1:
			return &"opponent_2_aggressive"
		2:
			return &"opponent_3_veteran"
		3:
			return &"opponent_4_deceptive"
		_:
			return &"opponent_5_boss"


## 任意角色 id → 完整数据。八个角色都能当 P1 或 P2（收服/选人的数据底座）。
static func for_character(character_id: StringName) -> FighterData:
	match character_id:
		&"char_b":
			return player_b()
		&"char_c":
			return player_c()
		&"char_a":
			return player_a()
		&"opponent_1_teaching":
			var t := opponent_base()
			t.id = &"opponent_1_teaching"
			t.max_hp = 30
			t.base_commit = 30
			t.persona_id = &"persona_1_teaching"
			return t
		&"opponent_2_aggressive":
			var a := opponent_base()
			a.id = &"opponent_2_aggressive"
			a.max_hp = 30
			a.base_commit = 28
			a.persona_id = &"persona_2_aggressive"
			return a
		&"opponent_3_veteran":
			var v := opponent_base()
			v.id = &"opponent_3_veteran"
			v.max_hp = 40
			v.base_commit = 29
			v.persona_id = &"persona_3_veteran"
			return v
		&"opponent_4_deceptive":
			var d := opponent_base()
			d.id = &"opponent_4_deceptive"
			d.max_hp = 40
			d.base_commit = 28
			d.persona_id = &"persona_4_deceptive"
			return d
		&"opponent_5_boss":
			var b := opponent_base()
			b.id = &"opponent_5_boss"
			b.max_hp = 40
			b.base_commit = 28
			b.spell_id = &"spell_boss"
			b.persona_id = &"persona_5_boss"
			return b
		_:
			return player_a()
