extends SceneTree
# MIT. Reuse authored materials while retaining incomplete sourceplan inventory.
const Chart=preload("res://scripts/overview_chart_art.gd")
var failures: Array[String]=[]
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var chart=Chart.new()
	chart.load_art()
	assert(chart.available())
	var before: Dictionary=chart.geometry.duplicate(true)
	# Inventory measured from resource192 by tools/export_overview_geometry.py;
	# the existing geometry reconstruction suite independently checks endpoints.
	for key in {"routes":947,"compartments":1046,"dots":206,"symbols":10,"sites":114}:
		if chart.geometry[key].size()!={"routes":947,"compartments":1046,"dots":206,"symbols":10,"sites":114}[key]: failures.append("Source inventory changed: "+key)
	var points: Array=[]
	for marker in chart.town_markers():
		if not marker.bounds.encloses(marker.destination): failures.append("Town art exceeds exact source town footprint")
		if not marker.bounds.get_center().is_equal_approx(marker.destination.get_center()): failures.append("Town marker moved away from source")
		points.append(marker.bounds)
	if points.size()!=45: failures.append("Static town inventory changed")
	if chart.geometry!=before: failures.append("Marker presentation mutates source geometry")
	if not chart.material is AtlasTexture or chart.material.region!=Chart.paper_region(): failures.append("Chart does not use clean modern authored paper")
	else:
		var crop: Rect2=chart.material.region
		var center: Vector2=Chart.PAPER_FACE.get_center()
		var radius: Vector2=Chart.PAPER_FACE.size/2.0
		for corner: Vector2 in [crop.position,crop.end,Vector2(crop.position.x,crop.end.y),Vector2(crop.end.x,crop.position.y)]:
			if ((corner-center)/radius).length_squared()>1.0: failures.append("Paper crop includes circular clock bezel")
	if chart.town_art==null: failures.append("Authored neutral town artwork missing")
	# Existing 1280 reference viewport, owner1440 viewport, narrow resize fixture.
	for size: Vector2 in [Vector2(1280,596),Vector2(1440,670),Vector2(600,280)]:
		var factor: Vector2=size/Vector2(320,149)
		for box in points:
			var rendered: Rect2=Rect2(box.position*factor,box.size*factor)
			if not Rect2(Vector2.ZERO,size).encloses(rendered): failures.append("Town outside chart after resize")
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: authored paper/landmarks, exact45static town footprints, resize bounds and immutable incomplete geometry")
	quit(0 if failures.is_empty() else 1)
