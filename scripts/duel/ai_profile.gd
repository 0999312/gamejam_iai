class_name AiProfile
extends Resource

## 对手「剑型」参数：只影响决策倾向，不影响判定规则。

@export var id: StringName = &"teaching"
@export var display_name: String = "PLACEHOLDER_OPPONENT"
@export_range(0.0, 1.0, 0.01) var aggression: float = 0.35
@export_range(0.0, 1.0, 0.01) var feint_rate: float = 0.05
## 看到玩家「构」后决定架招的延迟（帧）；低于 11 帧才可能架住 13 帧的构。
@export var reaction_frames: int = 19
@export var decision_interval: int = 18
@export_range(0.0, 1.0, 0.01) var guard_chance: float = 0.2
@export_range(0.0, 1.0, 0.01) var counter_chance: float = 0.45
@export_range(0.0, 1.0, 0.01) var wait_bias: float = 0.5
## 开场礼让帧：教学对手让玩家有时间读提示，不做任何动作。
@export var opening_grace_frames: int = 0
## 命中玩家后至少隔多少帧才再次出刀，避免「一套连到死」。
@export var post_hit_pause_frames: int = 45
## 符卡使用意愿：0 = 本场不用（小兵与中段对手），>0 = 到达关键时刻时以此概率发动。
## 只有关底持有符卡（见 FighterData.opponent_for_stage）。
@export_range(0.0, 1.0, 0.01) var spell_chance: float = 0.0


static func teaching() -> AiProfile:
	var profile := AiProfile.new()
	profile.id = &"teaching"
	profile.aggression = 0.30
	profile.feint_rate = 0.03
	profile.reaction_frames = 15
	profile.decision_interval = 20
	profile.guard_chance = 0.30
	profile.counter_chance = 0.40
	profile.wait_bias = 0.55
	profile.post_hit_pause_frames = 75
	return profile


## 五场阶梯的 AI 性格（内部代号见设计 §7.2；数值为初版可调）。
static func for_stage(stage: int) -> AiProfile:
	var profile := AiProfile.new()
	profile.opening_grace_frames = 0
	profile.post_hit_pause_frames = 50
	profile.display_name = "PH_OPPONENT_%d" % (stage + 1)
	match stage:
		0:
			profile.id = &"teaching"
			profile.aggression = 0.30
			profile.feint_rate = 0.03
			profile.reaction_frames = 15
			profile.decision_interval = 20
			profile.guard_chance = 0.30
			profile.counter_chance = 0.40
			profile.post_hit_pause_frames = 75
		1:
			profile.id = &"aggressive"
			profile.aggression = 0.65
			profile.feint_rate = 0.08
			profile.reaction_frames = 16
			profile.decision_interval = 15
			profile.guard_chance = 0.25
			profile.counter_chance = 0.50
		2:
			profile.id = &"veteran"
			profile.aggression = 0.45
			profile.feint_rate = 0.25
			profile.reaction_frames = 14
			profile.decision_interval = 19
			profile.guard_chance = 0.40
			profile.counter_chance = 0.55
		3:
			profile.id = &"deceptive"
			profile.aggression = 0.50
			profile.feint_rate = 0.45
			profile.reaction_frames = 13
			profile.decision_interval = 17
			profile.guard_chance = 0.40
			profile.counter_chance = 0.50
		_:
			profile.id = &"boss"
			profile.aggression = 0.60
			profile.feint_rate = 0.35
			profile.reaction_frames = 12
			profile.decision_interval = 15
			profile.guard_chance = 0.45
			profile.counter_chance = 0.55
			profile.post_hit_pause_frames = 40
			profile.spell_chance = 0.85
	return profile
