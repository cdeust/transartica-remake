extends SceneTree

# requires-native-renderer
# Native mixer output is the evidence, rather than just instantiated audio players.
const Audio = preload("res://scripts/game_audio.gd")
var failures: Array[String] = []


func _initialize() -> void:
	OS.low_processor_usage_mode = false
	call_deferred("run")


func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)


func run() -> void:
	var audio = Audio.new()
	audio.attach(root)
	await process_frame
	check(audio.music_manifest.get("tracks", {}).size() == 9, "all source music selections packaged")
	var capture := AudioEffectCapture.new()
	AudioServer.add_bus_effect(0, capture)
	var channel: int = audio.effect("berta", 0x568) # Original decoded csound, no synthetic fallback.
	check(channel == 0 and audio.samples.players[0].playing, "original sample reaches native playback")
	await audio.samples.players[0].finished
	var buffer := capture.get_buffer(capture.get_frames_available())
	var peak := 0.0
	for frame in buffer:
		peak = maxf(peak, maxf(absf(frame.x), absf(frame.y)))
	check(peak > 0, "native mixer output contains original nonzero PCM")
	print("Native original PCM mixer peak: ", peak)
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	var a: int = audio.sample("son", 7, -10, 127, 10000, 3)
	check(a >= 0 and audio.samples.loops[a] == 10000, "source long negative-priority ambient repeat")
	for priority in [30, 40, 50]:
		audio.sample("son", 0, priority, 127, 1, 8)
	check(audio.sample("son", 0, 60, 127, 1, 8) == -1, "original negative ambient channel cannot be preempted by positive priority")
	check(audio.sample("son", 7, -10, 127, 5, 3) == a and audio.samples.loops[a] == 5, "equal priority reuses the original channel")
	audio.stop_effects()
	check(audio.samples.priorities == [-128, -128, -128, -128], "cdelsound resets all original channels")
	check(audio.play_track("bojeu-0") and audio.music.playing, "source gameplay track native playback")
	audio.play_city(1)
	check(audio.current_track == "bolieu-3", "source type1 locale music")
	audio.play_city(2)
	check(audio.current_track == "bolieu-1", "source type2 locale music")
	audio.play_worksite()
	check(audio.current_track == "bolieu-2", "source mines/workshop music")
	audio.play_journey()
	check(audio.current_track == "bojeu2-0", "source first journey alternate")
	audio.play_journey()
	check(audio.current_track in ["bojeu-0", "bojeu-1"], "source second journey rnd2")
	var saved: Dictionary = audio.snapshot()
	check(audio.validate_snapshot(saved), "audio save can be staged without mutation")
	var broken: Dictionary = saved.duplicate()
	broken.track = "unknown"
	check(not audio.restore(broken) and audio.snapshot() == saved, "invalid audio restore is atomic")
	check(not audio.toggle_music() and not audio.music.playing, "music setting stops original score")
	check(audio.restore(saved) and audio.current_track == saved.track, "music save resumes source selection")
	audio.reset()
	check(audio.current_track.is_empty() and audio.music_enabled, "new game resets all audio settings")
	audio.music.stop()
	audio.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: native original mixer activity, four-channel priority, source rate/loops and scene-selected scores")
	quit(0 if failures.is_empty() else 1)
