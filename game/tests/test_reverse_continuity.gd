extends SceneTree
# MIT. Observed continuous normal-start save, owner3Oct disappearance report.
const Journey = preload("res://scripts/train_journey.gd")
const Rails = preload("res://scripts/rail_network.gd")
const View = preload("res://scripts/travel_world.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var save = JSON.parse_string(FileAccess.get_file_as_string(
		"res://../tasks/validation/continuous-play-20261003/reverse-disappeared-journey.json"))
	var network = Rails.new()
	network.load_bytes(FileAccess.get_file_as_bytes("res://../reference-private/CARTE.FIC"))
	var journey = Journey.new()
	journey.network = network
	assert(journey.restore(save.journey), "observed native save restores")
	var view = View.new()
	root.add_child(view)
	view.consist.derive_from_wagons(preload("res://scripts/train_wagons.gd").new())
	assert(view.train_renderer.load_assets())
	_check_convoy(view, journey, "recorded stopped reverse")
	for cycle in 12:
		journey.advance(137) # Actual regulator/speed in the recorded player run.
		_check_convoy(view, journey, "backing cycle%d" % cycle)
	var restored = Journey.new()
	restored.network = network
	assert(restored.restore(journey.snapshot()))
	_check_convoy(view, restored, "save/reload reverse")
	view.queue_free()
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: recorded native reverse save renders all six vehicles and retains them while backing")
	quit(0 if failures.is_empty() else 1)

func _check_convoy(view, journey, label: String) -> void:
	var count: int = view.train_renderer.poses(view,journey,view.consist,0.0).size()
	if count != view.consist.vehicles.size():
		failures.append("%s: %d/%d vehicles" % [label,count,view.consist.vehicles.size()])
