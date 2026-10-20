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


func _ready() -> void:
	_wind = load("res://assets/audio/amb/amb_wind_loop.ogg") as AudioStreamOggVorbis
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


func start_ambient() -> void:
	if _wind == null:
		return
	_wind_player = SoundManager.play_ambient_sound(_wind, 0.6)
	if _wind_player == null:
		return
	await get_tree().create_timer(0.7).timeout
	if is_instance_valid(_wind_player):
		_wind_player.volume_db = -14.0


func stop_ambient(immediate: bool = false) -> void:
	if _wind == null:
		return
	if immediate:
		if is_instance_valid(_wind_player):
			_wind_player.stop()
			_wind_player.stream = null
		_wind_player = null
		return
	SoundManager.stop_ambient_sound(_wind, 0.3)


func play_start() -> void:
	SoundManager.play_sound_with_pitch(START, 1.0)


func _on_state_changed(_side: int, _from: int, to: int) -> void:
	if to == DuelTypes.State.SLASH:
		_play(ATTACKS, 0.96, 1.06)
	elif to == DuelTypes.State.COMMIT:
		SoundManager.play_sound_with_pitch(DRAW, randf_range(1.08, 1.16))


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


func _play(options: Array, pitch_min: float, pitch_max: float) -> void:
	if options.is_empty():
		return
	var stream: AudioStream = options[randi() % options.size()]
	SoundManager.play_sound_with_pitch(stream, randf_range(pitch_min, pitch_max))


func _exit_tree() -> void:
	stop_ambient(true)
