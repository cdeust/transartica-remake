extends RefCounted

# MIT. Authored Noita-directed layers, never enlarged historical graphics.
# Composition follows private IFEBO capture: station blast, cloud banks, sunlight.
var storm: Texture2D
var restored: Texture2D
var effects: Texture2D


func load_art() -> void:
	storm = load("res://assets/campaign/sun-overcast.png")
	restored = load("res://assets/campaign/sun-restored.png")
	effects = load("res://assets/campaign/finale-effects.png")


func draw_on(screen: Control, sequence) -> void:
	var rectangle: Rect2 = screen.canvas_rect()
	screen.draw_texture_rect(storm, rectangle, false)
	var counter: int = sequence.tick - sequence.INTRO
	if counter >= 200:
		screen.draw_texture_rect(restored, rectangle, false)
	elif counter >= 0:
		# The visual grade is authored; palette changes use source rnd4 dispatch.
		var grades := [Color(1, 1, 1), Color(0.65, 0.72, 1), Color(1, 0.8, 0.55), Color(0.7, 0.6, 0.9)]
		screen.draw_texture_rect(storm, rectangle, false, grades[sequence.palette()])
	screen.begin_canvas()
	if counter < 0:
		var shot: int = sequence.shot()
		if shot in [37, 38, 39, 40]:
			var cell := 2 if shot == 37 else 3
			var extent := Vector2(26, 22) if shot == 37 else Vector2(39, 32)
			_effect(screen, Rect2(Vector2(123, 116) - extent / 2, extent), cell)
	else:
		var shifts: PackedInt32Array = sequence.clouds()
		for layer in 4:
			# IFEBO cloud handles7..10, mirrorX=175-x, source speeds4,3,2,1.
			var origin := Vector2(shifts[layer], layer * 6)
			_effect(screen, Rect2(origin, Vector2(175, 56)), layer % 2)
			_effect(screen, Rect2(Vector2(175 - shifts[layer], layer * 6), Vector2(-175, 56)), layer % 2)
	screen.draw_set_transform(Vector2.ZERO)


func _effect(screen: Control, destination: Rect2, cell: int) -> void:
	var half := effects.get_size() / 2
	var source := Rect2(Vector2(cell % 2, cell / 2) * half, half)
	screen.draw_texture_rect_region(effects, destination, source)
