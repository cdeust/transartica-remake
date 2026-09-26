extends SceneTree

# Diagnostic layout only. Uses the production renderer at zoom 1.
class Comparison extends Node2D:
	const Renderer = preload("res://scripts/train_renderer.gd")
	const Consist = preload("res://scripts/train_consist.gd")
	const Rails = preload("res://scripts/rail_network.gd")
	const World = preload("res://scripts/travel_world.gd")
	var renderer = Renderer.new()
	var kind := "sleeper"

	func _ready() -> void:
		renderer.load_assets()
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1600, 1000), Color("20313c"))
		var headings := [6, 3, 2, 1, 4, 7, 8, 9]
		var scale: float = World.WORLD_EAST.length() / renderer.texels_per_cell
		for index in headings.size():
			var heading: int = headings[index]
			var origin := Vector2(200 + (index % 4) * 400, 350 + (index / 4) * 460)
			var axis: Vector2 = Vector2(Rails.DELTAS[heading]).normalized() * Consist.LENGTHS[kind]
			var chord: Vector2 = World.WORLD_EAST * axis.x + World.WORLD_SOUTH * axis.y
			var front: Vector2 = origin + chord * 0.5
			var rear: Vector2 = origin - chord * 0.5
			draw_line(rear - chord, front + chord, Color("71868c"), 2)
			var frame: Dictionary = renderer.frame_for(kind, heading)
			draw_set_transform_matrix(renderer.registration(frame, front, rear, scale))
			draw_texture(frame.texture, Vector2.ZERO)
			draw_set_transform_matrix(Transform2D.IDENTITY)
			draw_circle(front, 3, Color.YELLOW)
			draw_circle(rear, 3, Color.YELLOW)
			draw_string(ThemeDB.fallback_font, origin + Vector2(-150, 75), "%s / cap %d / zoom 1" % [kind, heading], HORIZONTAL_ALIGNMENT_LEFT, -1, 20)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	OS.low_processor_usage_mode = false
	root.size = Vector2i(1600, 1000)
	root.content_scale_size = root.size
	root.add_child(Comparison.new())
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../tasks/validation/sleeper-eight-headings-directional-baseline.png"))
	quit()
