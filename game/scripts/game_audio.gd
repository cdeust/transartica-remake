extends Node

# MIT. Source-backed playback; all original waveforms/full cue datasets are private.
# YODA0xd23..38 alternates BOJEU2 and BOJEU(rnd2); YODA1070..10be locale.
const Channels = preload("res://scripts/sample_channels.gd")
const Cue = preload("res://scripts/audio_cue.gd")
var samples = Channels.new()
var music := AudioStreamPlayer.new()
var manifest: Dictionary = {}
var music_manifest: Dictionary = {}
var _cache: Dictionary = {}
var _alternate := false
var current_track := ""
var effects_enabled := true
var music_enabled := true
var _elapsed := 0.0
var _fade_remaining := 0.0
var _fade_duration := 0.0
var _fade_gain := 1.0
var _effect_generation := 0
var _engine_audio = preload("res://scripts/engine_audio.gd").new()
var _scene_audio = preload("res://scripts/scene_audio.gd").new()
signal source_sequence_finished


func attach(app: Node) -> void:
	app.add_child(self)
	add_child(samples)
	add_child(music)
	_engine_audio.attach(app,self)
	_scene_audio.attach(app,self)
	for pair in [["manifest", "manifest.json"], ["music_manifest", "music.json"]]:
		var path: String = "res://private-data/audio/" + pair[1]
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				set(pair[0], parsed)
	# Authored orchestral score preserves the original cue keys and transitions.
	# Sample provenance/render proof: orchestral-score-20261006.md.
	var score_path := "res://assets/audio/orchestral/music.json"
	if FileAccess.file_exists(score_path):
		var score: Variant = JSON.parse_string(FileAccess.get_file_as_string(score_path))
		if score is Dictionary and score.get("tracks") is Dictionary:
			music_manifest = score


func sample(script: String, resource: int, priority: int, volume: int, repeat: int, frequency: int) -> int:
	if not effects_enabled:
		return -1
	var entry: Dictionary = manifest.get("scripts", {}).get(script, {}).get("samples", {}).get(str(resource), {})
	if entry.is_empty():
		return -1
	var stream: AudioStreamWAV = _wave(entry.file)
	if stream == null:
		return -1
	var rate: int = entry.frequency_khz if frequency == 0 else frequency
	return samples.play(stream, ((priority + 128) & 255) - 128, volume, repeat, rate, int(entry.frequency_khz))


func effect(script: String, source_offset: int, locals: Dictionary = {}) -> int:
	for event in manifest.get("scripts", {}).get(script, {}).get("cues", []):
		if int(event.offset) == source_offset and event.name == "csound":
			var parameters: Array[int] = []
			for operand in event.args:
				parameters.append(Cue.value(operand, locals))
			return sample(script, parameters[0], parameters[1], parameters[2], parameters[3], parameters[4])
	return -1


func play_track(key: String, guard_preference := true) -> bool:
	if guard_preference and not music_enabled:
		music.stop()
		current_track = ""
		return false
	var entry: Dictionary = music_manifest.get("tracks", {}).get(key, {})
	if entry.is_empty():
		return false
	var stream: AudioStreamWAV = _wave(entry.file)
	if stream == null:
		return false
	music.stop()
	var playback: AudioStreamWAV = stream.duplicate()
	if entry.get("cycle", false):
		playback.loop_mode = AudioStreamWAV.LOOP_FORWARD
		playback.loop_begin = int(entry.get("loop_begin", 0))
		playback.loop_end = int(entry.get("loop_end", roundi(playback.get_length() * playback.mix_rate)))
	music.stream = playback
	_elapsed = 0.0
	_fade_remaining = 0
	music.volume_linear = _gain(key) # MAIN0x4b0 ECS volume50; captures use127.
	current_track = key
	music.play()
	return true


func _process(delta: float) -> void:
	_engine_audio.advance(delta)
	_scene_audio.advance(delta)
	if current_track.is_empty():
		return
	_elapsed += delta
	if _fade_remaining > 0:
		_fade_remaining = maxf(0, _fade_remaining - delta)
		music.volume_linear = _fade_gain * _fade_remaining / _fade_duration
		if _fade_remaining == 0:
			music.stop()
			current_track = ""
		return
	var entry: Dictionary = music_manifest.get("tracks", {}).get(current_track, {})
	if entry.get("cycle", false):
		# cmusic type4 opcodes.c: attack+1, duration, fall+1; source ticks50Hz.
		var finish: float = (float(entry.duration_ticks) + (21 if current_track == "bopres-0" else 11)) / 50
		if _elapsed > finish:
			music.volume_linear = _gain(current_track) * maxf(0.0, 1.0 - (_elapsed - finish) * 50 / 101)
			if music.volume_linear == 0:
				music.stop()
				current_track = ""


func play_journey(synthesized_music := true) -> void:
	# YODA0xd04 requires capability25936==0; ECS skips Atari setter0x3b8.
	if not synthesized_music or not music_enabled:
		play_track("")
		return
	_alternate = not _alternate
	play_track("bojeu2-0" if _alternate else "bojeu-%d" % randi_range(0, 1))


func play_city(city_kind: int, city_index := -1) -> void:
	if absi(city_kind) == 3 or city_index == 45:
		music.stop()
		current_track = ""
		return # YODA0x1031..105a original exclusions.
	# YODA mainTABLE24548 field2: 1→3,2→1,>3→0; fresh selector otherwise0.
	play_track("bolieu-%d" % ({1: 3, 2: 1}.get(city_kind, 0)))


