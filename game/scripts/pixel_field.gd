extends RefCounted
class_name PixelField

# Local falling-sand field for smoke, steam, snow, sparks and debris.
# Inspired by, not a reproduction of, Noita. Rules borrowed from the published
# description of its simulation (Petri Purho, GDC 2019 "Exploring the Tech and
# Design of Noita", https://www.youtube.com/watch?v=prXuyMCgbTc ; summaries:
# https://80.lv/articles/noita-a-game-based-on-falling-sand-simulation and
# https://braindump.jethro.dev/posts/gdc_vault_exploring_the_tech_and_design_of_noita/):
# falling cells try down then sideways and update bottom-up; gases are the
# inverse (up then sideways); fast material leaves the grid as a free particle
# and becomes a cell again where it lands. Noita's 64x64 chunks, dirty rects and checkerboard
# threading scale a whole world; they are deliberately absent from this local
# emitter. GDScript per-cell loops suit a ~20k-cell field stepped once per
# simulation cycle, not a full-scene field (that would need a shader or GDExtension).
#
# The caller owns time: step() is called from the simulation clock, never from
# _process, so identical seeds and inputs give identical fields at any frame rate.
# render() and render_glow() return native-resolution textures; draw them scaled by
# an integer factor with TEXTURE_FILTER_NEAREST, the glow with an additive blend.
# Presentation only: no original game rule is encoded here.

enum { EMPTY, SMOKE, STEAM, SNOW, SPARK, DEBRIS }

const LIFETIME := {SMOKE: 90, STEAM: 40, SPARK: 24} # authored: cycles before a gas or spark fades.
const MAX_HEAT := 255
const HEAT_DECAY := 6 # authored: ember glow fades within ~40 cycles.
const GRAVITY := {DEBRIS: 0.22, SPARK: 0.07, SNOW: 0.15} # authored: cells per cycle squared for free particles.
const RISE_CHANCE := {SMOKE: 0.55, STEAM: 0.85} # authored: smoke lingers, steam climbs fast.
const SPREAD_CHANCE := 0.35 # authored: gases try sideways first this often, so plumes widen.
const PALETTES := {
	SMOKE: [Color("#3b4247"), Color("#474f55"), Color("#565e63")],
	STEAM: [Color("#c9d6dc"), Color("#dbe5ea"), Color("#b7c6ce")],
	SNOW: [Color("#e9f1f5"), Color("#d3e2ea"), Color("#f7fbfd")],
	SPARK: [Color("#ffd27a"), Color("#ffb347"), Color("#fff1c2")],
	DEBRIS: [Color("#2a2f33"), Color("#3d3530"), Color("#51483f")],
} # source: authored steel, ash and ice palette matching the travel scene.

var width: int
var height: int
var wind := 0 # -1, 0 or 1: lateral bias for gases and snow.
var _cells := PackedByteArray()
var _age := PackedByteArray()
var _heat := PackedByteArray()
var _shade := PackedByteArray()
var _moved := PackedByteArray()
var _rng := RandomNumberGenerator.new()
# Free particles (parallel arrays): position and velocity in cells, material, heat, age.
var _px := PackedFloat32Array()
var _py := PackedFloat32Array()
var _vx := PackedFloat32Array()
var _vy := PackedFloat32Array()
var _pmat := PackedByteArray()
var _pheat := PackedByteArray()
var _page := PackedByteArray()


func _init(field_width: int = 192, field_height: int = 108, seed_value: int = 1) -> void:
	width = field_width
	height = field_height
	var total := width * height
	# Packed arrays are values: resize each member directly, never through a list.
	_cells.resize(total)
	_age.resize(total)
	_heat.resize(total)
	_shade.resize(total)
	_moved.resize(total)
	_cells.fill(EMPTY)
	_age.fill(0)
	_heat.fill(0)
	_shade.fill(0)
	_moved.fill(0)
	_rng.seed = seed_value


func material_at(cell: Vector2i) -> int:
	return _cells[_index(cell.x, cell.y)] if _inside(cell.x, cell.y) else EMPTY


func count(material: int) -> int:
	return _cells.count(material)


# Cells plus airborne particles of this material.
func total(material: int) -> int:
	return _cells.count(material) + _pmat.count(material)


func airborne() -> int:
	return _pmat.size()


func cells() -> PackedByteArray:
	var snapshot := _cells.duplicate()
	for index in _pmat.size():
		var x := int(_px[index])
		var y := int(_py[index])
		if _inside(x, y):
			snapshot[_index(x, y)] = _pmat[index] | 0x80
	return snapshot


func mean_row(material: int) -> float:
	var total := 0.0
	var found := 0
	for index in _cells.size():
		if _cells[index] == material:
			total += floorf(float(index) / width)
			found += 1
	return total / found if found > 0 else -1.0


