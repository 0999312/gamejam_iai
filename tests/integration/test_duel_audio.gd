extends GutTest

## 环境音契约：风声退役，雨声作为常亮循环铺底。


func test_rain_ambient_is_a_looped_wav() -> void:
	var audio := DuelAudio.new()
	add_child_autofree(audio)
	await wait_process_frames(1)

	var stream := audio.get("_rain") as AudioStreamWAV
	assert_not_null(stream, "DuelAudio 必须加载雨声 WAV")
	assert_eq(DuelAudio.RAIN_AMBIENT.resource_path, "res://assets/audio/amb/rain_calm_loop.wav")
	assert_false(stream == DuelAudio.RAIN_AMBIENT, "运行时必须复制一份，不能改到 preload 缓存")
	assert_eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD)
	assert_eq(stream.loop_begin, 0)
	assert_almost_eq(stream.get_length(), 30.0, 0.02)
	assert_eq(stream.loop_end, int(round(stream.get_length() * float(stream.mix_rate))))


func test_start_ambient_uses_the_rain_stream() -> void:
	var audio := DuelAudio.new()
	add_child_autofree(audio)
	await wait_process_frames(1)

	audio.start_ambient()
	var player := audio.get("_rain_player") as AudioStreamPlayer
	assert_not_null(player, "start_ambient 必须在 SoundManager 池里拿到播放器")
	assert_same(player.stream, audio.get("_rain"))
	assert_almost_eq(player.volume_db, DuelAudio.RAIN_VOLUME_DB, 0.01)
	audio.stop_ambient(true)
