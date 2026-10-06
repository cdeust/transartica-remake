extends SceneTree
# MIT. Validation precedes mount/copy; invalid user packs preserve installed bytes.
const Pack := preload("res://scripts/public_data_pack.gd")
var failures: Array[String] = []
var directory := "res://../.cache/public-pack-tests/"

func _initialize() -> void: run.call_deferred()
func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func fixture(name: String, entries: Array) -> String:
	var path := ProjectSettings.globalize_path(directory+name+".zip")
	var zip := ZIPPacker.new()
	check(zip.open(path)==OK,"fixture open")
	for entry in entries:
		check(zip.start_file(entry[0])==OK,"fixture entry")
		check(zip.write_file(entry[1])==OK,"fixture payload")
		zip.close_file()
	zip.close()
	return path

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var payload := "private fixture, not historical data".to_utf8_buffer()
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(payload)
	var name := "private-data/public-pack-fixture.data"
	var expected := {"format":Pack.FORMAT,"files":[{"path":name,"size":payload.size(),"sha256":hash.finish().hex_encode()}]}
	var valid := fixture("valid",[[name,payload]])
	check(not Pack.validate(directory+"missing.zip",expected).ok,"missing pack gate")
	check(Pack.validate(valid,expected).ok,"valid inventory")
	var corrupted := fixture("corrupted",[[name,"changed".to_utf8_buffer()]])
	var empty := fixture("empty",[])
	var unexpected := fixture("unexpected",[[name,payload],["scripts/main.gd",payload]])
	var traversal := fixture("traversal",[["private-data/../main.gd",payload]])
	var duplicate := fixture("duplicate",[[name,payload],[name,payload]])
	for path in [corrupted,empty,unexpected,traversal,duplicate]:
		check(not Pack.validate(path,expected).ok,"invalid ZIP rejected "+path)
	var installed := ProjectSettings.globalize_path(directory+"installed.zip")
	var previous := "existing installed bytes".to_utf8_buffer()
	var file := FileAccess.open(installed,FileAccess.WRITE)
	file.store_buffer(previous)
	file.close()
	check(not Pack.install(corrupted,installed,expected).ok,"invalid install refused")
	check(FileAccess.get_file_as_bytes(installed)==previous,"invalid install preserves old bytes")
	check(not FileAccess.file_exists(installed+".incoming"),"invalid install leaves no candidate")
	check(Pack.install(valid,installed,expected).ok,"valid install and mount")
	check(FileAccess.get_file_as_bytes("res://"+name)==payload,"mounted source path preserved")
	check(not FileAccess.file_exists(installed+".incoming"),"valid install leaves no candidate")
	check(not FileAccess.file_exists(installed+".previous"),"valid replacement leaves no backup")
	var recovered := ProjectSettings.globalize_path(directory+"recovered.zip")
	check(DirAccess.copy_absolute(valid,recovered+".previous")==OK,"interrupted-install fixture")
	check(Pack.mount(recovered,expected).ok,"recover interrupted install")
	check(FileAccess.file_exists(recovered) and not FileAccess.file_exists(recovered+".previous"),"recovery restores prior ZIP")
	# Crash after candidate rename: both recognized ZIPs exist; remove only backup.
	var completed := ProjectSettings.globalize_path(directory+"completed.zip")
	DirAccess.copy_absolute(valid,completed)
	DirAccess.copy_absolute(valid,completed+".previous")
	check(Pack._recover(completed,expected).ok,"post-rename crash reconciled")
	check(Pack.validate(completed,expected).ok and not FileAccess.file_exists(completed+".previous"),"valid destination retained, redundant backup removed")
	check(Pack.install(valid,completed,expected).ok,"replacement no longer blocked after crash")
	# Corrupt destination and valid backup: invalid incoming must alter neither.
	var damaged := ProjectSettings.globalize_path(directory+"damaged.zip")
	DirAccess.copy_absolute(corrupted,damaged)
	DirAccess.copy_absolute(valid,damaged+".previous")
	var bad_bytes := FileAccess.get_file_as_bytes(damaged)
	var good_bytes := FileAccess.get_file_as_bytes(damaged+".previous")
	check(not Pack.install(corrupted,damaged,expected).ok,"invalid incoming refused before crash recovery")
	check(FileAccess.get_file_as_bytes(damaged)==bad_bytes and FileAccess.get_file_as_bytes(damaged+".previous")==good_bytes,"invalid incoming preserves destination and valid previous")
	check(Pack.mount(damaged,expected).ok,"corrupt installed ZIP recovered from valid previous")
	check(Pack.validate(damaged,expected).ok and not FileAccess.file_exists(damaged+".previous"),"recovered exact recognized data")
	# Unrecognized backup is retained even alongside recognized installed data.
	var unknown := ProjectSettings.globalize_path(directory+"unknown.zip")
	DirAccess.copy_absolute(valid,unknown)
	DirAccess.copy_absolute(corrupted,unknown+".previous")
	check(Pack.mount(unknown,expected).ok,"valid installed data starts with unrecognized backup")
	check(not Pack.install(valid,unknown,expected).ok,"unknown backup prevents destructive replacement")
	check(FileAccess.get_file_as_bytes(unknown+".previous")==bad_bytes,"unknown backup never deleted")
	DirAccess.remove_absolute(unknown+".previous")
	check(ProjectSettings.get_setting("application/run/main_scene")=="res://main.tscn","private launch unchanged")
	check(ProjectSettings.get_setting("application/run/main_scene.public_release")=="res://public_boot.tscn","public bootstrap override")
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty():
		var actual := Pack.validate(arguments[0])
		check(actual.ok and actual.get("files")==Pack.manifest().files.size(),"actual separate pack matches manifest")
	for path in [valid,corrupted,empty,unexpected,traversal,duplicate,installed,recovered,completed,damaged,unknown]: DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: missing/valid/corrupt/extra/traversal/duplicate ZIPs, transactional install, resource mount, private/public startup and optional supplied private inventory")
	quit(0 if failures.is_empty() else 1)
