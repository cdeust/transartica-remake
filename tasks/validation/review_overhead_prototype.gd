extends SceneTree

# Separate art review. Does not modify the game, renderer or player save.
class Comparison extends Node2D:
	var texture: Texture2D
	var entries: Array
	var selected := 2
	const HEADINGS := [6, 3, 2, 1, 4, 7, 8, 9]
	const Rails = preload("res://scripts/rail_network.gd")
	const World = preload("res://scripts/travel_world.gd")

	func _ready() -> void:
		var base := ProjectSettings.globalize_path("res://../output/imagegen/vehicles-overhead-prototype-v2")
		texture = ImageTexture.create_from_image(Image.load_from_file(base + ".png"))
		entries = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
		queue_redraw()

	func _unhandled_key_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and event.keycode >= KEY_1 and event.keycode <= KEY_6:
			selected = event.keycode - KEY_1
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1600, 1000), Color("20313c"))
		draw_string(ThemeDB.fallback_font, Vector2(35, 45), "PROTOTYPE SEPARE - touches 1 a 6 : changer de vehicule", HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		var entry: Dictionary = entries[selected]
		var r: Array = entry.region
		var region := Rect2(r[0], r[1], r[2], r[3])
		# Diagnostic scale fixed for all eight headings, never fitted per direction.
		var pixel_scale := 0.42
		for index in HEADINGS.size():
			var heading: int = HEADINGS[index]
			var origin := Vector2(200 + (index % 4) * 400, 290 + (index / 4) * 460)
			var world_axis := Vector2(Rails.DELTAS[heading])
			var axis := (World.WORLD_EAST * world_axis.x + World.WORLD_SOUTH * world_axis.y).normalized()
			var rotation := axis.angle() - PI * 0.5
			draw_line(origin - axis * 150, origin + axis * 150, Color("71868c"), 2)
			draw_set_transform(origin, rotation, Vector2.ONE * pixel_scale)
			draw_texture_rect_region(texture, Rect2(-region.size * 0.5, region.size), region)
			draw_rect(Rect2(-region.size * 0.5, region.size), Color("9eaca8"), false, 1)
			draw_set_transform(Vector2.ZERO)
			draw_string(ThemeDB.fallback_font, origin + Vector2(-145, 150), "%s / %d / %.1f x %.1f px" % [entry.kind, heading, region.size.y * pixel_scale, region.size.x * pixel_scale], HORIZONTAL_ALIGNMENT_LEFT, -1, 17)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	OS.low_processor_usage_mode = false
	root.size = Vector2i(1600, 1000)
	root.content_scale_size = root.size
	root.title = "Transartica - prototype : meme gabarit dans les huit directions"
	root.add_child(Comparison.new())
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../tasks/validation/overhead-prototype-eight-headings.png"))
	print("READY: separate overhead art prototype, keys 1-6")
	OS.low_processor_usage_mode = true
