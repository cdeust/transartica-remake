extends RefCounted
# MIT. Foreground only; source geography in underground-rendering.md and world-terrain.md.
const Terrain = preload("res://scripts/travel_terrain.gd")
const Rails = preload("res://scripts/rail_glyphs.gd")
const Visual = preload("res://scripts/underground_visual.gd")
const ART_ROOT := "res://assets/travel/terrain/" # source: regions-v2/README.md overlay delivery.
const ART_CELL := 64.0 # source: regions-v2/README.md footprints per CARTE cell.
const GAUGE := 20.0 # source: terrain_portals.gd shared authored rail gauge.
const MOUTH_ANCHOR := Vector2(72,73) # source: first narrow channel row, world-foreground-20261006.md.
const MOUTH_GAUGE := 19.0 # source: row120 rail highlights62 and80/82, same evidence.
const LIP_HEIGHT := 73.0 # source: lintel shadow row72 precedes dark channel row73, same measurement.
const MOUTHS := {Vector2i(61,51):53,Vector2i(30,58):54,Vector2i(51,39):54,Vector2i(12,21):58,Vector2i(105,23):58,Vector2i(113,58):58} # source: underground-rendering.md six decoded mouths.
var canopies: Array[Texture2D] = []
var canopy_rects: Array[Rect2i] = []
var portal: Texture2D
var foreground_enabled := true # source: prepared on/off occlusion comparison; default enabled.

func load_art() -> bool:
	canopies.clear()
	canopy_rects.clear()
	for index in 3:
		var path := ART_ROOT+"canopy-%d.png" % index
		if not ResourceLoader.exists(path): continue
		var texture := load(path) as Texture2D
		if texture == null: continue
		canopies.append(texture)
		canopy_rects.append(texture.get_image().get_used_rect())
	var path := ART_ROOT+"tunnel-straight.png"
	portal = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return not canopies.is_empty() or portal != null

func handles_mouth(cell: Vector2i, code: int) -> bool:
	return portal != null and MOUTHS.get(cell,-1) == code

func mouth_registration(view, cell: Vector2i, code: int) -> Transform2D:
	# Reuse the existing measured source mouth anchor; never choose another tunnel.
	var frame: Dictionary = view.terrain.portals.frames[code]
	var old_anchor := Vector2(frame.mouth_anchor[0],frame.mouth_anchor[1])
	var target: Vector2 = view.terrain.portals.registration(view,cell,code) * old_anchor
	var direction := Visual.mouth_direction(code)
	var scale: float = GAUGE*view._effective_zoom()/MOUTH_GAUGE
	var rotation := direction.angle()-PI*0.5
	var basis := Transform2D(Vector2.RIGHT.rotated(rotation)*scale,Vector2.DOWN.rotated(rotation)*scale,Vector2.ZERO)
	return Transform2D(basis.x,basis.y,target-basis.basis_xform(MOUTH_ANCHOR))

func mouth_section(view, cell: Vector2i, code: int) -> Vector2:
	# Clip the embedded external rail at the original registered surface port.
	var target: Vector2 = view._world_to_screen(Vector2(cell)+Vector2.ONE*0.5+Visual.mouth_direction(code)*0.5)
	return mouth_registration(view,cell,code).affine_inverse() * target

func draw_floor(view) -> void:
	if view.world_data == null or portal == null: return
	for cell in MOUTHS:
		var code: int = view._tile_code(cell.x,cell.y)
		if not handles_mouth(cell,code) or not view._cell_is_visible(cell.x,cell.y): continue
		if not view.terrain.portals.frames.has(code): continue
		var section := mouth_section(view,cell,code)
		var source := Rect2(Vector2.ZERO,Vector2(portal.get_width(),section.y))
		view.draw_set_transform_matrix(mouth_registration(view,cell,code))
		view.draw_texture_rect_region(portal,source,source)
	view.draw_set_transform_matrix(Transform2D.IDENTITY)

