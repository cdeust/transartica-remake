extends SceneTree
# MIT. Source-space contour inspection; no source texture is changed.
const CROPS := {
	"boudoir-stoup": Rect2(50, 650, 145, 170),
	"boudoir-kolotov": Rect2(175, 260, 550, 600),
	"boudoir-revolver": Rect2(820, 670, 180, 130),
	"boudoir-book": Rect2(990, 600, 665, 240),
	"quarters-stoup": Rect2(20, 675, 150, 189),
	"quarters-operator": Rect2(120, 375, 260, 420),
	"quarters-map": Rect2(395, 405, 970, 455),
	"quarters-officer": Rect2(1200, 180, 621, 684),
}
var background: Texture2D
var crop := Rect2()
var magnification := 1.0
var left: Node2D
var right: Node2D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var name: String = args[0]
	var output: String = args[1]
	crop = CROPS[name]
	magnification = float(args[2]) if args.size() > 2 else 1.0
	if args.size() > 3:
		var coordinates := args[3].split(",")
		crop = Rect2(float(coordinates[0]), float(coordinates[1]), float(coordinates[2]), float(coordinates[3]))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(crop.size * Vector2(2, 1) * magnification)
	await process_frame
	await process_frame
	var source := "captain-boudoir" if name.begins_with("boudoir") else "general-quarters"
	background = load("res://assets/boudoir/%s.png" % source)
	left = Node2D.new()
	left.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(left)
	left.draw.connect(_draw_left)
	right = Node2D.new()
	right.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(right)
	right.draw.connect(_draw_right)
	var matte := Sprite2D.new()
	matte.centered = false
	matte.texture = load("res://assets/boudoir/cutouts/%s.png" % name)
	matte.region_enabled = true
	matte.region_rect = crop
	matte.position = Vector2(crop.size.x * magnification, 0)
	matte.scale = Vector2.ONE * magnification
	var shader := ShaderMaterial.new()
	shader.shader = load("res://shaders/object_hover.gdshader")
	shader.set_shader_parameter("coverage_from_alpha", true)
	matte.material = shader
	root.add_child(matte)
	left.queue_redraw()
	right.queue_redraw()
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output)
	print("SOURCE/OVERLAY %s %s" % [name, error])
	quit(error)


func _draw_left() -> void:
	left.draw_texture_rect_region(background, Rect2(Vector2.ZERO, crop.size * magnification), crop)


func _draw_right() -> void:
	right.draw_texture_rect_region(background, Rect2(Vector2(crop.size.x * magnification, 0), crop.size * magnification), crop)
