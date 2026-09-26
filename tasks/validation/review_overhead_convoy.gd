extends SceneTree

# Separate visual experiment, using the existing overhead prototype only.
# Owner requirement: each vehicle keeps its full screen dimensions at every cap.
class Convoy extends Node2D:
	var texture: Texture2D
	var entries: Array
	var phase := 0.0
	var paused := false
	var direction := 1.0
	# Review layout, not gameplay tuning: fit the existing 1600 x 1000 window.
	const CENTER := Vector2(800, 510)
	const RADIUS := 330.0
	const PIXEL_SCALE := 0.22
	const GAP := 5.0

	func _ready() -> void:
		var base := ProjectSettings.globalize_path("res://../output/imagegen/vehicles-overhead-prototype-v2")
		texture = ImageTexture.create_from_image(Image.load_from_file(base + ".png"))
		entries = JSON.parse_string(FileAccess.get_file_as_string(base + ".json"))
		_verify_rigid_dimensions()

	func _process(delta: float) -> void:
		if not paused:
			# One diagnostic revolution per minute; independent of render frame rate.
			phase += direction * TAU * delta / 60.0
		queue_redraw()

	func _unhandled_key_input(event: InputEvent) -> void:
		if not event is InputEventKey or not event.pressed or event.echo:
			return
		if event.keycode == KEY_SPACE:
			paused = not paused
		if event.keycode == KEY_R:
			direction *= -1.0

	func _pose(entry: Dictionary, front_angle: float) -> Dictionary:
		var r: Array = entry.region
		var region := Rect2(r[0], r[1], r[2], r[3])
		var length := region.size.y * PIXEL_SCALE
		# Circle chord identity: L = 2 R sin(angle / 2).
		# Equal chord length puts both endpoints on the track centerline.
		var span := 2.0 * asin(length / (2.0 * RADIUS))
		var rear_angle := front_angle - span
		var front := CENTER + Vector2.from_angle(front_angle) * RADIUS
		var rear := CENTER + Vector2.from_angle(rear_angle) * RADIUS
		return {"region": region, "center": (front + rear) * 0.5,
			"rotation": (front - rear).angle() - PI * 0.5,
			"next": rear_angle - GAP / RADIUS,
			"length": front.distance_to(rear)}

	func _verify_rigid_dimensions() -> void:
		var samples := 0
		for entry in entries:
			for heading in 8:
				var pose := _pose(entry, heading * TAU / 8.0)
				var region: Rect2 = pose.region
				assert(is_equal_approx(pose.length, region.size.y * PIXEL_SCALE))
				var transform := Transform2D(pose.rotation, pose.center).scaled_local(Vector2.ONE * PIXEL_SCALE)
				assert(is_equal_approx(transform.x.length(), PIXEL_SCALE))
				assert(is_equal_approx(transform.y.length(), PIXEL_SCALE))
				samples += 1
		print("PASS: %d rigid poses; both axes retain the same scale" % samples)

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1600, 1000), Color("20313c"))
		draw_string(ThemeDB.fallback_font, Vector2(35, 45), "PROTOTYPE SEPARE : convoi a gabarit constant", HORIZONTAL_ALIGNMENT_LEFT, -1, 24)
		draw_string(ThemeDB.fallback_font, Vector2(35, 80), "Espace : pause | R : inverser | Dessins proposes, non integres au jeu", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		# The loop is a test fixture, not the campaign map or a gameplay change.
		draw_arc(CENTER, RADIUS - 12, 0, TAU, 256, Color("91a7ac"), 3, true)
		draw_arc(CENTER, RADIUS + 12, 0, TAU, 256, Color("91a7ac"), 3, true)
		var angle := phase
		for entry in entries:
			var pose := _pose(entry, angle)
			var region: Rect2 = pose.region
			draw_set_transform(pose.center, pose.rotation, Vector2.ONE * PIXEL_SCALE)
			draw_texture_rect_region(texture, Rect2(-region.size * 0.5, region.size), region)
			draw_set_transform(Vector2.ZERO)
			angle = pose.next
		draw_string(ThemeDB.fallback_font, Vector2(570, 500), "6 vehicules, echelle fixe", HORIZONTAL_ALIGNMENT_LEFT, -1, 23)
		draw_string(ThemeDB.fallback_font, Vector2(570, 535), "Aucun changement de zoom", HORIZONTAL_ALIGNMENT_LEFT, -1, 19)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1600, 1000)
	root.content_scale_size = root.size
	root.title = "Transartica - prototype separe : convoi a gabarit constant"
	root.add_child(Convoy.new())
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../tasks/validation/overhead-convoy-loop.png"))
	print("READY: overhead convoy review; Space pauses, R reverses")