func play_worksite() -> void:
	play_track("bolieu-2") # YODA0x126a and0x165b both write selector2.


func play_loss() -> void:
	play_track("bolost-0") # ECS model3000→MAIN25915=0, YODA0x2870..28c2.


func play_reception() -> void:
	play_track("bopres-0", false) # MAIN0x593/5c0 title is unconditional.


func stop_effects() -> void:
	_effect_generation += 1
	samples.stop_all() # Original cdelsound is separate from cdelmusic.


func _wave(filename: String) -> AudioStreamWAV:
	if not _cache.has(filename):
		var path := filename if filename.begins_with("res://") else "res://private-data/audio/" + filename
		_cache[filename] = preload("res://scripts/source_audio_resource.gd").wave(path)
	return _cache[filename]


func toggle_music() -> bool:
	# OPTION0xf3/0xfb/0x108 MAIN25912; enabled means original flag0.
	music_enabled = not music_enabled
	if not music_enabled:
		music.stop()
	elif not current_track.is_empty():
		play_track(current_track) # Fresh PCM and source envelope clock restart together.
	return music_enabled


func snapshot() -> Dictionary:
	return {"version": 1, "music_enabled": music_enabled, "effects_enabled": effects_enabled,
		"alternate": _alternate, "track": current_track, "elapsed": _elapsed}


func validate_snapshot(data: Variant) -> bool:
	if not data is Dictionary or data.keys().size() != 6:
		return false
	for field in ["music_enabled", "effects_enabled", "alternate"]:
		if not data.get(field) is bool:
			return false
	if data.get("version") != 1 or not data.get("track") is String:
		return false
	if not data.track.is_empty():
		var entry: Dictionary = music_manifest.get("tracks", {}).get(data.track, {})
		if entry.is_empty() or _wave(entry.file) == null:
			return false
	var elapsed: Variant = data.get("elapsed")
	return (elapsed is float or elapsed is int) and is_finite(float(elapsed)) and elapsed >= 0


func restore(data: Dictionary) -> bool:
	if not validate_snapshot(data):
		return false
	reset()
	music_enabled = data.music_enabled
	effects_enabled = data.effects_enabled
	_alternate = data.alternate
	current_track = data.track
	if not current_track.is_empty():
		if not play_track(current_track, false):
			return false
		var entry: Dictionary = music_manifest.tracks[current_track]
		var stream: AudioStreamWAV = music.stream
		# Imported QOA and raw PCM have different byte counts for the same duration.
		# Evidence: exported-audio-20261004.md compares the actual release resource.
		var length: float = stream.get_length()
		music.seek(_score_position(entry, float(data.elapsed), length,stream.mix_rate))
	_elapsed = float(data.elapsed)
	return true


func reset() -> void:
	_engine_audio.reset()
	_scene_audio.reset()
	stop_effects()
	music.stop()
	music_enabled = true
	effects_enabled = true
	_alternate = false
	current_track = ""
	_elapsed = 0
	_fade_remaining = 0


static func _score_position(entry: Dictionary, elapsed: float, length: float, rate: float) -> float:
	# Source: capture_alis_music_loop.c records source sample boundaries. The
	# initial attack occurs once; subsequent elapsed time wraps inside the loop.
	var begin: float = float(entry.get("loop_begin",0)) / rate
	var end: float = float(entry.get("loop_end",int(length*rate))) / rate
	if entry.get("cycle",false) and end > begin and elapsed >= end:
		return begin + fposmod(elapsed-begin,end-begin)
	return minf(elapsed,length)


func _gain(key: String) -> float:
	return 50.0 / 127 if key.begins_with("bojeu") else 1.0


func fade_music(ticks: int) -> void:
	# Original cdelmusic→music_v2.c:mv2_offmusic, requested source tick fall.
	if ticks <= 0:
		music.stop()
		current_track = ""
		return
	_fade_duration = float(ticks) / 50
	_fade_remaining = _fade_duration
	_fade_gain = music.volume_linear


func new_game_reset() -> void:
	# OPTION25912 survives original START; only the runtime selector resets.
	var enabled := music_enabled
	var effects := effects_enabled
	reset()
	music_enabled = enabled
	effects_enabled = effects


func toggle_original_music() -> bool:
	# OPTION action3 writes25912 only; currently playing score is left intact.
	music_enabled = not music_enabled
	return music_enabled


func son(selector: int, pitch := 0, long_ambient := true) -> int:
	# SON0x18 cswitch base0; ECS MAIN25918=4 chooses ambient10000 branch.
	var offsets := {0: 0x34, 1: 0x48, 3: 0x9b, 4: 0xaf, 5: 0xc3, 7: 0xdf}
	if selector == 2:
		return effect("son", 0x72 if long_ambient else 0x87, {"12": pitch})
	if selector == 8:
		return effect("son", 0x109 if long_ambient else 0x11e, {"12": pitch})
	if selector == 6:
		var channel := effect("son", 0x12f)
		_son_sequence(_effect_generation)
		return channel
	return effect("son", offsets[selector], {"12": pitch}) if offsets.has(selector) else -1


func _son_sequence(generation: int) -> void:
	# SON0x13a/14f each waits three source cycles before next pitch.
	for offset in [0x144, 0x159]:
		await get_tree().create_timer(3.0 / 50).timeout
		if generation != _effect_generation:
			source_sequence_finished.emit()
			return
		effect("son", offset)
	source_sequence_finished.emit()
