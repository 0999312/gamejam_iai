class_name MatchSetup
extends RefCounted

## 一场对局的完整配置：两名角色（谁都可以是 P1 或 P2）+ 对手的 AI 性格。
##
## 多角色基础（见 docs/dev-example/balance-pass-02-plan.md §4）：
## 判定层只认 `FighterData`，AI 层只认 `AiProfile`，本类负责把两者拼成一场对局。
## 之后要做「收服敌人当可操作角色」时，只需要换 `p1` / `p2` 的来源，不动判定与 AI。

## 场次序号（仅用于表现层与种子；不参与数值）。
var stage: int = 0
## 难度档位（AiProfile.TIER_NORMAL / TIER_HARD）。
var tier: int = AiProfile.TIER_NORMAL
var p1: FighterData
var p2: FighterData
## P2 的性格；P1 由玩家操作，因此没有性格。
var p2_profile: AiProfile


static func of(p1_data: FighterData, p2_data: FighterData, profile: AiProfile,
		p_stage: int = 0, p_tier: int = AiProfile.TIER_NORMAL) -> MatchSetup:
	var setup := MatchSetup.new()
	setup.p1 = p1_data
	setup.p2 = p2_data
	setup.p2_profile = profile
	setup.stage = p_stage
	setup.tier = p_tier
	return setup


func p1_character_id() -> StringName:
	return p1.id if p1 != null else &""


func p2_character_id() -> StringName:
	return p2.id if p2 != null else &""


## 换边：同一场对局里把两个角色对调（收服后「用敌人打敌人」的最小入口）。
func swapped() -> MatchSetup:
	return MatchSetup.of(p2, p1, p2_profile, stage, tier)


func is_hard() -> bool:
	return tier == AiProfile.TIER_HARD
