extends Control
class_name SurveyCabVignette

# Original hand-authored palette and 480x144 drawing grid; no historical game art is used.
const ART_SIZE := Vector2(480, 144) # source: tasks/visual-design.md; presentation grid
const SKY := Color("#101f2b") # source: tasks/visual-design.md; original winter palette
const DISTANT_ICE := Color("#203542") # source: tasks/visual-design.md; original winter palette
const MID_ICE := Color("#2c4652") # source: tasks/visual-design.md; original winter palette
const SNOW := Color("#d8e5df") # source: tasks/visual-design.md; original winter palette
const SNOW_SHADE := Color("#a9c2c2") # source: tasks/visual-design.md; original winter palette
const IRON := Color("#182832") # source: tasks/visual-design.md; original locomotive palette
const IRON_LIGHT := Color("#506771") # source: tasks/visual-design.md; original locomotive palette
const RAIL_STEEL := Color("#83999b") # source: tasks/visual-design.md; original track palette
const BOILER := Color("#3f5961") # source: tasks/visual-design.md; original locomotive palette
const RUST := Color("#a85237") # source: tasks/visual-design.md; original locomotive palette
const BRASS := Color("#d59a4d") # source: tasks/visual-design.md; original locomotive palette
const WINDOW := Color("#f3c970") # source: tasks/visual-design.md; original lighting palette
const WHEEL_CYCLE := TAU # One full turn for decorative wheel motion.

var _phase := 0.0
var _motion_speed := 0.0
var _flakes: Array[Vector2] = []


func _ready() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(ART_SIZE.x, maxf(custom_minimum_size.y, ART_SIZE.y))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42917 # Fixed seed keeps authored snow placement repeatable.
	for index in 36:
		_flakes.append(Vector2(rng.randi_range(0, 479), rng.randi_range(4, 108)))


func _process(delta: float) -> void:
	if _motion_speed <= 0.0:
		return
	_phase = fposmod(_phase + delta * 1.5 * _motion_speed, WHEEL_CYCLE)
	for index in _flakes.size():
		_flakes[index].x = fposmod(_flakes[index].x - delta * (8.0 + float(index % 5) * 2.0) * _motion_speed, ART_SIZE.x)
		_flakes[index].y = 4.0 + fposmod(_flakes[index].y - 4.0 + delta * 3.0 * _motion_speed, 108.0)
	queue_redraw()


