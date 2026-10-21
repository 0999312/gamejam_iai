class_name DuelAudio
extends Node

## 灰盒战斗音效层：只订阅 DuelSim 信号，不参与判定。
## 素材来自 Kenney CC0（Impact Sounds / RPG Audio）与 OpenGameArt CC0；
## 原始下载与许可见 assets/audio/_sources/SOURCES.md 与 docs/audio-assets-plan.md。

const ATTACKS := [
	preload("res://assets/audio/sfx/sfx_attack_01.ogg"),
	preload("res://assets/audio/sfx/sfx_attack_02.ogg"),
]
const CLASHES := [
	preload("res://assets/audio/sfx/sfx_clash_01.ogg"),
	preload("res://assets/audio/sfx/sfx_clash_02.ogg"),
]
const BLOCKS := [
	preload("res://assets/audio/sfx/sfx_block_01.ogg"),
	preload("res://assets/audio/sfx/sfx_block_02.ogg"),
]
const HITS := [
	preload("res://assets/audio/sfx/sfx_hit_01.ogg"),
	preload("res://assets/audio/sfx/sfx_hit_02.ogg"),
]
const CLOTHS := [
	preload("res://assets/audio/sfx/sfx_cloth_01.ogg"),
	preload("res://assets/audio/sfx/sfx_cloth_02.ogg"),
]
const DRAW := preload("res://assets/audio/sfx/sfx_draw.ogg")
const START := preload("res://assets/audio/sfx/sfx_start.ogg")

var _sim: DuelSim
var _wind: AudioStreamOggVorbis
var _wind_player: AudioStreamPlayer
## 音效随机只用本实例的 RNG，不碰全局 RNG（审计 P3）。
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	var source := load("res://assets/audio/amb/amb_wind_loop.ogg") as AudioStreamOggVorbis
	if source != null:
		# load() 有缓存：直接改 source.loop 会污染所有引用它的地方，先复制一份。
		_wind = source.duplicate() as AudioStreamOggVorbis
		if _wind != null:
			_wind.loop = true


func bind(sim: DuelSim) -> void:
	if _sim != null and is_instance_valid(_sim):
		_disconnect_sim()
	_sim = sim
	if _sim == null:
		return
	_sim.state_changed.connect(_on_state_changed)
	_sim.hit_landed.connect(_on_hit_landed)
	_sim.attack_blocked.connect(_on_attack_blocked)
	_sim.clash_happened.connect(_on_clash_happened)
	_sim.guard_whiffed.connect(_on_guard_whiffed)
	_sim.spell_cast.connect(_on_spell_cast)
	_sim.spell_failed.connect(_on_spell_failed)
	_sim.spell_interrupted.connect(_on_spell_interrupted)
	_sim.slash_imminent.connect(_on_slash_imminent)
	# headless（GUT/CI）没有真实音频设备，OGG loop 播放会在退出时残留 playback；
	# 只在有窗口的运行时启动环境音。
	if DisplayServer.get_name() != "headless":
		start_ambient()


func _disconnect_sim() -> void:
	if _sim.state_changed.is_connected(_on_state_changed):
		_sim.state_changed.disconnect(_on_state_changed)
	if _sim.hit_landed.is_connected(_on_hit_landed):
		_sim.hit_landed.disconnect(_on_hit_landed)
	if _sim.attack_blocked.is_connected(_on_attack_blocked):
		_sim.attack_blocked.disconnect(_on_attack_blocked)
	if _sim.clash_happened.is_connected(_on_clash_happened):
		_sim.clash_happened.disconnect(_on_clash_happened)
	if _sim.guard_whiffed.is_connected(_on_guard_whiffed):
		_sim.guard_whiffed.disconnect(_on_guard_whiffed)
	if _sim.spell_cast.is_connected(_on_spell_cast):
		_sim.spell_cast.disconnect(_on_spell_cast)
	if _sim.spell_failed.is_connected(_on_spell_failed):
		_sim.spell_failed.disconnect(_on_spell_failed)
	if _sim.spell_interrupted.is_connected(_on_spell_interrupted):
		_sim.spell_interrupted.disconnect(_on_spell_interrupted)
	if _sim.slash_imminent.is_connected(_on_slash_imminent):
		_sim.slash_imminent.disconnect(_on_slash_imminent)


