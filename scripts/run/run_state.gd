class_name RunState
extends RefCounted

## 局内 5 场阶梯：HP 跨场、金币、连战残心、三选一心得。
## 纯逻辑，不依赖场景；表现层只读公开字段。

enum Phase { DUEL, REWARD, FAILED, CLEAR }

const STAGE_COUNT := 5
const ZANSHIN_CAP := 3
## 每层残心提供的开局心流。
const ZANSHIN_FLOW_BONUS := 8
## 每层残心抬高的心流下限（3 层 → 15 + 18 = 33，直接脱离最低档）。
const ZANSHIN_FLOOR_BONUS := 6
## 每层残心减免的受击心流损失（3 层 → 15 - 9 = 6）。
const ZANSHIN_LOSS_GUARD := 3

const UPGRADE_IDS: Array[StringName] = [
	&"u01", &"u02", &"u03", &"u04", &"u05",
	&"u06", &"u07", &"u08", &"u09", &"u10",
]

const UPGRADE_REGISTRY := "upgrade"
const UPGRADE_NAMESPACE := "iai"

## HARD 档 = 平衡 02 之前的历史数值（反馈 2：「现在的节奏当作困难模式」）。
## 键为角色 id，因此收服来的角色换上场也照样有困难档。
const HARD_COMMIT := {
	&"opponent_1_teaching": 20, &"opponent_2_aggressive": 18, &"opponent_3_veteran": 19,
	&"opponent_4_deceptive": 18, &"opponent_5_boss": 18,
}
const HARD_GUARD := {&"char_a": 12, &"char_b": 11, &"char_c": 14}
const HARD_GUARD_DEFAULT := 12
const HARD_ENEMY_HP_BONUS := 10

var seed_value: int = 0
var rng: RandomNumberGenerator
var meta: MetaSave
var character_id: StringName = &"char_a"
var hard_mode: bool = false

var stage_index: int = 0
var player_hp: int = 30
var max_hp: int = 30
var gold: int = 0
var zanshin: int = 0
var upgrades: Array[StringName] = []
var offers: Array[StringName] = []
var phase: int = Phase.DUEL

var last_gold_gain: int = 0
var last_flawless: bool = false


func _init(p_seed: int = 0, p_meta: MetaSave = null, p_character: StringName = &"char_a", p_hard: bool = false) -> void:
	seed_value = p_seed
	meta = p_meta if p_meta != null else MetaSave.new()
	character_id = p_character
	hard_mode = p_hard
	rng = RandomNumberGenerator.new()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value
	start_run()


## 新局：金币从局外存档带入，不重置。
func start_run() -> void:
	gold = meta.gold if meta != null else 0
	_reset_progress()


## 失败/通关后重开：只清进度，保留金币。
func restart_run() -> void:
	_reset_progress()


func _reset_progress() -> void:
	stage_index = 0
	upgrades.clear()
	offers.clear()
	var base := player_data()
	max_hp = base.max_hp
	player_hp = max_hp
	if meta != null and meta.has_unlock(&"start_slot"):
		var pool := _all_upgrade_ids()
		if not pool.is_empty():
			upgrades.append(pool[rng.randi_range(0, pool.size() - 1)])
	zanshin = 0
	phase = Phase.DUEL
	last_gold_gain = 0
	last_flawless = false


func stage_count() -> int:
	return STAGE_COUNT


func is_boss_stage() -> bool:
	return stage_index >= STAGE_COUNT - 1


func enemy_data() -> FighterData:
	# 多角色基础：场次只决定「谁上场」，数值全部来自角色本身。
	var data := FighterData.for_character(FighterData.stage_enemy_id(stage_index))
	if hard_mode:
		data.max_hp += HARD_ENEMY_HP_BONUS
		data.base_commit = int(HARD_COMMIT.get(data.id, data.base_commit))
	return data


