extends SceneTree
# MIT. Isolated PCK with authored frame/material and private vector topology only.
func _initialize()->void:
	var pack=PCKPacker.new()
	var destination=ProjectSettings.globalize_path("res://../.cache/overview-proof.pck")
	assert(pack.pck_start(destination)==OK)
	for name in DirAccess.get_files_at("res://scripts"):
		if name.ends_with(".gd"):add(pack,"res://scripts/"+name)
	add(pack,"res://project.godot")
	add(pack,"res://.godot/global_script_class_cache.cfg")
	add(pack,"res://tests/overview_bundle_check.gd")
	assert(pack.add_file("res://private-data/overview-geometry.json",ProjectSettings.globalize_path("res://../reference-private/overview-geometry.json"))==OK)
	for path in ["res://assets/interface/world-chart-frame.png","res://assets/travel/terrain/ice-master.png"]:
		add(pack,path)
		add(pack,path+".import")
		var config=ConfigFile.new()
		assert(config.load(path+".import")==OK)
		add(pack,config.get_value("remap","path"))
	assert(pack.flush()==OK)
	print("PASS: isolated overview PCK contains private vectors and authored textures; no original RGB or map pixels")
	quit()
func add(pack:PCKPacker,path:String)->void:
	assert(pack.add_file(path,ProjectSettings.globalize_path(path))==OK)
