extends SceneTree

# MIT. Source-only classification/visibility regression, not traversal acceptance.
const Visual = preload("res://scripts/underground_visual.gd")
const Hazards = preload("res://scripts/campaign_hazards.gd")
const Network = preload("res://scripts/rail_network.gd")
const Portals = preload("res://scripts/terrain_portals.gd")

class ProjectedView:
	extends RefCounted
	var calls: Array = []
	func _world_to_screen(point: Vector2) -> Vector2:
		return point*16.0 # source: original CARTE16px registration test lattice.
	func _effective_zoom() -> float:
		return 1.0
	func draw_line(first: Vector2, last: Vector2, color: Color, width: float) -> void:
		calls.append([first,last,color,width])


func _initialize() -> void:
	var data = preload("res://scripts/world_data.gd").new()
	assert(data.load_from_project(ProjectSettings.globalize_path("res://").trim_suffix("/")))
	var network = Network.new()
	assert(network.load_bytes(data.map_bytes))
	for code in range(38,59):
		# source: TIME0x0496 excludes53/54/58 from double-speed underground set.
		assert(Visual.is_underground(code) == (code not in [53,54,58]))
		assert(Visual.is_underground(-code) == Visual.is_underground(code))
	for code in [0,2,3,15,16,34,65,80,147]:
		assert(not Visual.is_underground(code))
	for cell in Hazards.MOLES:
		assert(Visual.is_underground(network.tile(cell)), "Every original mole hazard is on underground rails")
	for record in [[Vector2i(61,51),53,Vector2.DOWN], [Vector2i(30,58),54,Vector2.LEFT],
		[Vector2i(51,39),54,Vector2.LEFT], [Vector2i(12,21),58,Vector2.RIGHT],
		[Vector2i(105,23),58,Vector2.RIGHT], [Vector2i(113,58),58,Vector2.RIGHT]]:
		assert(network.tile(record[0]) == record[1])
		assert(Visual.mouth_direction(record[1]) == record[2])
	# Owner-requested design samples, explicitly not source rules.
	for alpha in [0.75,0.85]:
		assert(is_equal_approx(Visual.train_tint(39,alpha).a,alpha))
		assert(Visual.train_tint(54,alpha) == Color.WHITE)
		assert(Visual.train_tint(2,alpha) == Color.WHITE)
	var portals = Portals.new()
	portals.load_art()
	assert(portals.textures.size() == 3, "Three generated open-mouth variants load")
	var view := ProjectedView.new()
	for code in [53,54,58]:
		var frame: Dictionary = portals.frames[code]
		var cell := Vector2i(2,3) # authored deliberately offset registration fixture.
		var transform: Transform2D = portals.registration(view,cell,code)
		var endpoint := Portals._point(frame.rail_endpoint)
		var anchor := Portals._point(frame.mouth_anchor)
		var direction := Visual.mouth_direction(code)
		var target := view._world_to_screen(Vector2(cell)+Vector2.ONE*0.5+direction*0.5)
		assert((transform*endpoint).is_equal_approx(target), "Measured rail section joins source surface boundary exactly")
		assert((transform.basis_xform(endpoint-anchor)).normalized().is_equal_approx(direction))
		var normal := (endpoint-anchor).normalized().orthogonal()
		assert(is_equal_approx(transform.basis_xform(normal*float(frame.rail_gauge)).length(),Portals.GAUGE))
		assert(portals.handles_rail(code), "Embedded rails cannot receive a generic duplicate")
	assert(portals.draw_tile(view,Vector2i.ZERO,39) and not view.calls.is_empty())
	assert(not portals.handles_rail(2) and not portals.handles_rail(80))
	print("PASS: exact underground/mouth sets, six original portal orientations, seven mole sites and independent wagon tints")
	quit()
