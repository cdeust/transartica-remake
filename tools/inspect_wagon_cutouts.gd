extends SceneTree
# MIT. Read-only inspection of generated layers against their original scene.
# source: Godot Image.get_pixel/get_used_rect, existing source scene dimensions.

func _initialize() -> void:
	var rows: Array = []
	var args := OS.get_cmdline_user_args()
	var directory := args[0] if args.size() > 0 else "res://../output/imagegen/wagon-cutouts-20261002/"
	for name: String in DirAccess.get_files_at(directory):
		if not name.ends_with(".png"):
			continue
		var layer := Image.load_from_file(directory + name)
		var scene := "captain-boudoir" if name.begins_with("boudoir") else "general-quarters"
		var original := Image.load_from_file("res://assets/boudoir/%s.png" % scene)
		var opaque := 0
		var partial := 0
		var equal_rgb := 0
		var alpha_counts: Dictionary = {}
		for y in layer.get_height():
			for x in layer.get_width():
				var pixel := layer.get_pixel(x, y)
				var alpha := roundi(pixel.a * 255.0)
				alpha_counts[alpha] = int(alpha_counts.get(alpha, 0)) + 1
				if alpha == 0:
					continue
				opaque += int(alpha == 255)
				partial += int(alpha < 255)
				var source := original.get_pixel(x, y)
				equal_rgb += int(pixel.r == source.r and pixel.g == source.g and pixel.b == source.b)
		rows.append({"file": name, "size": str(layer.get_size()), "bounds": str(layer.get_used_rect()), "opaque": opaque, "partial": partial, "same_source_rgb": equal_rgb, "alpha_histogram": alpha_counts})
	var report := args[1] if args.size() > 1 else "res://../tasks/validation/wagon-cutouts-inspection-20261002.json"
	var output := FileAccess.open(report, FileAccess.WRITE)
	output.store_string(JSON.stringify(rows, "\t"))
	for row in rows:
		print(row.file, " ", row.bounds, " same-source-rgb=", row.same_source_rgb, " partial=", row.partial, " opaque=", row.opaque)
	quit()