func start_ambient() -> void:
	if _wind == null:
		return
	# play_ambient_sound 的第二个参数是「淡入时长（秒）」，不是音量。
	# 原先传 0.6 被当成「0.6 秒淡到 0 dB」，开场偏响再突降（审计 P2）。
	_wind_player = SoundManager.play_ambient_sound(_wind, 0.0)
	if _wind_player == null:
		return
	_wind_player.volume_db = -14.0


func stop_ambient(immediate: bool = false) -> void:
	if _wind == null:
		return
	if immediate:
		if is_instance_valid(_wind_player):
			# 只 stop()，不把 stream 置空：这个播放器属于 SoundManager 的池，
			# 置空会让池在回收时对 null 取 resource_path 而报错（审计 P2）。
			_wind_player.stop()
		_wind_player = null
		return
	SoundManager.stop_ambient_sound(_wind, 0.3)


func play_start() -> void:
	SoundManager.play_sound_with_pitch(START, 1.0)


func _on_state_changed(_side: int, _from: int, to: int) -> void:
	if to == DuelTypes.State.SLASH:
		_play(ATTACKS, 0.96, 1.06)
	elif to == DuelTypes.State.COMMIT:
		SoundManager.play_sound_with_pitch(DRAW, _rng.randf_range(1.08, 1.16))


func _on_hit_landed(_attacker: int, _defender: int, _damage: int) -> void:
	_play(HITS, 0.92, 1.0)
	_play(CLOTHS, 0.94, 1.04)


func _on_attack_blocked(_attacker: int, _defender: int, perfect: bool) -> void:
	if perfect:
		_play([CLASHES[0]], 0.9, 0.96)
	else:
		_play(BLOCKS, 0.95, 1.05)


func _on_clash_happened(_a: int, _b: int) -> void:
	_play(CLASHES, 0.94, 1.04)


func _on_guard_whiffed(_side: int) -> void:
	_play(CLOTHS, 0.88, 0.96)


## 符卡发动：用开场音降调 + 高频金属余韵，和普通出刀明显区分开。
func _on_spell_cast(side: int, _effect: int) -> void:
	var pitch := 0.80 if side == DuelTypes.Side.P2 else 0.90
	SoundManager.play_sound_with_pitch(START, pitch)
	_play(CLASHES, 1.28, 1.46)


## 心流不足或次数用尽：一声闷响，不打断战斗节奏。
func _on_spell_failed(_side: int) -> void:
	_play(CLOTHS, 0.70, 0.80)


## 蓄力被一刀驱散：短促的破音。
func _on_spell_interrupted(_side: int) -> void:
	_play(HITS, 0.68, 0.78)


## 落刀预警：把金属撞击升到 1.5 倍音高，做成一声短促的「叮」。
## 与拔刀声（COMMIT 开始）拉开音区，玩家不需要分辨方向。
func _on_slash_imminent(_side: int) -> void:
	_play(BLOCKS, 1.52, 1.66)


## options 的元素必须都是 AudioStream（调用点传的是上面的常量数组）；
## 这里做一次 as 收窄，避免无类型数组把错误类型喂给 SoundManager。
func _play(options: Array, pitch_min: float, pitch_max: float) -> void:
	if options.is_empty():
		return
	var stream: AudioStream = options[_rng.randi() % options.size()] as AudioStream
	if stream == null:
		return
	SoundManager.play_sound_with_pitch(stream, _rng.randf_range(pitch_min, pitch_max))


func _exit_tree() -> void:
	stop_ambient(true)
