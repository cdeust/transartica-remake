extends SceneTree
# MIT. Read-only itinerary aid, never a playthrough or gameplay mutation.
# Source: campaign_route_planner.gd and decoded CARTE turn/port rules.
# Only detached models are restored from an actual F5 save. The native game
# continues independently and receives only mouse/key inputs from its pilot.

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 3:
		push_error("Usage: -- SAVE_JSON TARGET_X,TARGET_Y OUTPUT_JSON")
		quit(1)
		return
	var saved = JSON.parse_string(FileAccess.get_file_as_string(arguments[0]))
	var target := arguments[1].split(",")
	if not saved is Dictionary or target.size() != 2:
		push_error("Save or target unavailable")
		quit(1)
		return
	var data = preload("res://scripts/world_data.gd").new()
	var network = preload("res://scripts/rail_network.gd").new()
	var campaign = preload("res://scripts/campaign_state.gd").new()
	var wagons = preload("res://scripts/train_wagons.gd").new()
	data.load_from_project(ProjectSettings.globalize_path("res://"))
	network.load_bytes(data.map_bytes)
	network.set_city_anchors(data.city_anchors())
	if not network.restore(saved.network) or not campaign.restore(saved.campaign.state) or not wagons.restore(saved.wagons):
		push_error("Invalid recorded save")
		quit(1)
		return
	campaign.load_data()
	var planner = preload("res://tests/campaign_route_planner.gd").new()
	planner.network = network
	planner.campaign = campaign
	planner.wagons = wagons
	var position := Vector2i(saved.journey.position[0],saved.journey.position[1])
	var route: Array = planner.plan(position,int(saved.journey.heading),Vector2i(int(target[0]),int(target[1])))
	var result: Array = []
	for action: Dictionary in route:
		var record := action.duplicate()
		for key in record:
			if record[key] is Vector2i:
				record[key] = [record[key].x,record[key].y]
		result.append(record)
	var output := FileAccess.open(arguments[2],FileAccess.WRITE)
	output.store_string(JSON.stringify(result,"\t"))
	print("ITINERARY ",result.size()," cells/actions, start ",position," target ",arguments[1])
	quit(0 if not result.is_empty() else 1)
