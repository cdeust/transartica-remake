extends SceneTree
# MIT. Earned42991 closed bridge; source TIME/YODA78 mine and65 workshop exits.
# Projection only: native physical rear contacts are validated by the live pilot.
const Planner = preload("res://tests/campaign_route_planner.gd")
const Rails = preload("res://scripts/rail_network.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Usage: -- earned42991.json")
		quit(1)
		return
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	var data = preload("res://scripts/world_data.gd").new()
	check(data.load_from_project(ProjectSettings.globalize_path("res://")),"Load source world")
	var network = Rails.new()
	network.load_bytes(data.map_bytes)
	network.set_city_anchors(data.city_anchors())
	check(network.restore(saved.network),"Restore earned network")
	var campaign = preload("res://scripts/campaign_state.gd").new()
	check(campaign.restore(saved.campaign.state) and campaign.load_data(),"Restore earned campaign")
	var wagons = preload("res://scripts/train_wagons.gd").new()
	check(wagons.restore(saved.wagons),"Restore earned train")
	var planner = Planner.new()
	planner.network = network
	planner.campaign = campaign
	planner.wagons = wagons
	planner.allow_midtrack_reverse = false
	var mine := Vector2i(111,32)
	check(network.tile(mine) == 78 and network.tile(Vector2i(110,33)) == -120,"Actual mine and closed bridge are preserved")
	var before: Dictionary = network.snapshot()
	var position := Vector2i(saved.journey.position[0],saved.journey.position[1])
	var route: Array = planner.plan(position,int(saved.journey.heading),Vector2i(121,32),int(saved.journey.phase))
	check(route.size() == 154,"Earned mine turnaround reaches Balkhach in154 projected actions")
	if route.size() == 154:
		check(route[144].get("station") == mine and route[145].heading == 3 and route[145].switch == 20,"Mine exit reverses heading before next switch")
	for action in route:
		check(not action.get("reverse",false) and action.next != Vector2i(110,33),"No operator midtrack reverse or closed bridge crossing")
	check(network.snapshot() == before,"Planning never mutates the earned network")
	# Contrast the existing65 branch on the same detached topology.
	network._tiles[mine.x*Rails.HEIGHT+mine.y] = 65
	var workshop_route: Array = planner.plan(position,int(saved.journey.heading),Vector2i(121,32),int(saved.journey.phase))
	check(workshop_route.size() == 154,"Existing65 workshop projection remains reachable")
	check(workshop_route == route,"Mine and workshop use the same forced exit projection")
	check(network.entry_boundary(mine) == "event site","Workshop is recognized as an event boundary")
	network._tiles[mine.x*Rails.HEIGHT+mine.y] = 78
	check(network.entry_boundary(mine) == "event site","Mine is recognized as an event boundary")
	check(network.snapshot() == before,"Detached contrast restores the exact network")
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: earned42991 closed-bridge mine turnaround projection,65 contrast, source event boundaries and unchanged network")
	quit(0 if failures.is_empty() else 1)
