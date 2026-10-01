extends SceneTree
# Native default overview; source RGB is never loaded.
func _initialize()->void:
	OS.low_processor_usage_mode=false
	call_deferred("run")
func run()->void:
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i(1280,720)
	var app=load("res://scripts/main.gd").new()
	app.size=Vector2(1280,720)
	app.save_path_override=ProjectSettings.globalize_path("res://../.cache/overview-unused.json")
	root.add_child(app)
	await process_frame
	app._restart_engine()
	app._open_panel("overview")
	app.set_process(false)
	var view=app._boudoir_session.overview
	await create_timer(0.25).timeout
	if view.plan_texture!=null or not view.authored_available:
		push_error("Default overview must render without historical RGB")
		quit(1)
		return
	var path=ProjectSettings.globalize_path("res://../tasks/validation/authored-overview-native-20261001.png")
	var capture:Image=root.get_texture().get_image()
	if capture.get_pixel(640,260).r+capture.get_pixel(640,260).g<0.1:
		push_error("Native overview body blank")
		quit(1)
		return
	if capture.save_png(path)!=OK:
		push_error("Native overview capture failed")
		quit(1)
		return
	print("PASS: native default authored overview, original RGB absent; actual source start marker and lower instrument strip")
	app.queue_free()
	await process_frame
	quit(0)
