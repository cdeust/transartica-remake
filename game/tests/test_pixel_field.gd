extends SceneTree

const PixelFieldScript = preload("res://scripts/pixel_field.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_test_determinism(failures)
	_test_directions_and_bounds(failures)
	_test_conservation_and_fading(failures)
	_test_render(failures)
	if failures.is_empty():
		print("PASS: pixel field determinism, gas rise, snow fall, conservation, fading and native render")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _scene(seed_value: int):
	var field = PixelFieldScript.new(96, 64, seed_value)
	field.wind = 1
	field.burst(Vector2i(48, 40), 60)
	field.emit(PixelFieldScript.SNOW, Vector2i(20, 5), 80, 6)
	field.emit(PixelFieldScript.STEAM, Vector2i(70, 50), 50, 4)
	return field


func _test_determinism(failures: Array[String]) -> void:
	var first = _scene(7)
	var second = _scene(7)
	for cycle in 40:
		first.step()
		second.step()
	_check(first.cells() == second.cells(), "same seed and inputs give identical fields", failures)
	var other = _scene(8)
	for cycle in 40:
		other.step()
	_check(other.cells() != first.cells(), "a different seed changes the field", failures)


func _test_directions_and_bounds(failures: Array[String]) -> void:
	var field = PixelFieldScript.new(64, 64, 3)
	field.emit(PixelFieldScript.SMOKE, Vector2i(32, 50), 60, 4)
	field.emit(PixelFieldScript.SNOW, Vector2i(32, 10), 60, 4)
	var smoke_before: float = field.mean_row(PixelFieldScript.SMOKE)
	var snow_before: float = field.mean_row(PixelFieldScript.SNOW)
	for cycle in 24:
		field.step()
	_check(field.mean_row(PixelFieldScript.SMOKE) < smoke_before - 5.0, "smoke rises", failures)
	_check(field.mean_row(PixelFieldScript.SNOW) > snow_before + 5.0, "snow falls", failures)
	for cycle in 200:
		field.step()
	_check(field.cells().size() == 64 * 64, "field keeps its size", failures)
	_check(field.count(PixelFieldScript.SNOW) == 60, "snow never leaves the field", failures)
	_check(field.mean_row(PixelFieldScript.SNOW) > 60.0, "snow settles on the bottom edge", failures)
	for index in 12:
		field.launch(PixelFieldScript.SNOW, Vector2(20.0 + index, 30.0), Vector2(0.8, -1.5))
	for cycle in 60:
		field.step()
	_check(field.airborne() == 0 and field.total(PixelFieldScript.SNOW) == 72, "thrown snow lands and is conserved", failures)


func _test_conservation_and_fading(failures: Array[String]) -> void:
	var field = _scene(11)
	var snow: int = field.count(PixelFieldScript.SNOW)
	var debris: int = field.total(PixelFieldScript.DEBRIS)
	_check(field.total(PixelFieldScript.SPARK) > 0 and field.count(PixelFieldScript.SMOKE) > 0, "burst emits sparks and smoke", failures)
	_check(field.airborne() > 0, "burst throws free particles", failures)
	field.step()
	field.step()
	_check(field.airborne() > 0, "debris stays airborne for a few cycles", failures)
	for cycle in 300:
		field.step()
	_check(field.count(PixelFieldScript.SNOW) == snow, "snow count is conserved", failures)
	_check(field.airborne() == 0, "every particle lands or fades", failures)
	_check(field.count(PixelFieldScript.DEBRIS) == debris, "debris count is conserved through flight and landing", failures)
	_check(field.total(PixelFieldScript.SPARK) == 0, "sparks fade", failures)
	_check(field.count(PixelFieldScript.SMOKE) == 0 and field.count(PixelFieldScript.STEAM) == 0, "gases fade", failures)


func _test_render(failures: Array[String]) -> void:
	var field = _scene(5)
	for cycle in 3:
		field.step()
	var texture: ImageTexture = field.render()
	var glow: ImageTexture = field.render_glow()
	_check(texture.get_size() == Vector2(96, 64), "render stays at native grid resolution", failures)
	_check(glow.get_size() == Vector2(96, 64), "glow stays at native grid resolution", failures)
	var image := texture.get_image()
	var lit := 0
	var glow_image := glow.get_image()
	for y in 64:
		for x in 96:
			if glow_image.get_pixel(x, y).r > 0.0:
				lit += 1
	_check(lit > 0, "hot debris and sparks emit light", failures)
	_check(image.get_pixel(0, 0).a == 0.0, "empty cells stay transparent", failures)


func _check(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
