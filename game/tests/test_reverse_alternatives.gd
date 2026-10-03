extends SceneTree
# MIT. Prepared model fixtures using the supplied topology and earned7087.
# None of these state preparations is native player acceptance.
const Stop = preload("res://scripts/reverse_contact_stop.gd")
const Journey = preload("res://scripts/train_journey.gd")
const Network = preload("res://scripts/rail_network.gd")
const Wagons = preload("res://scripts/train_wagons.gd")
const Dialog = preload("res://scripts/works_dialog.gd")
const Works = preload("res://scripts/track_works.gd")
const View = preload("res://scripts/travel_world.gd")
var failures: Array[String] = []
var saved: Dictionary
var world
var rows := 0
func _initialize() -> void: call_deferred("_run")
func check(value: bool, label: String) -> void:
	if not value: failures.append(label)
func _run() -> void:
	saved = JSON.parse_string(FileAccess.get_file_as_string("res://../reference-private/validation/reverse-obstacle-approach-earned.json"))
	world = preload("res://scripts/world_data.gd").new()
	assert(world.load_from_project(ProjectSettings.globalize_path("res://").trim_suffix("/")))
	for length in [6,9,13]: _reverse_cases(length)
	_forward_station("forward-InSalah-earned.json",Vector2i(23,61))
	_forward_station("forward-Copenhagen-earned.json",Vector2i(34,12))
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: %d alternative model cases, lengths6/9/13, shortage/retry/return, save phases, Rum/InSalah/Copenhagen source approaches" % rows)
	quit(0 if failures.is_empty() else 1)
func fixture(length: int) -> Dictionary:
	var network = Network.new()
	assert(network.load_bytes(world.map_bytes))
	assert(network.restore(saved.network))
	network.set_city_anchors(world.city_anchors())
	var journey = Journey.new()
	journey.network = network
	assert(journey.restore(saved.journey))
	var wagons = Wagons.new()
	assert(wagons.restore(saved.wagons))
	wagons.wagons = wagons.wagons.slice(0,length)
	var view = View.new()
	root.add_child(view)
	view.consist.derive_from_wagons(wagons)
	assert(view.train_renderer.load_assets())
	return {"network":network,"journey":journey,"wagons":wagons,"view":view}
func poses(f: Dictionary) -> Array:
	return f.view.train_renderer.poses(f.view,f.journey,f.view.consist,0.0)
func roundtrip(f: Dictionary, label: String) -> void:
	var before: Array = poses(f)
	var value = JSON.parse_string(JSON.stringify({"journey":f.journey.snapshot(),"network":f.network.snapshot(),"wagons":f.wagons.snapshot()}))
	check(f.network.restore(value.network),label+" network")
	check(f.wagons.restore(value.wagons),label+" wagons")
	check(f.journey.restore(value.journey),label+" journey")
	check(poses(f)==before,label+" contacts")
	rows += 1
func drive(f: Dictionary, label: String) -> void:
	for tick in 1000: # Bounded model drive across the earned finite approach.
		Stop.advance(f.view,f.journey,300)
		check(poses(f).size()==f.view.consist.vehicles.size(),label+" full consist tick%d" % tick)
		if f.journey.blocked: return
	check(false,label+" did not stop")
