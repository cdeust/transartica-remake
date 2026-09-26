extends SceneTree
# source: reproducible native rendering measurement, 10 seconds per observed state.
var scene
var started: int
var phase := "active"
var samples := []
func _initialize():
	call_deferred("_run")
func _run():
	scene = load("res://main.tscn").instantiate()
	scene.save_path_override = ProjectSettings.globalize_path("res://../.cache/benchmark-no-save.json")
	root.add_child(scene)
	await process_frame
	await process_frame
	scene._restart_engine()
	scene.engine.heat = 2500
	scene.engine.pressure_reserve = 15000
	scene.engine.speed = 150
	scene.engine.cycle_lignite()
	scene.engine.cycle_anthracite()
	scene.engine.set_regulator(200)
	scene._open_panel("map")
	await process_frame
	started = Time.get_ticks_msec()
	print("BENCH_PHASE active")
func _process(_delta):
	if scene == null or started == 0:
		return false
	if phase == "active":
		scene.session.paused = false
	if Time.get_ticks_msec() - started < 10000:
		return false
	print(JSON.stringify({"phase":phase,"fps":Engine.get_frames_per_second(),"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"memory_static":Performance.get_monitor(Performance.MEMORY_STATIC),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"cycles":scene.engine.cycles}))
	if phase == "paused":
		print("PASS: native oblique world active and paused measurement completed")
		quit(0)
	phase = "paused"
	scene.session.paused = true
	started = Time.get_ticks_msec()
	print("BENCH_PHASE paused")
	return false
