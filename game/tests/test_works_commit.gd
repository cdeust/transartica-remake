extends SceneTree

const Network = preload("res://scripts/rail_network.gd")
const Journey = preload("res://scripts/train_journey.gd")
const Wagons = preload("res://scripts/train_wagons.gd")
const Dialog = preload("res://scripts/works_dialog.gd")
const TrackWorks = preload("res://scripts/track_works.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var bytes := PackedByteArray()
	bytes.resize(Network.WIDTH * Network.HEIGHT)
	bytes[83 * Network.HEIGHT + 67] = 67
	bytes[82 * Network.HEIGHT + 67] = 2
	var network = Network.new()
	network.load_bytes(bytes)
	var journey = Journey.new()
	journey.network = network
	journey.position = Vector2i(82, 67)
	journey.blocked = true
	journey.stop_reason = "obstacle"
	var wagons = Wagons.new()
	wagons.wagons = [[18, 0, 1, 30], [6, 0, 0, 20]]
	var dialog = Dialog.new()
	dialog.journey = journey
	dialog.wagons = wagons
	dialog.rng = RandomNumberGenerator.new()
	dialog.rng.seed = 1
	root.add_child(dialog)
	dialog.ask(network)
	dialog._accept()
	var saved: Dictionary = dialog.snapshot()
	var rails_after_accept: int = wagons.wagons[0][3]
	if not Dialog.validate_snapshot(saved, network) or not dialog.restore(saved):
		push_error("accepted works restore must preserve pending map commit")
		quit(1)
		return
	dialog._accept()
	if wagons.wagons[0][3] != rails_after_accept:
		push_error("restored accepted works must never charge twice")
		quit(1)
		return
	if network.tile(Vector2i(83, 67)) != 67 or not journey.blocked:
		push_error("YODA 0x25c2: map and journey must remain blocked until TEXTEK close")
		quit(1)
		return
	dialog._close(true)
	if network.tile(Vector2i(83, 67)) != 63 or journey.blocked:
		push_error("YODA 0x25ce: close commits repair and retry")
		quit(1)
		return
	network.load_bytes(bytes)
	dialog.restore(saved)
	dialog.reset()
	dialog._close(true)
	var cleared: Dictionary = dialog.snapshot()
	if cleared.visible or cleared.accepted or cleared.countdown != 0 or cleared.cell != [-1,-1] or network.tile(Vector2i(83,67)) != 67:
		push_error("New-game reset must discard accepted repair and closing callbacks")
		quit(1)
		return
	wagons.wagons = [[18,0,1,2],[5,0,0,15],[7,0,0,2],[16,3,0,0]]
	var report: Dictionary = TrackWorks.work_report("crevasse", wagons)
	if report.ticks != -47 or report.mammoths != 2 or report.cranes != 1:
		push_error("TEXTEK signed-byte labour countdown mismatch")
		quit(1)
		return
	TrackWorks.consume_rails(wagons,2)
	if wagons.wagons[0][2] != 1 or wagons.wagons[0][3] != 0:
		push_error("TEXTEK exact zero retains goods1")
		quit(1)
		return
	print("PASS: works close-time map commit, pending resume without recharge, signed-byte labour and exact-zero rails")
	dialog.queue_free()
	quit(0)
