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
	for key in ["bojeu-0","bojeu-1","bojeu2-0","bopres-0"]:
		var entry: Dictionary = audio.music_manifest.tracks[key]
		check(entry.loop_begin > 0 and entry.loop_end > entry.loop_begin,"initial source attack is outside repeating region")
		audio.play_track(key)
		check(audio.music.stream.loop_begin == entry.loop_begin and audio.music.stream.loop_end == entry.loop_end,"native WAV player uses captured source boundaries")
		var rate: float = audio.music.stream.mix_rate
		var begin: float = entry.loop_begin/rate
		var end: float = entry.loop_end/rate
		check(is_equal_approx(Audio._score_position(entry,end+(end-begin)/2,end,rate),begin+(end-begin)/2),"saved elapsed clock wraps inside second source cycle")
	audio.reset()
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
	check(audio.son(7) == 0 and audio.samples.loops[0] == 3, "source SONselector7 pitchcue")
	audio.stop_effects()
	check(audio.son(8) == 0 and audio.samples.loops[0] == 10000, "source SONselector8 ECS longambient")
	audio.stop_effects()
	var pitched_channel: int = audio.son(8,2)
	var expected_pitch: float = 6.0/float(audio.manifest.scripts.son.samples["6"].frequency_khz)
	check(pitched_channel == 0 and is_equal_approx(audio.samples.players[0].pitch_scale,expected_pitch),"SON local12 pitch %.6f equals %.6f on native channel%d" % [audio.samples.players[0].pitch_scale,expected_pitch,pitched_channel])
	audio.stop_effects()
	check(audio.son(6) == 0 and audio.samples.loops[0] == 4, "source SONselector6 starts threepitchsequence")
	audio.stop_effects()
	await audio.source_sequence_finished
	check(audio.samples.priorities == [-128, -128, -128, -128], "cdelsound cancels pending original sequence")
	check(audio.play_track("bojeu-0") and audio.music.playing, "source gameplay track native playback")
	audio.play_city(1)
	check(audio.current_track == "bolieu-3", "source type1 locale music")
	audio.play_city(2)
	check(audio.current_track == "bolieu-1", "source type2 locale music")
	audio.play_worksite()
	check(audio.current_track == "bolieu-2", "source mines/workshop music")
	audio.play_journey(true)
	check(audio.current_track == "bojeu2-0", "source first journey alternate")
	audio.play_journey(true)
	check(audio.current_track in ["bojeu-0", "bojeu-1"], "source second journey rnd2")
	audio.play_city(3)
	check(not audio.music.playing, "original type3 locale excludes music")
	audio.play_city(1, 45)
	check(not audio.music.playing, "original city45 excludes music")
	audio.play_journey(false)
	check(not audio.music.playing, "original disabled capability excludes synthesized travel branch")
	audio.play_reception()
	var saved: Dictionary = audio.snapshot()
	check(audio.validate_snapshot(saved), "audio save can be staged without mutation")
	var broken: Dictionary = saved.duplicate()
	broken.track = "unknown"
	check(not audio.restore(broken) and audio.snapshot() == saved, "invalid audio restore is atomic")
	check(not audio.toggle_music() and not audio.music.playing, "music setting stops original score")
	check(audio.toggle_music() and audio._elapsed == 0, "music reenable restarts PCM and envelope together")
	check(audio.restore(saved) and audio.current_track == saved.track, "music save resumes source selection")
	audio.play_reception()
	check(not audio.toggle_original_music() and audio.music.playing, "original option only changes subsequent music preference")
	var disabled_title: Dictionary = audio.snapshot()
	check(audio.restore(disabled_title) and audio.music.playing and not audio.music_enabled, "unconditional title score resumes while preference disabled")
	audio.play_loss()
	check(not audio.music.playing, "original loss score respects25912 guard")
	audio.toggle_original_music()
	audio.play_loss()
	check(audio.current_track == "bolost-0", "original ECS loss selects BOLOST via model3000")
	audio.fade_music(50)
	audio._process(1.0)
	check(not audio.music.playing and audio.current_track.is_empty(), "source cdelmusic falls to silence")
	audio.music_enabled = false
	audio.new_game_reset()
	check(not audio.music_enabled and audio.current_track.is_empty(), "original START retains user music setting")
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
