extends SceneTree

# MIT. Authored-score integration: routed public PCM, looping, actual mixer, saves.
const Audio = preload("res://scripts/game_audio.gd")
var failures: Array[String] = []

func _initialize() -> void:
	OS.low_processor_usage_mode = false
	call_deferred("run")

func run() -> void:
	var audio = Audio.new()
	audio.attach(root)
	await process_frame
	_check(audio.music_manifest.get("sample_library") == "VSCO2 CE, CC0-1.0", "authored orchestral manifest selected")
	_check(audio.music_manifest.tracks.size() == 9, "all original cue keys covered")
	for key in audio.music_manifest.tracks:
		var entry: Dictionary = audio.music_manifest.tracks[key]
		_check(entry.file.begins_with("res://assets/audio/orchestral/"), "public authored track path " + key)
		_check(audio.play_track(key), "authored PCM loads " + key)
		_check(audio.music.stream.get_length() > 0 and audio.music.stream.stereo, "stereo musical track " + key)
		_check(audio.music.stream.loop_mode == (AudioStreamWAV.LOOP_FORWARD if entry.cycle else AudioStreamWAV.LOOP_DISABLED), "source loop policy " + key)
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 1.0 # Keep the measured 0.2-second PCM window without ring-buffer overflow.
	AudioServer.add_bus_effect(0,capture)
	audio.play_track("bojeu-0")
	var frame_count := ceili(AudioServer.get_mix_rate() * 0.2)
	var deadline := Time.get_ticks_msec() + 5000 # Test watchdog only; expiry is a failure.
	while (audio.music.get_playback_position() < 0.2 or capture.get_frames_available() < frame_count) and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(audio.music.get_playback_position() >= 0.2, "authored PCM playback advances before capture")
	_check(capture.get_frames_available() >= frame_count, "real mixer delivers the measured PCM frame window")
	var buffer := capture.get_buffer(mini(frame_count, capture.get_frames_available()))
	var peak := 0.0
	for frame in buffer: peak = maxf(peak,maxf(absf(frame.x),absf(frame.y)))
	_check(peak > 0, "authored orchestral PCM reaches the real mixer")
	print("Authored orchestral mixer peak: ",peak)
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	var entry: Dictionary = audio.music_manifest.tracks["bojeu-0"]
	var rate: float = audio.music.stream.mix_rate
	var begin: float = entry.loop_begin/rate
	var end: float = entry.loop_end/rate
	var saved: Dictionary = audio.snapshot()
	saved.elapsed = end + (end-begin)/2
	_check(audio.restore(saved) and audio.snapshot() == saved, "elapsed score clock restores across loop wrap")
	_check(is_equal_approx(Audio._score_position(entry,saved.elapsed,end,rate),begin+(end-begin)/2), "restored PCM position stays inside authored loop")
	audio.music.stop()
	audio.queue_free()
	await process_frame
	for failure in failures: push_error(failure)
	print("PASS: authored orchestral cue coverage, PCM mixer, loop policy and save restoration" if failures.is_empty() else "FAIL: authored orchestral score")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
