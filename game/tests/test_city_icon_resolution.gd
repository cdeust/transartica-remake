extends SceneTree
# MIT. Owner3Oct: modern artwork must survive the commerce texture loader.
const Icons = preload("res://scripts/city_list_icons.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var icons = Icons.new()
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(Icons.MANIFEST))
	var atlas = load("res://assets/cities/" + manifest.file).get_image()
	if atlas.is_compressed(): atlas.decompress()
	for frame in manifest.frames:
		var region := Rect2i(frame.region[0],frame.region[1],frame.region[2],frame.region[3])
		_verify(atlas.get_region(region))
	for kind in range(1,26):
		_verify(icons.wagons.texture_for(kind).get_image())
	print("PASS: all16 goods and25 wagon images retain their exact source pixels before display scaling")
	quit()

func _verify(original: Image) -> void:
	if original.is_compressed(): original.decompress()
	original.convert(Image.FORMAT_RGBA8)
	var pixels := original.get_data()
	var fitted := Icons.fitted(original).get_image()
	assert(fitted.get_width() >= original.get_width() and fitted.get_height() >= original.get_height(), "source resolution preserved")
	var offset := (fitted.get_size()-original.get_size())/2
	var recovered := fitted.get_region(Rect2i(offset,original.get_size()))
	assert(recovered.get_data() == pixels, "source pixels remain exact")
