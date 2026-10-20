class_name RunState
extends RefCounted

## 局内 5 场阶梯：HP 跨场、金币、连战残心、三选一心得。
## 纯逻辑，不依赖场景；表现层只读公开字段。

enum Phase { DUEL, REWARD, FAILED, CLEAR }

const STAGE_COUNT := 5
const ZANSHIN_CAP := 3
const ZANSHIN_FLOW_BONUS := 8

const UPGRADE_IDS: Array[StringName] = [
	&"u01", &"u02", &"u03", &"u04", &"u05",
	&"u06", &"u07", &"u08", &"u09", &"u10",
]

const UPGRADE_REGISTRY := "upgrade"
const UPGRADE_NAMESPACE := "iai"

var seed_value: int = 0
var rng: RandomNumberGenerator
var meta: MetaSave
var character_id: StringName = &"char_a"
var hard_mode: bool = false

var stage_index: int = 0
var player_hp: int = 3
var max_hp: int = 3
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
	var data := FighterData.opponent_for_stage(stage_index)
	if hard_mode:
		data.max_hp += 1
		data.base_commit = maxi(8, data.base_commit - 1)
	return data


func enemy_profile() -> AiProfile:
	var profile := AiProfile.for_stage(stage_index)
	if hard_mode:
		profile.reaction_frames = maxi(8, profile.reaction_frames - 2)
		profile.aggression = minf(1.0, profile.aggression + 0.10)
		profile.feint_rate = minf(0.9, profile.feint_rate + 0.05)
	return profile


## 把已选心得换算成玩家帧数据（效果由注册表里的 UpgradeData 声明）。
func player_data() -> FighterData:
	var data := FighterData.for_character(character_id)
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


func start_flow() -> int:
	var data := player_data()
	return mini(data.max_flow, data.start_flow + zanshin * ZANSHIN_FLOW_BONUS)


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
	var gain := 10 + player_hp * 2
	if flawless:
		gain += 10
	if is_boss_stage():
		gain += 30
	gold += gain
	last_gold_gain = gain
	last_flawless = flawless

	zanshin = mini(ZANSHIN_CAP, zanshin + 1 + (1 if flawless else 0))
	var heal := 1
	for id in upgrades:
		var upgrade := upgrade_data(id)
		if upgrade != null and upgrade.effect == &"heal_bonus":
			heal = upgrade.amount
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