func enemy_profile() -> AiProfile:
	var data := FighterData.for_character(FighterData.stage_enemy_id(stage_index))
	return AiProfile.for_persona(data.persona_id, difficulty_tier())


## 难度档位（AiProfile.TIER_NORMAL / TIER_HARD）。
func difficulty_tier() -> int:
	return AiProfile.TIER_HARD if hard_mode else AiProfile.TIER_NORMAL


## 本场对局配置：两名角色 + 对手性格。多角色基础：谁都可以当 P1 或 P2。
func build_match() -> MatchSetup:
	return MatchSetup.of(player_data(), enemy_data(), enemy_profile(), stage_index, difficulty_tier())


## 本场的「两名可操作角色」（收服后两者都能被玩家选）。
func stage_cast(stage: int = -1) -> Array[StringName]:
	var index := stage if stage >= 0 else stage_index
	return [character_id, FighterData.stage_enemy_id(index)]


## 当前可操作角色：均衡默认可用，其余靠局外解锁（收服后写入 meta.unlocks）。
func roster() -> Array[StringName]:
	var ids: Array[StringName] = [&"char_a"]
	for id in FighterData.PLAYABLE_IDS:
		if id == &"char_a":
			continue
		if meta != null and meta.has_unlock(id):
			ids.append(id)
	return ids


## 选人入口：只允许 roster 里的角色，避免越权切换到未解锁角色。
func select_character(id: StringName) -> bool:
	if not roster().has(id):
		return false
	character_id = id
	return true


## 把已选心得与残心换算成玩家帧数据（效果由注册表里的 UpgradeData 声明）。
## 残心在这里一次性折算完毕，不存在第二个入口。
func player_data() -> FighterData:
	var data := FighterData.for_character(character_id)
	var zan := mini(zanshin, ZANSHIN_CAP)
	# 残心 = 心流保证：抬高起点与下限、降低受击损失，并给一点架窗。
	data.start_flow = mini(data.max_flow, data.start_flow + zan * ZANSHIN_FLOW_BONUS)
	data.flow_floor += zan * ZANSHIN_FLOOR_BONUS
	data.flow_loss_reduction = zan * ZANSHIN_LOSS_GUARD
	data.guard_duration_base += zan
	if hard_mode:
		# HARD 把玩家的架窗也退回 02 之前（12/11/14f），这是「困难」的一部分。
		data.guard_duration_base = int(HARD_GUARD.get(data.id, HARD_GUARD_DEFAULT)) + zan
	# 反斩是「增强」：所有角色都有，但强度随残心成长（−4 → −10f），对手固定 −10f。
	data.riposte_commit_bonus = -4 - 2 * zan
	for id in upgrades:
		var upgrade := upgrade_data(id)
		if upgrade == null:
			continue
		match upgrade.effect:
			&"guard_duration":
				data.guard_duration_base += upgrade.amount
			&"commit":
				data.base_commit = maxi(1, data.base_commit + upgrade.amount)
			&"start_flow":
				data.start_flow = mini(data.max_flow, data.start_flow + upgrade.amount)
	return data


## 需要 DuelSim 运行时判定的心得。
func mods() -> Dictionary:
	var result := {
		"perfect_gain": 12,
		"see_through": false,
		"pursuit": false,
		"guts": false,
		"opening_commit": 0,
		"hint_lead": 0,
	}
	for id in upgrades:
		var upgrade := upgrade_data(id)
		if upgrade == null:
			continue
		match upgrade.effect:
			&"perfect_gain":
				result["perfect_gain"] = upgrade.amount
			&"see_through":
				result["see_through"] = true
			&"pursuit":
				result["pursuit"] = true
			&"guts":
				result["guts"] = true
			&"opening_commit":
				result["opening_commit"] = upgrade.amount
			&"hint_lead":
				result["hint_lead"] = upgrade.amount
	return result


func has_upgrade(id: StringName) -> bool:
	return upgrades.has(id)


