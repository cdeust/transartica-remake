extends SceneTree
# MIT. Owner-authorized local raster extraction, 3 October 2026.
# Source: manually measured scene coordinates in wagon-cutout-guides.json.
# Godot Image/Geometry2D APIs: pixel centers classified against authored polygons.
# Source RGB is copied verbatim; coverage is opaque or transparent.


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var selected_subject := ""
	if "--subject" in args:
		var index := args.find("--subject")
		if index + 1 >= args.size():
			push_error("--subject requires an exact guide name")
			quit(1)
			return
		selected_subject = args[index + 1]
	var guides: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://../tools/wagon-cutout-guides.json"))
	var reports: Array = []
	for subject: Dictionary in guides.subjects:
		if not selected_subject.is_empty() and subject.name != selected_subject:
			continue
		var report := _extract(subject)
		if report.is_empty():
			quit(1)
			return
		reports.append(report)
	if reports.is_empty():
		push_error("No guide matched requested subject " + selected_subject)
		quit(1)
		return
	var report_name := "wagon-local-cutouts-20261003" if selected_subject.is_empty() else selected_subject + "-local-extraction-20261003"
	FileAccess.open("res://../tasks/validation/" + report_name + ".json", FileAccess.WRITE).store_string(JSON.stringify(reports, "\t") + "\n")
	print("%d registered raster cutout(s) saved from original source pixels" % reports.size())
	quit()


func _extract(subject: Dictionary) -> Dictionary:
	var source_path := "res://assets/boudoir/%s.png" % subject.source
	var original := Image.load_from_file(ProjectSettings.globalize_path(source_path))
	original.convert(Image.FORMAT_RGBA8)
	var output := Image.create(original.get_width(), original.get_height(), false, Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	var foreground := _polygons(subject.foreground)
	var holes := _polygons(subject.holes)
	var occluder: Image
	if subject.has("occluder"):
		occluder = Image.load_from_file(ProjectSettings.globalize_path("res://assets/boudoir/cutouts/" + subject.occluder))
	var selected := 0
	var area := Rect2(foreground[0][0], Vector2.ZERO)
	for polygon: PackedVector2Array in foreground:
		for point in polygon:
			area = area.expand(point)
	for y in range(maxi(0, floori(area.position.y)), mini(original.get_height(), ceili(area.end.y))):
		for x in range(maxi(0, floori(area.position.x)), mini(original.get_width(), ceili(area.end.x))):
			var center := Vector2(x, y) + Vector2.ONE / 2.0
			var included := _inside(center, foreground)
			# The revolver's visible trigger occupies part of the guard opening.
			if _inside(center, holes) and not (foreground.size() > 1 and Geometry2D.is_point_in_polygon(center, foreground[1])):
				included = false
			if occluder != null and roundi(occluder.get_pixel(x, y).a) != 0:
				included = false
			if included:
				output.set_pixel(x, y, original.get_pixel(x, y))
				selected += 1
	var destination := "res://assets/boudoir/cutouts/%s.png" % subject.name
	var error := output.save_png(ProjectSettings.globalize_path(destination))
	if error != OK:
		push_error("Could not save " + destination)
		return {}
	return {"subject": subject.name, "pixels": selected, "source_sha256": FileAccess.get_sha256(source_path), "cutout_sha256": FileAccess.get_sha256(destination), "source_rgb_preserved": true, "size": str(output.get_size()), "alpha_bounds": str(output.get_used_rect())}


func _polygons(paths: Array) -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	for path: Array in paths:
		var polygon := PackedVector2Array()
		for point: Array in path:
			polygon.append(Vector2(point[0], point[1]))
		polygons.append(polygon)
	return polygons


func _inside(point: Vector2, polygons: Array[PackedVector2Array]) -> bool:
	for polygon in polygons:
		if Geometry2D.is_point_in_polygon(point, polygon):
			return true
	return false
