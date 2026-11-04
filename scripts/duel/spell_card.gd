class_name SpellCardData
extends Resource

## 符卡（技能）：与角色硬绑定，每场限次数，消耗心流。
## 只声明机制数据；name_key / desc_key 指向 I18N，文案由人类提供
## （缺失时 HUD 会显示 [占位] 前缀，见 DuelHud._tr）。

enum Effect {
	## 瞬发架刀·反斩：按 L 立刻完成防御姿态，窗口内被刀自动完美弹开并反击。
	GUARD_STANCE,
	## 疾风连斩：蓄力后自动出刀，这一刀无视对手的架。
	BLADE_RUSH,
	## 崩山：长蓄力后自动出刀，高伤 + 追加硬直 + 穿防。
	CRUSH,
}

@export var id: StringName = &""
## 绑定角色 id（与 FighterData.spell_id 一致）。
@export var character_id: StringName = &"char_a"
@export var name_key: String = ""
@export var desc_key: String = ""
## 发动消耗的心流。
@export var flow_cost: int = 30
## 发动硬直帧数（期间可被斩中，不无敌）。
@export var cast_frames: int = 8
## 每场可用次数。
@export var uses_per_duel: int = 1
## 效果类型，由 DuelSim._cast_spell 解释。
@export var effect: int = Effect.GUARD_STANCE
## 效果数值：
## GUARD_STANCE = 「必完美格挡」的持续帧；BLADE_RUSH / CRUSH = 本刀伤害。
@export var amount: int = 0
## 这一刀是否无视对手的架（只在 BLADE_RUSH / CRUSH 上有意义）。
@export var unblockable: bool = false
## GUARD_STANCE：自动架刀窗口（帧）。窗口内受刀自动完美弹开，超时未受击返还部分心流。
@export var auto_guard_frames: int = 45
## GUARD_STANCE：自动弹开成功后的反斩伤害。
@export var counter_damage: int = 10
## GUARD_STANCE：窗口超时、一刀未接时返还的心流。
@export var empty_refund_flow: int = 10


## 角色登场时绑定的符卡；未知 id 返回 null（即没有符卡）。
static func for_character_id(spell_id: StringName) -> SpellCardData:
	match spell_id:
		&"spell_a":
			return _guard_stance()
		&"spell_b":
			return _blade_rush()
		&"spell_c":
			return _crush()
		&"spell_boss":
			return _boss()
		_:
			return null


## A「均衡」：瞬发架刀·反斩——按 L 立刻完成防御姿态，45f 内被刀自动完美弹开
## 并立刻反斩（10 伤，穿防）。窗口内自己先出刀则窗口取消、不返还；
## 45f 内一刀未接则返还 10 心流。是一次「读对手出刀」的保险，而不是开无敌。
static func _guard_stance() -> SpellCardData:
	var card := SpellCardData.new()
	card.id = &"spell_a"
	card.character_id = &"char_a"
	card.name_key = "spell.spell_a.name"
	card.desc_key = "spell.spell_a.desc"
	card.flow_cost = 30
	card.cast_frames = 0
	card.uses_per_duel = 1
	card.effect = Effect.GUARD_STANCE
	card.amount = 0
	card.auto_guard_frames = 45
	card.counter_damage = 10
	card.empty_refund_flow = 10
	return card


## B「快剑」：疾风连斩——8f 蓄力后自动出刀，20 伤且无视对手的架。
## 蓄力期可被抢刀打断，打空后仍有 34f 收势。
static func _blade_rush() -> SpellCardData:
	var card := SpellCardData.new()
	card.id = &"spell_b"
	card.character_id = &"char_b"
	card.name_key = "spell.spell_b.name"
	card.desc_key = "spell.spell_b.desc"
	card.flow_cost = 35
	card.cast_frames = 8
	card.uses_per_duel = 1
	card.effect = Effect.BLADE_RUSH
	card.amount = 20
	card.unblockable = true
	return card


## C「重剑」：崩山——20f 长蓄力后自动出刀，30 伤 + 追加硬直 + 穿防。
## 蓄力期是全场最长的明牌破绽，对手有 333ms 抢刀窗口。
static func _crush() -> SpellCardData:
	var card := SpellCardData.new()
	card.id = &"spell_c"
	card.character_id = &"char_c"
	card.name_key = "spell.spell_c.name"
	card.desc_key = "spell.spell_c.desc"
	card.flow_cost = 34
	card.cast_frames = 20
	card.uses_per_duel = 1
	card.effect = Effect.CRUSH
	card.amount = 30
	card.unblockable = true
	return card


## 关底「剑鬼」：崩势斩 + 穿防。蓄力 14f 是全场最长的可读前摇——
## 玩家的正确解是抢刀打断，而不是架（架不住）。
static func _boss() -> SpellCardData:
	var card := SpellCardData.new()
	card.id = &"spell_boss"
	card.character_id = &"char_boss"
	card.name_key = "spell.spell_boss.name"
	card.desc_key = "spell.spell_boss.desc"
	card.flow_cost = 40
	card.cast_frames = 14
	card.uses_per_duel = 1
	card.effect = Effect.CRUSH
	card.amount = 30
	card.unblockable = true
	return card
