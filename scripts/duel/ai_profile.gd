class_name AiProfile
extends Resource

## 对手「剑型」（AI 性格）：只影响决策倾向，不影响判定规则。
##
## 2026-10-21 多角色基础：性格由 `persona_id` 索引，不再由「场次序号」索引。
## 场次 → 角色 → 性格 的映射集中在 `FighterData._stage_enemy_id()` 与 `MatchSetup`，
## 这样「收服来的敌人」只要带同一个 persona_id 就能直接上场当对手，也能交给玩家操作。

@export var id: StringName = &"persona_1_teaching"
## 名称留空走 I18N；此处仅为编辑器内可读性（PLACEHOLDER，不参与显示）。
@export var display_name: String = "PLACEHOLDER_OPPONENT"

@export_group("Offense")
@export_range(0.0, 1.0, 0.01) var aggression: float = 0.35
@export_range(0.0, 1.0, 0.01) var feint_rate: float = 0.05
## 命中后至少隔多少帧才再次出刀，避免「一套连到死」（AI 的间合）。
@export var post_hit_pause_frames: int = 45
## 符卡使用意愿：0 = 本场不用（小兵与中段对手），>0 = 到达关键时刻时以此概率发动。
@export_range(0.0, 1.0, 0.01) var spell_chance: float = 0.0

@export_group("Defense")
## 看到玩家「构」后决定架招的延迟（帧）。
@export var reaction_frames: int = 19
@export var decision_interval: int = 18
@export_range(0.0, 1.0, 0.01) var guard_chance: float = 0.2
## 「确定反」概率：看到玩家进入空挥/被架硬直时立刻出反斩的机会（0 = 不反）。
@export_range(0.0, 1.0, 0.01) var counter_chance: float = 0.45
## 起构安全判断：玩家处于 IDLE（随时能抢刀）时不起构，只在玩家
## GUARD / GUARD_REC / RECOVERY / SPELL 时落构。前摇拉长后必须开，否则 AI 是活靶子。
@export var safe_start: bool = true

@export_group("Match")
## 开场礼让帧：教学对手让玩家有时间读提示，不做任何动作。
@export var opening_grace_frames: int = 0
## 心流高档是否让该角色缩短前摇。AI 关掉——否则 AI 涨到「流」档后玩家物理上反应不了。
@export var flow_speeds_commit: bool = false
## 二阶段触发血线（占最大血量的比例，0 = 无二阶段）。
@export_range(0.0, 1.0, 0.01) var two_phase_at_ratio: float = 0.0

## 难度档位（与 DuelTypes.Difficulty 对应，这里用 int 避免资源层依赖枚举顺序）。
const TIER_NORMAL: int = 0
const TIER_HARD: int = 1

## 各性格的「基准表」（HARD = 历史值；NORMAL 由基准表衍生）。
## aggression / guard_chance / counter_chance / decision_interval / post_hit_pause 见 for_persona。
const _BASE := {
	&"persona_1_teaching": {"agg": 0.30, "feint": 0.03, "react": 15, "decide": 20, "guard": 0.30, "counter": 0.40, "post": 75, "spell": 0.0},
	&"persona_2_aggressive": {"agg": 0.65, "feint": 0.08, "react": 16, "decide": 15, "guard": 0.25, "counter": 0.50, "post": 50, "spell": 0.0},
	&"persona_3_veteran": {"agg": 0.45, "feint": 0.25, "react": 14, "decide": 19, "guard": 0.40, "counter": 0.55, "post": 50, "spell": 0.0},
	&"persona_4_deceptive": {"agg": 0.50, "feint": 0.45, "react": 13, "decide": 17, "guard": 0.40, "counter": 0.50, "post": 50, "spell": 0.0},
	&"persona_5_boss": {"agg": 0.60, "feint": 0.35, "react": 12, "decide": 15, "guard": 0.45, "counter": 0.55, "post": 40, "spell": 0.85},
}

## NORMAL 档对基准表的修正（§2.2「慢刀快心」：刀慢 167ms，但出手不更少）。
const _NORMAL_DECISION_OFFSET: int = -4   ## 决策节拍快 67ms
const _NORMAL_POST_HIT_OFFSET: int = -20  ## AI 间合短 333ms
const _NORMAL_AGGRESSION_SCALE: float = 0.8
const _NORMAL_GUARD_BONUS: float = 0.15


static func teaching() -> AiProfile:
	return for_persona(&"persona_1_teaching", TIER_NORMAL)


## 任意性格 id + 难度档 → 完整性格参数。
static func for_persona(persona_id: StringName, tier: int = TIER_NORMAL) -> AiProfile:
	var base: Dictionary = _BASE.get(persona_id, _BASE[&"persona_1_teaching"])
	var hard := tier == TIER_HARD
	var profile := AiProfile.new()
	profile.id = persona_id if _BASE.has(persona_id) else &"persona_1_teaching"
	profile.display_name = "PH_OPPONENT_%s" % profile.id
	profile.feint_rate = base["feint"]
	profile.reaction_frames = base["react"]
	profile.spell_chance = base["spell"]
	profile.two_phase_at_ratio = 0.5 if persona_id == &"persona_5_boss" else 0.0
	if hard:
		profile.aggression = base["agg"]
		profile.decision_interval = base["decide"]
		profile.post_hit_pause_frames = base["post"]
		profile.guard_chance = base["guard"]
		profile.counter_chance = 1.0
	else:
		profile.aggression = clampf(base["agg"] * _NORMAL_AGGRESSION_SCALE, 0.0, 1.0)
		profile.decision_interval = maxi(6, base["decide"] + _NORMAL_DECISION_OFFSET)
		profile.post_hit_pause_frames = maxi(12, base["post"] + _NORMAL_POST_HIT_OFFSET)
		profile.guard_chance = clampf(base["guard"] + _NORMAL_GUARD_BONUS, 0.0, 0.95)
		# 确定反：默认档也必须「掷中就打」，否则被架住的玩家几乎不付代价。
		profile.counter_chance = 1.0
	return profile


## 场次 → 对手性格（保留旧入口；内部走 FighterData 的场次表）。
static func for_stage(stage: int, tier: int = TIER_NORMAL) -> AiProfile:
	return for_persona(FighterData.for_character(FighterData.stage_enemy_id(stage)).persona_id, tier)
