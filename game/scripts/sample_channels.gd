extends Node

# MIT. ALIS audio.c playsample four-channel priority and finite-repeat rules;
# sys.c sample mixer uses signed8 PCM * (volume>>1), hence /256 gain.
var players: Array[AudioStreamPlayer] = []
var priorities: Array[int] = []
var loops: Array[int] = []


func _ready() -> void:
	for index in 4:
		var player := AudioStreamPlayer.new()
		add_child(player)
		players.append(player)
		priorities.append(-128) # Original idle curson0x80.
		loops.append(0)
		player.finished.connect(_finished.bind(index))


func play(stream: AudioStreamWAV, priority: int, volume: int, repeat: int, frequency: int, original_rate: int) -> int:
	var chosen := 0
	var found := false
	for index in 4:
		if priorities[index] == priority:
			chosen = index
			found = true
			break
	if not found:
		for index in 4:
			if priorities[index] < priorities[chosen]:
				chosen = index
	var current := priorities[chosen]
	if (priority >= 0 and current < 0 and current != -128) or priority < current:
		return -1 # Exact source protection of negative-priority ambient channels.
	var rate := frequency if frequency >= 1 and frequency <= 20 else 10
	var player := players[chosen]
	player.stop()
	player.stream = stream
	player.pitch_scale = float(rate) / original_rate
	player.volume_linear = float(volume >> 1) / 256
	priorities[chosen] = priority
	loops[chosen] = maxi(1, repeat) # sys.c only repeats while loop>1.
	player.play()
	return chosen


func _finished(index: int) -> void:
	loops[index] -= 1
	if loops[index] > 0:
		players[index].play()
	else:
		priorities[index] = -128


func stop_all() -> void:
	for index in players.size():
		players[index].stop()
		priorities[index] = -128
		loops[index] = 0