func set_motion(speed_ratio: float) -> void:
	_motion_speed = clampf(speed_ratio, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var pixel_scale := maxf(1.0, floorf(minf(size.x / ART_SIZE.x, size.y / ART_SIZE.y)))
	var margin := ((size - ART_SIZE * pixel_scale) * 0.5).floor()
	draw_set_transform(margin, 0.0, Vector2.ONE * pixel_scale)
	_draw_sky()
	_draw_glacial_horizon()
	_draw_snow_banks()
	_draw_track()
	_draw_wheels()
	_draw_locomotive()
	_draw_wagon()
	_draw_rods()
	_draw_steam()
	_draw_snow()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_scene_frame(margin, ART_SIZE * pixel_scale)


func _draw_scene_frame(margin: Vector2, extent: Vector2) -> void:
	# source: tasks/visual-design.md; frame masks art outside its integer-scale canvas.
	var surround := Color("#0c1720")
	draw_rect(Rect2(0, 0, size.x, margin.y), surround)
	draw_rect(Rect2(0, margin.y + extent.y, size.x, margin.y), surround)
	draw_rect(Rect2(0, 0, margin.x, size.y), surround)
	draw_rect(Rect2(margin.x + extent.x, 0, size.x, size.y), surround)
	draw_rect(Rect2(margin, extent), Color("#40555f"), false, 1.0)


func _draw_sky() -> void:
	draw_rect(Rect2(Vector2.ZERO, ART_SIZE), SKY)
	draw_rect(Rect2(0, 26, ART_SIZE.x, 12), Color("#172d39"))
	draw_rect(Rect2(0, 42, ART_SIZE.x, 4), Color("#203844"))


func _draw_glacial_horizon() -> void:
	var far_ridge := PackedInt32Array([16, 21, 19, 26, 24, 17, 18, 28, 31, 25, 20, 18, 23, 29, 27, 21, 18, 24, 30, 26, 19, 16, 22, 28, 25, 18, 20, 27, 24, 17])
	var near_ridge := PackedInt32Array([29, 34, 31, 37, 33, 25, 27, 38, 43, 36, 30, 28, 35, 42, 39, 32, 27, 34, 41, 38, 31, 26, 33, 40, 36, 28, 30, 39, 34, 27])
	_draw_ridge_layer(93, far_ridge, DISTANT_ICE)
	_draw_ridge_highlights(93, far_ridge)
	_draw_ridge_layer(102, near_ridge, MID_ICE)
	_draw_ridge_highlights(102, near_ridge)
	_draw_ice_cracks()


func _draw_ridge_layer(base_y: int, heights: PackedInt32Array, color: Color) -> void:
	for index in heights.size():
		var top := base_y - heights[index]
		draw_rect(Rect2(index * 16, top, 16, ART_SIZE.y - top), color)


func _draw_ridge_highlights(base_y: int, heights: PackedInt32Array) -> void:
	for index in heights.size():
		var top := base_y - heights[index]
		var ledge := 4 + (index * 7 % 9)
		draw_rect(Rect2(index * 16, top, ledge, 2), SNOW_SHADE)
		if index % 4 == 1:
			draw_rect(Rect2(index * 16 + 8, top + 5, 5, 2), MID_ICE)


func _draw_ice_cracks() -> void:
	for index in 13:
		var x := 11 + index * 37
		var y := 71 + index * 11 % 20
		draw_rect(Rect2(x, y, 8 + index % 5 * 3, 2), SNOW_SHADE)
		draw_rect(Rect2(x + 3, y + 2, 2, 4 + index % 3 * 2), DISTANT_ICE)


func _draw_snow_banks() -> void:
	draw_rect(Rect2(0, 92, ART_SIZE.x, 52), Color("#738d91"))
	draw_rect(Rect2(0, 96, 480, 17), SNOW_SHADE)
	draw_rect(Rect2(0, 100, 480, 10), SNOW)
	draw_rect(Rect2(0, 105, 103, 5), Color("#eef1e5"))
	draw_rect(Rect2(391, 104, 89, 6), Color("#eef1e5"))
	_draw_shelf_strata()
	_draw_snow_ripples()


func _draw_shelf_strata() -> void:
	for index in 12:
		var x := index * 43 - 9
		var width := 25 + index * 17 % 30
		var y := 113 + index * 7 % 14
		draw_rect(Rect2(x, y, width, 3), SNOW_SHADE)
		draw_rect(Rect2(x + 5, y + 3, width - 8, 2), Color("#405b66"))
	for index in 8:
		var x := 17 + index * 61
		draw_rect(Rect2(x, 98 + index % 3 * 4, 11, 2), SNOW)


func _draw_snow_ripples() -> void:
	for index in 16:
		var x := (index * 41 + int(_phase * 3.0 * _motion_speed)) % 480
		var y := 89 + index * 13 % 19
		var width := 7 + index % 4 * 3
		draw_rect(Rect2(x, y, width, 1), SNOW)


func _draw_track() -> void:
	draw_rect(Rect2(0, 117, 480, 22), Color("#405963"))
	draw_rect(Rect2(0, 121, 480, 13), Color("#344b55"))
	for index in 20:
		var x := index * 26 - 8
		draw_rect(Rect2(x, 116, 16, 15), IRON)
		draw_rect(Rect2(x + 2, 117, 12, 2), IRON_LIGHT)
		draw_rect(Rect2(x + 3, 126, 10, 2), Color("#263c47"))
		draw_rect(Rect2(x + 5, 118, 2, 2), RAIL_STEEL)
		draw_rect(Rect2(x + 11, 118, 2, 2), RAIL_STEEL)
	draw_rect(Rect2(0, 114, 480, 4), IRON)
	draw_rect(Rect2(0, 114, 480, 1), RAIL_STEEL)
	draw_rect(Rect2(0, 124, 480, 4), IRON)
	draw_rect(Rect2(0, 124, 480, 1), RAIL_STEEL)
	draw_rect(Rect2(0, 128, 480, 9), Color("#263d48"))
	for index in 48:
		var x := index * 10
		var y := 130 + index * 7 % 6
		draw_rect(Rect2(x, y, 4, 2), SNOW_SHADE if index % 3 == 0 else MID_ICE)


func _draw_wheels() -> void:
	for center_x in [119, 167, 215, 263]:
		_draw_spoked_wheel(Vector2(center_x, 99), 15.0, _phase)
	_draw_spoked_wheel(Vector2(354, 100), 11.0, _phase)
	_draw_spoked_wheel(Vector2(397, 100), 11.0, _phase)


func _draw_spoked_wheel(center: Vector2, radius: float, phase: float) -> void:
	draw_circle(center, radius + 3, IRON)
	draw_arc(center, radius + 1, 0.0, TAU, 24, IRON_LIGHT, 2.0, false)
	draw_arc(center, radius - 3, 0.0, TAU, 20, BRASS, 1.0, false)
	for spoke in 8:
		var angle := phase + float(spoke) * WHEEL_CYCLE / 8.0
		var tip := center + Vector2(cos(angle), sin(angle)) * (radius - 4.0)
		draw_line(center, tip.round(), SNOW_SHADE, 1.5, false)
	draw_circle(center, 3.0, BRASS)
	draw_circle(center, 1.0, IRON)


func _draw_locomotive() -> void:
	_draw_frame()
	_draw_boiler()
	_draw_cab()
	_draw_chimney()
	_draw_front_end()
	_draw_piping()


func _draw_frame() -> void:
	draw_rect(Rect2(99, 82, 207, 9), IRON)
	draw_rect(Rect2(103, 82, 195, 3), BRASS)
	draw_rect(Rect2(107, 90, 184, 4), RUST)
	draw_rect(Rect2(110, 94, 174, 3), IRON_LIGHT)
	draw_rect(Rect2(91, 84, 18, 7), RUST)
	for x in [112, 154, 202, 250, 289]:
		draw_rect(Rect2(x, 84, 3, 4), BRASS)


func _draw_boiler() -> void:
	draw_rect(Rect2(125, 42, 132, 38), BOILER)
	draw_circle(Vector2(126, 61), 19, BOILER)
	draw_circle(Vector2(252, 61), 19, BOILER)
	draw_rect(Rect2(140, 34, 97, 13), IRON_LIGHT)
	draw_rect(Rect2(145, 32, 87, 4), SNOW_SHADE)
	draw_rect(Rect2(140, 48, 105, 2), Color("#829599"))
	draw_rect(Rect2(138, 72, 112, 3), RUST)
	for x in [148, 225]:
		draw_rect(Rect2(x, 39, 4, 39), BRASS)
		draw_rect(Rect2(x + 1, 40, 2, 4), SNOW)
	for x in [160, 183, 207, 239]:
		draw_rect(Rect2(x, 51, 3, 3), BRASS)
		draw_rect(Rect2(x + 1, 50, 1, 1), SNOW)


func _draw_cab() -> void:
	draw_rect(Rect2(258, 34, 45, 48), RUST)
	draw_rect(Rect2(255, 29, 53, 7), IRON)
	draw_rect(Rect2(261, 36, 39, 3), BRASS)
	draw_rect(Rect2(267, 42, 23, 19), WINDOW)
	draw_rect(Rect2(270, 45, 17, 13), Color("#fff0b2"))
	draw_rect(Rect2(277, 42, 3, 19), RUST)
	draw_rect(Rect2(264, 62, 34, 4), IRON_LIGHT)
	draw_rect(Rect2(264, 67, 34, 12), RUST)
	draw_rect(Rect2(270, 70, 21, 3), BRASS)
	draw_rect(Rect2(295, 48, 4, 4), BRASS)


func _draw_chimney() -> void:
	draw_rect(Rect2(153, 30, 21, 7), IRON)
	draw_rect(Rect2(158, 20, 11, 13), IRON_LIGHT)
	draw_rect(Rect2(154, 17, 20, 5), IRON)
	draw_rect(Rect2(151, 15, 26, 3), BRASS)
	draw_rect(Rect2(155, 22, 15, 2), SNOW_SHADE)


func _draw_front_end() -> void:
	draw_rect(Rect2(111, 49, 17, 26), IRON_LIGHT)
	draw_rect(Rect2(115, 53, 10, 15), IRON)
	draw_rect(Rect2(116, 57, 8, 4), WINDOW)
	draw_rect(Rect2(103, 66, 10, 5), BRASS)
	draw_rect(Rect2(98, 72, 14, 4), IRON)
	draw_rect(Rect2(89, 77, 16, 5), RUST)
	draw_rect(Rect2(91, 82, 5, 5), IRON)
	for step in 4:
		draw_rect(Rect2(88 - step * 4, 85 + step * 2, 4, 2), IRON_LIGHT)


func _draw_piping() -> void:
	draw_rect(Rect2(155, 28, 61, 3), BRASS)
	draw_rect(Rect2(160, 25, 3, 7), BRASS)
	draw_rect(Rect2(208, 24, 3, 8), BRASS)
	draw_rect(Rect2(130, 39, 14, 3), IRON)
	draw_rect(Rect2(133, 36, 3, 4), BRASS)
	draw_rect(Rect2(245, 37, 11, 4), IRON)
	draw_rect(Rect2(237, 34, 3, 6), BRASS)
	draw_rect(Rect2(245, 65, 12, 3), BRASS)
	draw_rect(Rect2(253, 61, 3, 7), BRASS)
	draw_rect(Rect2(126, 56, 6, 9), IRON_LIGHT)
	draw_rect(Rect2(128, 58, 2, 4), BRASS)


func _draw_wagon() -> void:
	draw_rect(Rect2(320, 56, 104, 31), IRON_LIGHT)
	draw_rect(Rect2(317, 51, 111, 7), IRON)
	draw_rect(Rect2(322, 59, 99, 3), BRASS)
	draw_rect(Rect2(325, 64, 91, 18), Color("#344e58"))
	draw_rect(Rect2(331, 67, 77, 3), RUST)
	draw_rect(Rect2(341, 63, 3, 19), IRON_LIGHT)
	draw_rect(Rect2(392, 63, 3, 19), IRON_LIGHT)
	_draw_coal_load()
	draw_rect(Rect2(306, 82, 35, 5), IRON)
	draw_rect(Rect2(306, 83, 31, 2), BRASS)


func _draw_coal_load() -> void:
	for index in 11:
		var x := 326 + index * 8
		var height := 7 + (index * 11 % 8)
		draw_rect(Rect2(x, 55 - height, 7, height), IRON)
		draw_rect(Rect2(x + 1, 54 - height, 3, 2), IRON_LIGHT)


func _draw_rods() -> void:
	var crank := Vector2(cos(_phase), sin(_phase)) * 8.0
	var first := Vector2(119, 99) + crank
	var last := Vector2(263, 99) + crank
	draw_line(first.round(), last.round(), IRON, 4.0, false)
	draw_line(first.round(), last.round(), BRASS, 1.0, false)
	for x in [167, 215]:
		var pin := Vector2(x, 99) + crank
		draw_circle(pin.round(), 3.0, BRASS)
	var piston := Vector2(108, 78) + Vector2(0, sin(_phase) * 2.0)
	draw_line(Vector2(157, 80), piston.round(), IRON, 3.0, false)
	draw_line(Vector2(157, 80), piston.round(), SNOW_SHADE, 1.0, false)


func _draw_steam() -> void:
	var drift := fposmod(_phase * 12.0, 68.0)
	var alpha := 0.32 + 0.24 * sin(_phase * 0.7) # source: tasks/visual-design.md; decorative opacity choice.
	var steam := Color(SNOW_SHADE, alpha)
	var first_x := 155.0 - drift
	var first_y := 12.0 - fposmod(_phase * 8.0, 19.0)
	draw_rect(Rect2(first_x, first_y, 7, 3), steam)
	draw_rect(Rect2(first_x - 3, first_y - 3, 8, 3), steam)
	draw_rect(Rect2(first_x - 9, first_y - 6, 7, 3), steam)
	var second_x := first_x - 35.0
	draw_rect(Rect2(second_x, first_y + 8, 6, 3), Color(SNOW_SHADE, alpha * 0.7))
	draw_rect(Rect2(second_x - 4, first_y + 5, 7, 3), Color(SNOW_SHADE, alpha * 0.7))


func _draw_snow() -> void:
	for index in _flakes.size():
		var point := _flakes[index].round()
		var dimensions := Vector2(4, 1) if index % 3 == 0 else Vector2(2, 1)
		draw_rect(Rect2(point, dimensions), SNOW)
	var pulse := Color(WINDOW, 0.18 + 0.12 * sin(_phase * 1.4)) # Original decorative lamp glow.
	draw_rect(Rect2(111, 52, 9, 8), pulse)
	draw_rect(Rect2(114, 54, 4, 4), WINDOW)