func _reverse_cases(length: int) -> void:
	var f := fixture(length)
	var label := "length%d" % length
	roundtrip(f,label+" before")
	drive(f,label+" initial")
	check(f.journey.at_obstacle() and f.journey.boundary_cell()==Vector2i(6,9),label+" crevasse")
	roundtrip(f,label+" stopped")
	var contact: Array = poses(f)
	check(f.journey.reverse_direction(),label+" away reverse")
	check(poses(f)==contact,label+" away continuity")
	for tick in 10: Stop.advance(f.view,f.journey,300)
	check(poses(f).size()==length,label+" away drawn")
	contact = poses(f)
	check(f.journey.reverse_direction(),label+" return reverse")
	check(poses(f)==contact,label+" return continuity")
	drive(f,label+" return")
	check(f.journey.at_obstacle() and f.journey.boundary_cell()==Vector2i(6,9),label+" return same obstacle")
	# Labour fixtures are real source wagon types, independent of the rendered
	# earned composition; varying quantities here is explicitly model setup.
	var labour = Wagons.new()
	var dialog = Dialog.new()
	dialog.journey=f.journey; dialog.wagons=labour
	dialog.rng=RandomNumberGenerator.new(); dialog.rng.seed=1
	root.add_child(dialog)
	for scenario in [{"kind":"rails","quantity":0},{"kind":"rails","quantity":Works.WORKS.crevasse.rails-1},{"kind":"slaves","quantity":0},{"kind":"slaves","quantity":Works.WORKS.crevasse.slaves-1}]:
		var shortage: String = scenario.kind
		labour.wagons=[[18,0,1,scenario.quantity if shortage=="rails" else 30],[5,0,0,scenario.quantity if shortage=="slaves" else 24]]
		var unchanged: Array = labour.snapshot()
		check(Works.shortage("crevasse",labour)==shortage,label+" source shortage"+shortage)
		check(dialog.ask(f.network),label+" ask")
		dialog._accept()
		check(not dialog.snapshot().accepted and labour.snapshot()==unchanged,label+" shortage no charge "+shortage)
		check(f.network.tile(Vector2i(6,9))==69,label+" shortage no repair")
		dialog._close(false)
		check(f.journey.resume_after_works(),label+" shortage retry release")
		Stop.advance(f.view,f.journey,300)
		check(f.journey.at_obstacle() and f.journey.obstacle_cell()==Vector2i(6,9),label+" shortage retries same")
		rows+=1
	labour.wagons=[[18,0,1,30],[5,0,0,24]]
	dialog.ask(f.network); dialog._decline()
	check(f.journey.at_obstacle(),label+" explicit decline blocked")
	dialog.ask(f.network); dialog._accept()
	var paid: Array = labour.snapshot()
	var pending = JSON.parse_string(JSON.stringify(dialog.snapshot()))
	check(labour.restore(JSON.parse_string(JSON.stringify(paid))),label+" accepted cargo reload")
	roundtrip(f,label+" accepted")
	check(dialog.restore(pending),label+" accepted dialog reload")
	dialog._accept()
	check(labour.snapshot()==paid,label+" reload no double charge")
	dialog._close(true)
	check(f.network.tile(Vector2i(6,9))==64 and not f.journey.blocked,label+" repaired")
	roundtrip(f,label+" repaired")
	drive(f,label+" Rum")
	check(f.journey.at_station() and f.journey.boundary_cell()==Vector2i(6,10),label+" Rum physical port")
	roundtrip(f,label+" station")
	check(f.journey.depart_from_station(),label+" depart")
	roundtrip(f,label+" departure")
	dialog.queue_free(); f.view.queue_free()
func _forward_station(file: String, target: Vector2i) -> void:
	var original := saved
	saved = JSON.parse_string(FileAccess.get_file_as_string("res://../reference-private/validation/"+file))
	var f := fixture(saved.wagons.size())
	saved = original
	# Prepared model replay: move source elapsed phase back inside this same
	# station-adjacent tile, preserving the actual traversed incoming rail path.
	f.journey.blocked=false; f.journey.stop_reason=""
	f.journey.phase=1; f.journey.distance_ticks=0
	if not f.journey._render_path.points.is_empty():
		f.journey._render_cursor-=2.0/3.0 # Source three equal travel phases.
	drive(f,"forward earned-history station%s" % target)
	check(f.journey.at_station() and f.journey.boundary_cell()==target,"forward source station%s" % target)
	roundtrip(f,"forward source station%s" % target)
	check(f.journey.depart_from_station(),"forward departure%s" % target)
	f.view.queue_free()
