extends SceneTree
# MIT. Exact saved9876 and observed9875 drive detached regression models only.
const Rails = preload("res://scripts/rail_network.gd")
const Journey = preload("res://scripts/train_journey.gd")
var errors: Array[String] = []
var baseline := false
var saved: Dictionary
var observed: Dictionary
func _initialize() -> void:
	baseline = "--before-planner" in OS.get_cmdline_user_args()
	saved = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../reference-private/validation/planner-reversal-earned9876.json")))
	observed = JSON.parse_string(FileAccess.get_file_as_string(ProjectSettings.globalize_path("res://../reference-private/validation/planner-reversal-observed9875.json")))
	var data = preload("res://scripts/world_data.gd").new()
	check(data.load_from_project(ProjectSettings.globalize_path("res://")),"private reference loads")
	var network = Rails.new()
	network.load_bytes(data.map_bytes)
	network.set_city_anchors(data.city_anchors())
	check(network.restore(saved.network),"earned9876 network restores")
	var campaign = preload("res://scripts/campaign_state.gd").new()
	check(campaign.restore(saved.campaign.state) and campaign.load_data(),"earned campaign restores")
	var wagons = preload("res://scripts/train_wagons.gd").new()
	check(wagons.restore(saved.wagons),"earned21-wagon composition restores")
	var planner = load(ProjectSettings.globalize_path("res://../.cache/planner-reversal-phase-fix-20261004/before.gd") if baseline else "res://tests/campaign_route_planner.gd").new()
	planner.network = network
	planner.campaign = campaign
	planner.wagons = wagons
	var original: Dictionary = network.snapshot()
	# Observe phase1/heading4 at9875; no full save exists for that observation.
	var route: Array = plan(planner,4,30,int(observed.phase))
	check(route.size()==2 and route[0].get("reverse",false),"9875 direct east itinerary starts with reverse")
	if route.size()==2:
		check(route[1].get("switch")==22 and route[1].outgoing==6,"9875 reverse must prepare22 before east departure")
	if not baseline:
		var default_route: Array = planner.plan(Vector2i(29,24),4,Vector2i(28,24))
		check(default_route.size()==1 and default_route[0].phase==0 and default_route[0].outgoing==4,"three-argument caller retains phase0 departure")
		for phase in [-1,0,1,2]: test_phase(planner,network,phase)
		var resumed: Array = plan(planner,6,30,int(saved.journey.phase))
		check(resumed.size()==1 and resumed[0].get("switch")==22,"exact9876 phase0 replan prepares22")
		var journey = Journey.new()
		journey.network = network
		check(journey.restore(saved.journey),"exact9876 journey restores")
		journey.advance(20)
		check(journey.heading==3 and journey.phase==1,"unchanged23 reproduces native9877 turn")
		check(journey.restore(saved.journey) and network.toggle_switch(Vector2i(29,24)),"prepared22 uses real toggle")
		while journey.position==Vector2i(29,24) and not journey.blocked: journey.advance(300)
		check(journey.position==Vector2i(30,24) and journey.heading==6,"prepared22 departure matches actual journey")
		check(network.restore(original),"restore owned detached map")
	check(network.snapshot()==original,"planning preserves source network")
	for error in errors: push_error(error)
	if errors.is_empty(): print("PASS: earned9875/9876 planner reverse phases, switch preparation and detached journey agreement")
	quit(0 if errors.is_empty() else 1)
func plan(planner, heading: int, target_x: int, phase: int) -> Array:
	return planner.plan(Vector2i(29,24),heading,Vector2i(target_x,24)) if baseline else planner.plan(Vector2i(29,24),heading,Vector2i(target_x,24),phase)
func test_phase(planner,network,phase: int) -> void:
	var original: Dictionary = network.snapshot()
	var journey = Journey.new()
	journey.network = network
	check(journey.restore(saved.journey),"phase fixture begins from actual save")
	# Explicit source-phase model variants of the observed location, not native play.
	journey.phase = phase
	journey.heading = 4
	journey.incoming_heading = 4
	var route: Array = plan(planner,4,30,phase)
	check(route.size()==2 and route[0].get("reverse",false),"phase %d direct reverse route" % phase)
	if route.size()!=2: return
	journey.reverse_direction()
	check(route[0].phase_before==phase and route[0].phase_after==journey.phase,"phase %d source reverse formula" % phase)
	check(route[1].phase==journey.phase,"phase %d propagated after reverse" % phase)
	var expected: int = 22 if journey.phase<Journey.TURN_PHASE else 23
	check(route[1].get("switch")==expected,"phase %d turn-sensitive switch" % phase)
	if network.tile(Vector2i(29,24)) != expected:
		check(network.toggle_switch(Vector2i(29,24)),"phase %d prepares real switch" % phase)
	while journey.position==Vector2i(29,24) and not journey.blocked:
		journey.advance(300)
	check(journey.position==route[1].next and journey.heading==route[1].outgoing,"phase %d planned exit matches source journey" % phase)
	check(network.restore(original),"phase %d restores detached network" % phase)
func check(ok: bool,label: String) -> void:
	if not ok: errors.append(label)
