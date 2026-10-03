extends SceneTree

# MIT. Native renderer required: --path game --script res://tests/test_works_shared_panel.gd.
# Prepared UI regression, not campaign acceptance. Owner works capture7190
# showed a different bottom panel. Source: panel-layout.md common rows149..199.
var app
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Native renderer required for shared works panel pixels")
		quit(1)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	app = load("res://main.tscn").instantiate()
	app.play_startup_intro = false # game_boot.gd: prepared UI fixtures opt out.
	app.save_path_override = ProjectSettings.globalize_path("res://../.cache/works-panel/save.json")
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.session.paused = true
	check(app._boot.intro == null,"intro cannot obscure the tested panel")
	app._open_panel("room")
	for extent in [Vector2i(321, 201), Vector2i(1440, 900)]:
		root.size = extent
		await process_frame
		await process_frame
		var panel = app._boudoir_session.panel
		var normal: Image = await capture_panel(panel)
		app.works_dialog.kind = "crevasse"
		app.works_dialog._show(app.works_dialog._message(24), true)
		app._boudoir_session.refresh()
		await process_frame
		check(panel.visible, "same common panel remains visible during works at %s" % extent)
		var working: Image = await capture_panel(panel)
		check(normal.get_data() == working.get_data(), "works reuses exact common panel pixels at %s" % extent)
		check(app.works_dialog._yes.visible and app.works_dialog._no.visible, "source question keeps NO and OK controls")
		app.works_dialog.hide()
		app._boudoir_session.refresh()
		await process_frame
	app.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: works and normal room share identical live panel pixels and retain question controls")
	quit(0 if failures.is_empty() else 1)


func capture_panel(panel) -> Image:
	await process_frame
	RenderingServer.force_draw(true)
	var image: Image = root.get_texture().get_image()
	var bounds: Rect2 = panel.panel_rect()
	check(bounds.size.x > 0 and bounds.size.y > 0,"shared panel has a real viewport area")
	check(not image.is_empty(),"native viewport capture is nonempty")
	if bounds.size.x <= 0 or bounds.size.y <= 0 or image.is_empty():
		return Image.create(1,1,false,Image.FORMAT_RGBA8)
	# Logical rows149..199 fitted through the production shared-panel transform.
	var first := Vector2i(ceili(bounds.position.x), ceili(bounds.position.y))
	var last := Vector2i(floori(bounds.end.x), floori(bounds.end.y))
	return image.get_region(Rect2i(first, last - first))


func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
