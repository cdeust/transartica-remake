extends SceneTree
var room_art: Texture2D # Keep the texture alive, as GeneralQuarters does in the actual app.

# MIT. Prepared artwork observer only; never submits gameplay input.
func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	assert(DisplayServer.get_name() != "headless")
	root.size = Vector2i(1280,800) # authored fourfold320x200 artwork review.
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	room_art = load("res://assets/boudoir/general-quarters.png")
	var screen = preload("res://scripts/campaign_screen.gd").new()
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.open_menu(["SEND SPY","DYNAMITE","EXIT"])
	await capture("spy-menu")
	screen.present("sabotage_confirm",["ORDER THIS SPY TO USE DYNAMITE HERE?"],false,true)
	await capture("sabotage-confirmation")
	screen.hide()
	var reception = preload("res://scripts/reception_screen.gd").new()
	root.add_child(reception)
	reception.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reception.show()
	var keys = preload("res://scripts/keyboard_settings_button.gd").new()
	reception.add_child(keys)
	await capture("options")
	print("PASS: prepared menu, confirmation and options artwork captured")
	quit()


func capture(label: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	assert(not image.is_empty() and image.get_size() == Vector2i(1280,800))
	var directory := ProjectSettings.globalize_path("res://../output/brass-choices-review-20261004")
	DirAccess.make_dir_recursive_absolute(directory)
	assert(image.save_png(directory+"/"+label+".png") == OK)