# Places up to `amount` cells of `material` in empty cells within `radius`.
func emit(material: int, center: Vector2i, amount: int, radius: int = 2, heat: int = 0) -> int:
	var placed := 0
	for attempt in amount * 3:
		if placed >= amount:
			break
		var x := center.x + _rng.randi_range(-radius, radius)
		var y := center.y + _rng.randi_range(-radius, radius)
		if not _inside(x, y) or _cells[_index(x, y)] != EMPTY:
			continue
		var index := _index(x, y)
		_cells[index] = material
		_age[index] = 0
		_heat[index] = clampi(heat, 0, MAX_HEAT)
		_shade[index] = _rng.randi_range(0, 2)
		placed += 1
	return placed


# Authored explosion recipe (FIDELITE.md, 26 September: Noita-inspired debris,
# smoke and light, no original explosion sprite).
func burst(center: Vector2i, strength: int = 40) -> void:
	for index in strength:
		launch(DEBRIS, Vector2(center), _upward_velocity(1.2, 3.2), MAX_HEAT)
	for index in strength / 2:
		launch(SPARK, Vector2(center), _upward_velocity(1.5, 4.0), MAX_HEAT)
	emit(SMOKE, center + Vector2i(0, -2), strength, 5)


func launch(material: int, position: Vector2, velocity: Vector2, heat: int = 0) -> void:
	_px.append(position.x)
	_py.append(position.y)
	_vx.append(velocity.x)
	_vy.append(velocity.y)
	_pmat.append(material)
	_pheat.append(clampi(heat, 0, MAX_HEAT))
	_page.append(0)


func _upward_velocity(minimum: float, maximum: float) -> Vector2:
	# authored: a half-disc fan, biased upward so blasts throw debris into the air.
	var angle := _rng.randf_range(PI * 1.05, PI * 1.95)
	return Vector2.from_angle(angle) * _rng.randf_range(minimum, maximum)


func step() -> void:
	_moved.fill(0)
	_step_particles()
	# Falling cells: bottom-up so a column falls together in one step.
	for y in range(height - 1, -1, -1):
		for x in _row_order():
			var index := _index(x, y)
			var material := _cells[index]
			if material == SNOW or material == DEBRIS or material == SPARK:
				if _moved[index] == 0:
					_step_falling(x, y, material)
	# Rising cells: top-down, the inverse rule.
	for y in height:
		for x in _row_order():
			var index := _index(x, y)
			var material := _cells[index]
			if (material == SMOKE or material == STEAM) and _moved[index] == 0:
				_step_rising(x, y)
	_age_cells()


func _row_order() -> Array:
	# Alternating scan direction avoids a systematic sideways drift.
	var order := range(width)
	if _rng.randi() % 2 == 0:
		order.reverse()
	return order


func _step_falling(x: int, y: int, material: int) -> void:
	var side := _pick_side()
	var drift := wind if material == SNOW and _rng.randf() < 0.3 else 0 # authored: snow drifts with the wind.
	var targets := [Vector2i(x + drift, y + 1), Vector2i(x + side, y + 1), Vector2i(x - side, y + 1)]
	for target in targets:
		if _try_move(x, y, target.x, target.y):
			return


func _step_rising(x: int, y: int) -> void:
	var side := _pick_side()
	if _rng.randf() < SPREAD_CHANCE:
		_try_move(x, y, x + side, y)
		return
	if _rng.randf() >= RISE_CHANCE[_cells[_index(x, y)]]:
		return
	var targets := [Vector2i(x + wind, y - 1), Vector2i(x + side, y - 1), Vector2i(x - side, y - 1), Vector2i(x + side, y)]
	for target in targets:
		if _try_move(x, y, target.x, target.y):
			return


func _pick_side() -> int:
	if wind != 0 and _rng.randf() < 0.6: # authored: wind biases, but does not fix, the sideways choice.
		return wind
	return 1 if _rng.randi() % 2 == 0 else -1


func _try_move(x: int, y: int, to_x: int, to_y: int) -> bool:
	if not _inside(to_x, to_y):
		return false
	var from := _index(x, y)
	var to := _index(to_x, to_y)
	if _cells[to] != EMPTY:
		return false
	_cells[to] = _cells[from]
	_age[to] = _age[from]
	_heat[to] = _heat[from]
	_shade[to] = _shade[from]
	_cells[from] = EMPTY
	_age[from] = 0
	_heat[from] = 0
	_shade[from] = 0
	_moved[to] = 1
	return true


