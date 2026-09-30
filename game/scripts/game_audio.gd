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


func attach(app: Node) -> void:
	app.add_child(self)
	add_child(samples)
	add_child(music)
	for pair in [["manifest", "manifest.json"], ["music_manifest", "music.json"]]:
		var path: String = "res://private-data/audio/" + pair[1]
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				set(pair[0], parsed)


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


func play_track(key: String) -> bool:
	if not music_enabled:
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
		playback.loop_end = playback.data.size() / 2
	music.stream = playback
	_elapsed = 0.0
	music.volume_linear = _gain(key) # MAIN0x424 Amiga volume83; captures use127.
	current_track = key
	music.play()
	return true


func _process(delta: float) -> void:
	if current_track.is_empty():
		return
	_elapsed += delta
	var entry: Dictionary = music_manifest.get("tracks", {}).get(current_track, {})
	if entry.get("cycle", false):
		# cmusic type4 opcodes.c: attack+1, duration, fall+1; source ticks50Hz.
		var finish: float = (float(entry.duration_ticks) + (21 if current_track == "bopres-0" else 11)) / 50
		if _elapsed > finish:
			music.volume_linear = _gain(current_track) * maxf(0.0, 1.0 - (_elapsed - finish) * 50 / 101)
			if music.volume_linear == 0:
				music.stop()
				current_track = ""


func play_journey() -> void:
	_alternate = not _alternate
	play_track("bojeu2-0" if _alternate else "bojeu-%d" % randi_range(0, 1))


func play_city(city_kind: int) -> void:
	# YODA mainTABLE24548 field2: 1→3,2→1,>3→0; fresh selector otherwise0.
	play_track("bolieu-%d" % ({1: 3, 2: 1}.get(city_kind, 0)))


func play_worksite() -> void:
	play_track("bolieu-2") # YODA0x126a and0x165b both write selector2.


func play_loss() -> void:
	play_track("bolost-0") # YODA0x287d, BOLOST0x2d.


func play_reception() -> void:
	play_track("bopres-0") # MAIN0x593/5c0 and YODA0x288e.


func stop_effects() -> void:
	samples.stop_all() # Original cdelsound is separate from cdelmusic.


func _wave(filename: String) -> AudioStreamWAV:
	if not _cache.has(filename):
		var path := "res://private-data/audio/" + filename
		if not FileAccess.file_exists(path):
			return null
		_cache[filename] = AudioStreamWAV.load_from_file(path)
	return _cache[filename]


func toggle_music() -> bool:
	music_enabled = not music_enabled
	if not music_enabled:
		music.stop()
	elif not current_track.is_empty():
		var selected := current_track
		var elapsed := _elapsed
		play_track(selected)
		_elapsed = elapsed
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
	if not data.track.is_empty() and not music_manifest.get("tracks", {}).has(data.track):
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
	if music_enabled and not current_track.is_empty():
		play_track(current_track)
		var entry: Dictionary = music_manifest.tracks[current_track]
		var stream: AudioStreamWAV = music.stream
		var length: float = float(stream.data.size()) / (stream.mix_rate * 2)
		music.seek(fmod(float(data.elapsed), length) if entry.get("cycle", false) else minf(float(data.elapsed), length))
	_elapsed = float(data.elapsed)
	return true


func reset() -> void:
	stop_effects()
	music.stop()
	music_enabled = true
	effects_enabled = true
	_alternate = false
	current_track = ""
	_elapsed = 0


func _gain(key: String) -> float:
	return 83.0 / 127 if key.begins_with("bojeu") else 1.0
