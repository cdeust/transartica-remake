extends SceneTree
func _initialize():
	var img = Image.load_from_file(ProjectSettings.globalize_path("res://assets/travel/train-east.png"))
	print("ALPHA ", img.get_pixel(0,0).a, " / ", img.get_pixel(800,50).a, " / ", img.get_pixel(800,900).a, " used ", img.get_used_rect())
	quit()
