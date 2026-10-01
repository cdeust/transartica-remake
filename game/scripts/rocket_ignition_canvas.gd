extends Node2D

# MIT. Dedicated procedural surface keeps its shader off the scene artwork.
# Authored clip: left of BERTA controls(x211), above footer(y141).
const REGION := Rect2(20,0,189,141)
var surface := ShaderMaterial.new()

func _init() -> void:
	surface.shader = preload("res://shaders/rocket_ignition.gdshader")
	material = surface
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false

func configure(ignition, bounds: Rect2) -> void:
	visible = ignition.active
	position = bounds.position
	scale = Vector2.ONE*(bounds.size.x/320.0)
	surface.set_shader_parameter("visual_seconds",ignition.tick/50.0)
	surface.set_shader_parameter("nozzle",ignition.nozzle)
	queue_redraw()

func _draw() -> void:
	draw_rect(REGION,Color.WHITE)
