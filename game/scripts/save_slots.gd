extends RefCounted

const BoudoirActions = preload("res://scripts/boudoir_actions.gd")


# Source: tasks/evidence/boudoir-layout.md; room.alis 0x55e, 0x06a6.
# The initial character is a letter; later characters may include digits.
static func normalize_name(raw: String) -> String:
	var name := ""
	for index in raw.length():
		name = BoudoirActions.append_char(name, raw.unicode_at(index))
	return name


static func slot_path(directory: String, name: String) -> String:
	# A caller must explicitly normalize input; paths never sanitize traversal.
	if name.is_empty() or normalize_name(name) != name:
		return ""
	return directory.path_join(BoudoirActions.save_filename(name))


static func list_names(directory: String) -> Array[String]:
	var names: Array[String] = []
	var dir := DirAccess.open(directory)
	if dir == null:
		return names
	for filename in dir.get_files():
		if filename.ends_with(".SAV"):
			var name := filename.trim_suffix(".SAV")
			if not slot_path(directory, name).is_empty():
				names.append(name)
	names.sort()
	return names