func upgrade_data(id: StringName) -> UpgradeData:
	if not RegistryManager.has_registry(UPGRADE_REGISTRY):
		return null
	var registry := RegistryManager.get_registry(UPGRADE_REGISTRY)
	if registry == null:
		return null
	return registry.get_entry(ResourceLocation.new(UPGRADE_NAMESPACE, String(id))) as UpgradeData


func upgrade_label(id: StringName) -> String:
	var upgrade := upgrade_data(id)
	if upgrade == null or upgrade.name_key.is_empty():
		return I18NManager.get_text("ui.upgrade_unknown")
	return I18NManager.get_text(upgrade.name_key)


func upgrade_desc(id: StringName) -> String:
	var upgrade := upgrade_data(id)
	if upgrade == null or upgrade.desc_key.is_empty():
		return ""
	return I18NManager.get_text(upgrade.desc_key)


## 战斗结束：结算金币/残心/回复，生成三选一或结束本局。
func on_duel_finished(winner: int) -> void:
	if winner != DuelTypes.Side.P1:
		phase = Phase.FAILED
		zanshin = 0
		_record_meta(false)
		return

	var flawless := player_hp == max_hp
	# 经济与血量比例挂钩：满血 16 金，残血 10 金（与 02 之前的 10 + hp×2 等价）。
	var hp_ratio := float(player_hp) / float(maxi(1, max_hp))
	var gain := 10 + roundi(6.0 * hp_ratio)
	if flawless:
		gain += 10
	if is_boss_stage():
		gain += 30
	gold += gain
	last_gold_gain = gain
	last_flawless = flawless

	zanshin = mini(ZANSHIN_CAP, zanshin + 1 + (1 if flawless else 0))
	# 回复也按比例：基础 1/3 血量（30 血 → 10），心得 heal_bonus 翻倍。
	var heal := maxi(1, roundi(float(max_hp) / 3.0))
	for id in upgrades:
		var upgrade := upgrade_data(id)
		if upgrade != null and upgrade.effect == &"heal_bonus":
			heal *= 2
	player_hp = mini(max_hp, player_hp + heal)

	if is_boss_stage():
		phase = Phase.CLEAR
		offers.clear()
		_record_meta(true)
	else:
		offers = _roll_offers()
		phase = Phase.REWARD
		_sync_meta()


## 三选一：0–2；成功则进入下一场。
func apply_offer(index: int) -> bool:
	if phase != Phase.REWARD:
		return false
	if index < 0 or index >= offers.size():
		return false
	upgrades.append(offers[index])
	offers.clear()
	stage_index += 1
	phase = Phase.DUEL
	return true


func _record_meta(cleared: bool) -> void:
	if meta == null:
		return
	meta.record_run(cleared, stage_index + 1)
	_sync_meta()


func _sync_meta() -> void:
	if meta == null:
		return
	meta.gold = gold
	meta.save()


func _all_upgrade_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if RegistryManager.has_registry(UPGRADE_REGISTRY):
		var registry := RegistryManager.get_registry(UPGRADE_REGISTRY)
		if registry != null:
			for key in registry.get_all_keys():
				var key_text := String(key)
				var separator := key_text.find(":")
				if separator >= 0:
					ids.append(StringName(key_text.substr(separator + 1)))
	if ids.is_empty():
		return UPGRADE_IDS.duplicate()
	var ordered: Array[StringName] = []
	for id in UPGRADE_IDS:
		if ids.has(id):
			ordered.append(id)
	for id in ids:
		if not ordered.has(id):
			ordered.append(id)
	return ordered


func _roll_offers() -> Array[StringName]:
	var pool: Array = []
	for id in _all_upgrade_ids():
		if not upgrades.has(id):
			pool.append(id)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: StringName = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var result: Array[StringName] = []
	for i in range(mini(3, pool.size())):
		result.append(pool[i])
	return result