func draw(view) -> void:
	if view.world_data == null or not foreground_enabled: return
	for entry in canopy_plan(view):
		var first: Vector2 = view._world_to_screen(entry.rect.position)
		var last: Vector2 = view._world_to_screen(entry.rect.end)
		view.draw_texture_rect(canopies[entry.variant],Rect2(first,last-first),false)
	if portal == null: return
	for cell in MOUTHS:
		var code: int = view._tile_code(cell.x,cell.y)
		if not handles_mouth(cell,code) or not view._cell_is_visible(cell.x,cell.y): continue
		if not view.terrain.portals.frames.has(code): continue
		# Only the opaque arch/crown crosses the train; dark opening remains below it.
		var source := Rect2(Vector2.ZERO,Vector2(portal.get_width(),LIP_HEIGHT))
		view.draw_set_transform_matrix(mouth_registration(view,cell,code))
		view.draw_texture_rect_region(portal,source,source)
	view.draw_set_transform_matrix(Transform2D.IDENTITY)

func canopy_plan(view) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if canopies.is_empty(): return result
	var bounds: Rect2i = view._visible_world_bounds().grow(2) # source: largest v2 footprint2.25 cells.
	bounds = bounds.intersection(Rect2i(0,0,view.WorldDataScript.MAP_WIDTH,view.WorldDataScript.MAP_HEIGHT))
	for x in range(bounds.position.x,bounds.end.x):
		for y in range(bounds.position.y,bounds.end.y):
			var cell := Vector2i(x,y)
			var resource: int = Terrain.resource_code(view._tile_code(x,y))
			if resource < 116 or resource > 132: continue # source: CARTE forest resource set.
			var neighbor := rail_neighbor(view,cell)
			if neighbor == cell: continue
			var variant := posmod(x+y*3,canopies.size()) # source: deterministic authored variant, no gameplay RNG.
			var extent := canopies[variant].get_size()/ART_CELL
			var delta := Vector2(neighbor-cell)
			var opaque_extent := Vector2(canopy_rects[variant].size)/ART_CELL
			var radius: float = opaque_extent.x*0.5 if delta.x != 0 else opaque_extent.y*0.5
			# Measured crown radius reaches the neighboring rail plus half its existing gauge.
			var overhang: float = maxf(0,1.0-radius+GAUGE/(2.0*view.CELL_PIXELS))
			var center := Vector2(cell)+Vector2.ONE*0.5+delta*overhang
			var rect := Rect2(center-extent*0.5,extent)
			if protected_overlap(view,rect): continue
			result.append({"cell":cell,"rail":neighbor,"variant":variant,"rect":rect})
	return result

static func rail_neighbor(view, cell: Vector2i) -> Vector2i:
	for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		var neighbor: Vector2i = cell+delta
		if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= view.WorldDataScript.MAP_WIDTH or neighbor.y >= view.WorldDataScript.MAP_HEIGHT: continue
		if not Rails.ports_for_code(view._tile_code(neighbor.x,neighbor.y)).is_empty(): return neighbor
	return cell

static func protected_overlap(view, rect: Rect2) -> bool:
	var bounds := Rect2i(Vector2i(rect.position.floor()),Vector2i(rect.end.ceil()-rect.position.floor()))
	for x in range(maxi(0,bounds.position.x),mini(view.WorldDataScript.MAP_WIDTH,bounds.end.x)):
		for y in range(maxi(0,bounds.position.y),mini(view.WorldDataScript.MAP_HEIGHT,bounds.end.y)):
			var code: int = absi(view._tile_code(x,y))
			if code >= 18 and code <= 37 and rect.intersects(Rect2(Vector2(x,y),Vector2.ONE)):
				return true # source: switch/station click targets, rail glyph codes18..37.
	for city in view.world_data.cities:
		# terrain_landmarks uses the source lower-right anchor: painting starts2west/1north.
		if rect.intersects(Rect2(Vector2(city.x,city.y)-Vector2(2,1),Vector2(3,2))): return true
	return false
