extends RefCounted
class_name SurveyWorldData

const MAP_WIDTH := 160 # source: FORMAT-CARTE.md, MAIN.CO dimensions and CARTE.FIC read length
const MAP_HEIGHT := 73 # source: FORMAT-CARTE.md, MAIN.CO dimensions and CARTE.FIC read length
# source: project layout in tasks/execution-contract.md; reference data stays private
const MAP_PATH := "../reference-private/CARTE.FIC"
const CITIES_PATH := "../reference-private/villes-decoded.csv"

var map_bytes := PackedByteArray()
var cities: Array[Dictionary] = []


func load_from_project(project_root: String) -> bool:
	var map_contents := _read_reference("CARTE.FIC", project_root)
	var city_contents := _read_reference("villes-decoded.csv", project_root)
	if map_contents.is_empty() or city_contents.is_empty():
		return false
	map_bytes = map_contents
	if map_bytes.size() != MAP_WIDTH * MAP_HEIGHT:
		return false
	cities = _parse_cities(city_contents.get_string_from_utf8())
	return cities.size() == 46


func _read_reference(filename: String, project_root: String) -> PackedByteArray:
	# Godot's CSV importer creates translations and drops the raw CSV in exports.
	# Keep the exact CSV bytes under a neutral extension for FileAccess.
	var bundled_name := "villes-decoded.data" if filename.ends_with(".csv") else filename
	var bundled_path := "res://private-data/" + bundled_name
	if FileAccess.file_exists(bundled_path):
		return FileAccess.get_file_as_bytes(bundled_path)
	var relative_path := MAP_PATH if filename == "CARTE.FIC" else CITIES_PATH
	var source_path := project_root.path_join(relative_path)
	if not FileAccess.file_exists(source_path):
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(source_path)


func map_code(x: int, y: int) -> int:
	if x < 0 or x >= MAP_WIDTH or y < 0 or y >= MAP_HEIGHT:
		return -1
	return map_bytes[x * MAP_HEIGHT + y]


func _parse_cities(csv_text: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var lines := csv_text.strip_edges().split("\n")
	if lines.size() < 2:
		return result
	var columns := lines[0].split(",")
	var name_column := columns.find("game_name")
	var x_column := columns.find("anchor_x")
	var y_column := columns.find("anchor_y")
	if mini(mini(name_column, x_column), y_column) < 0:
		return result
	for line in lines.slice(1):
		var fields := line.split(",")
		if fields.size() <= maxi(name_column, maxi(x_column, y_column)):
			continue
		result.append({"name": fields[name_column], "x": int(fields[x_column]), "y": int(fields[y_column])})
	return result