# Ballistic motion sampled cell by cell; a particle that meets a filled cell or the
# field border rejoins the grid at its last free cell (sparks die instead).
func _step_particles() -> void:
	var index := 0
	while index < _pmat.size():
		var material := _pmat[index]
		_vy[index] += GRAVITY.get(material, GRAVITY[DEBRIS])
		_page[index] = mini(255, _page[index] + 1)
		_pheat[index] = maxi(0, _pheat[index] - HEAT_DECAY / 2)
		var start := Vector2(_px[index], _py[index])
		var velocity := Vector2(_vx[index], _vy[index])
		var samples := maxi(1, ceili(velocity.length()))
		var landed := false
		var last := start
		for sample in samples:
			var next := start + velocity * float(sample + 1) / samples
			var cell := Vector2i(floori(next.x), floori(next.y))
			if not _inside(cell.x, cell.y) or _is_solid(_cells[_index(cell.x, cell.y)]):
				landed = true
				break
			last = next
		_px[index] = last.x
		_py[index] = last.y
		var expired: bool = material == SPARK and _page[index] >= LIFETIME[SPARK]
		if landed or expired:
			if material != SPARK:
				_settle(index, Vector2i(floori(last.x), floori(last.y)))
			_remove_particle(index)
		else:
			index += 1


func _settle(particle: int, cell: Vector2i) -> void:
	cell = Vector2i(clampi(cell.x, 0, width - 1), clampi(cell.y, 0, height - 1))
	# Search upward for a cell without solid material; gas there is displaced.
	while cell.y >= 0 and _is_solid(_cells[_index(cell.x, cell.y)]):
		cell.y -= 1
	if cell.y < 0:
		return # Known loss: a column solid up to the top edge drops the particle (untested edge case).
	var target := _index(cell.x, cell.y)
	_cells[target] = _pmat[particle]
	_heat[target] = _pheat[particle]
	_age[target] = 0
	_shade[target] = _rng.randi_range(0, 2)
	_moved[target] = 1


func _is_solid(material: int) -> bool:
	return material == SNOW or material == DEBRIS


func _remove_particle(index: int) -> void:
	_px.remove_at(index)
	_py.remove_at(index)
	_vx.remove_at(index)
	_vy.remove_at(index)
	_pmat.remove_at(index)
	_pheat.remove_at(index)
	_page.remove_at(index)


func _age_cells() -> void:
	for index in _cells.size():
		var material := _cells[index]
		if material == EMPTY:
			continue
		_heat[index] = maxi(0, _heat[index] - HEAT_DECAY)
		if not LIFETIME.has(material):
			continue
		_age[index] = mini(255, _age[index] + 1)
		# Randomised lifetime keeps plumes from vanishing in one frame.
		if _age[index] >= LIFETIME[material] and _rng.randf() < 0.25:
			_cells[index] = EMPTY
			_age[index] = 0
			_heat[index] = 0


func render() -> ImageTexture:
	var data := PackedByteArray()
	data.resize(width * height * 4)
	for index in _cells.size():
		var material := _cells[index]
		if material == EMPTY:
			continue
		var colour: Color = PALETTES[material][_shade[index]]
		if LIFETIME.has(material):
			colour.a = clampf(1.0 - float(_age[index]) / (LIFETIME[material] * 1.4), 0.15, 1.0)
		_write(data, index, colour)
	for particle in _pmat.size():
		var x := int(_px[particle])
		var y := int(_py[particle])
		if _inside(x, y):
			_write(data, _index(x, y), PALETTES[_pmat[particle]][particle % 3])
	return ImageTexture.create_from_image(Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data))


# Additive light: sparks and hot debris. Composite with CanvasItemMaterial.BLEND_MODE_ADD.
func render_glow() -> ImageTexture:
	var data := PackedByteArray()
	data.resize(width * height * 4)
	for index in _cells.size():
		var material := _cells[index]
		var strength := 0.0
		if material == SPARK:
			strength = 1.0 - float(_age[index]) / LIFETIME[SPARK]
		elif _heat[index] > 0:
			strength = float(_heat[index]) / MAX_HEAT
		if strength > 0.0:
			_write(data, index, Color(1.0, 0.62, 0.22, 1.0) * clampf(strength, 0.0, 1.0))
	for particle in _pmat.size():
		var x := int(_px[particle])
		var y := int(_py[particle])
		var heat := float(_pheat[particle]) / MAX_HEAT
		if _pmat[particle] == SPARK:
			heat = 1.0 - float(_page[particle]) / LIFETIME[SPARK]
		if _inside(x, y) and heat > 0.0:
			_write(data, _index(x, y), Color(1.0, 0.7, 0.3, 1.0) * clampf(heat, 0.0, 1.0))
	return ImageTexture.create_from_image(Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data))


func _write(data: PackedByteArray, index: int, colour: Color) -> void:
	var offset := index * 4
	data[offset] = colour.r8
	data[offset + 1] = colour.g8
	data[offset + 2] = colour.b8
	data[offset + 3] = colour.a8


func _inside(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func _index(x: int, y: int) -> int:
	return y * width + x
