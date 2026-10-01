extends SceneTree
# MIT. Run from isolated main-pack to prove absent original RGB/default availability.
func _initialize()->void:call_deferred("run")
func run()->void:
	var view=load("res://scripts/ecs_overview.gd").new()
	view.reference_pixels=false
	view.size=Vector2(1280,596)
	root.add_child(view)
	await process_frame
	assert(not FileAccess.file_exists("res://private-data/general-plan.json"))
	assert(not FileAccess.file_exists("res://../reference-private/general-plan.json"))
	assert(view.chart.available() and view.plan_texture==null)
	assert(view.chart.geometry.towns.size()==45 and view.chart.frame!=null)
	print("PASS: isolated exported PCK default authored overview works with original RGB absent")
	view.queue_free()
	await process_frame
	quit()
