extends RefCounted
# MIT. Owner6Oct separation contract; documented ZIPReader/resource-pack APIs.
# See tasks/evidence/public-data-pack-20261006.md; no archive extraction.
const MANIFEST := "res://assets/interface/original-data-manifest.json"
const INSTALLED := "user://original-data.zip"
const FORMAT := "transartica-original-data-v1"

static func manifest() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	return parsed if parsed is Dictionary else {}

static func validate(path: String, expected: Dictionary = {}) -> Dictionary:
	if expected.is_empty(): expected = manifest()
	if expected.get("format") != FORMAT or not expected.get("files") is Array or expected.files.is_empty():
		return {"ok":false,"message":"The data manifest is unavailable."}
	if not FileAccess.file_exists(path):
		return {"ok":false,"message":"Choose your original-data ZIP to start the game."}
	var archive := ZIPReader.new()
	if archive.open(path) != OK:
		return {"ok":false,"message":"This file is not a readable data ZIP."}
	var entries: PackedStringArray = archive.get_files()
	var wanted: Dictionary = {}
	for entry in expected.files:
		if not entry is Dictionary or not entry.get("path") is String:
			archive.close()
			return {"ok":false,"message":"The data manifest is invalid."}
		var name: String = entry.path
		if not _data_path(name) or wanted.has(name):
			archive.close()
			return {"ok":false,"message":"The data manifest has an invalid path."}
		wanted[name] = entry
	var seen: Dictionary = {}
	for name in entries:
		if not wanted.has(name) or seen.has(name):
			archive.close()
			return {"ok":false,"message":"This ZIP contains unexpected files."}
		seen[name] = true
		var payload := archive.read_file(name)
		var entry: Dictionary = wanted[name]
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(payload)
		if payload.size() != int(entry.get("size",-1)) or hash.finish().hex_encode() != entry.get("sha256"):
			archive.close()
			return {"ok":false,"message":"The data ZIP is incomplete or does not match this version."}
	archive.close()
	if seen.size() != wanted.size():
		return {"ok":false,"message":"The data ZIP is missing required files."}
	return {"ok":true,"files":seen.size()}

static func _data_path(path: String) -> bool:
	if not path.begins_with("private-data/") or path.ends_with(".import") or "\\" in path:
		return false
	for component in path.split("/"):
		if component in ["", ".", ".."]: return false
	return true

static func mount(path: String = INSTALLED, expected: Dictionary = {}) -> Dictionary:
	var recovery := _recover(path,expected)
	if not recovery.ok: return recovery
	return _mount(path,expected)

static func _mount(path: String, expected: Dictionary) -> Dictionary:
	var result := validate(path,expected)
	if not result.ok: return result
	# replace_files=false: data never substitutes code already in the public pack.
	if not ProjectSettings.load_resource_pack(path,false):
		return {"ok":false,"message":"The data ZIP could not be opened by the game."}
	return result

static func _recover(path: String, expected: Dictionary) -> Dictionary:
	# Crash states are recognized by validating both ZIPs against this edition.
	# Only a recognized redundant backup may be removed; unknown bytes stay put.
	var backup := path+".previous"
	if not FileAccess.file_exists(backup): return {"ok":true}
	var previous := validate(backup,expected)
	var installed := validate(path,expected)
	if not previous.ok:
		if installed.ok: return {"ok":true}
		return {"ok":false,"message":"The retained backup does not match this edition: "+backup+"."}
	if installed.ok:
		if DirAccess.remove_absolute(backup) != OK:
			return {"ok":false,"message":"The completed installation backup could not be removed: "+backup+"."}
	elif DirAccess.rename_absolute(backup,path) != OK:
		# Windows may remove the invalid destination before a failed MoveFileW;
		# the validated source backup remains available for the next recovery.
		return {"ok":false,"message":"The previous data ZIP is retained at "+backup+" and could not be restored."}
	return {"ok":true}

static func install(source: String, destination: String = INSTALLED, expected: Dictionary = {}) -> Dictionary:
	var result := validate(source,expected)
	if not result.ok: return result
	if ProjectSettings.globalize_path(source) == ProjectSettings.globalize_path(destination):
		return mount(destination,expected)
	# Copy to a separate candidate; validate the actual copy before replacing data.
	var candidate := destination+".incoming"
	if DirAccess.copy_absolute(source,candidate) != OK:
		return {"ok":false,"message":"The data ZIP could not be copied. Check free space and folder access."}
	result = validate(candidate,expected)
	if not result.ok:
		DirAccess.remove_absolute(candidate)
		return result
	result = _recover(destination,expected)
	if not result.ok:
		DirAccess.remove_absolute(candidate)
		return result
	# Windows Godot4.5 removes an existing rename destination before MoveFileW.
	# Move the previous ZIP aside first, leaving a vacant destination and rollback.
	# Source: drivers/windows/dir_access_windows.cpp254..291, cited in evidence.
	var backup := destination+".previous"
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(candidate)
		return {"ok":false,"message":"A backup does not match this edition and has been retained: "+backup+"."}
	var had_previous := FileAccess.file_exists(destination)
	if had_previous and DirAccess.rename_absolute(destination,backup) != OK:
		DirAccess.remove_absolute(candidate)
		return {"ok":false,"message":"Your existing data could not be backed up and is unchanged."}
	if DirAccess.rename_absolute(candidate,destination) != OK:
		DirAccess.remove_absolute(candidate)
		return _rollback(destination,backup,had_previous)
	# Keep this transaction backup until mounting succeeds; startup recovery
	# must not remove it before a possible rollback.
	result = _mount(destination,expected)
	if not result.ok:
		DirAccess.remove_absolute(destination)
		return _rollback(destination,backup,had_previous)
	if had_previous: DirAccess.remove_absolute(backup)
	return result

static func _rollback(destination: String, backup: String, had_previous: bool) -> Dictionary:
	if had_previous and DirAccess.rename_absolute(backup,destination) != OK:
		return {"ok":false,"message":"Installation failed. Your previous ZIP is retained at "+backup+"."}
	return {"ok":false,"message":"The data ZIP could not be installed. Your existing data is unchanged."}
