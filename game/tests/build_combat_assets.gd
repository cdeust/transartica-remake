extends SceneTree
# MIT. Mechanical crops of authored masters; rectangles follow handoff grid.
const BASE := "res://../output/imagegen/visuals-20260927/"
func _initialize() -> void:
	var grids := {"combat-wagons-04-10": [2,3,[4,5,6,7,8,9]], "combat-wagons-10-17": [2,3,[10,12,13,14,15,16]], "combat-wagons-17-25": [2,4,[17,18,19,20,22,24,25,0]]}
	for name in grids:
		var image := Image.load_from_file(BASE + name + ".png")
		var spec: Array = grids[name]
		var width := image.get_width() / int(spec[0])
		var height := image.get_height() / int(spec[1])
		for index in spec[2].size():
			if spec[2][index] > 0:
				_crop(image, Rect2i(index % int(spec[0]) * width,index / int(spec[0]) * height,width,height), "wagon-%02d" % spec[2][index])
	var train := Image.load_from_file(BASE + "combat-train-kit.png")
	var w := train.get_width()
	var h := train.get_height()
	var rectangles := [Rect2i(0,0,w*38/100,h/2),Rect2i(w*38/100,0,w*27/100,h/2),Rect2i(w*65/100,0,w*35/100,h/2),Rect2i(0,h/2,w/3,h/2),Rect2i(w/3,h/2,w/3,h/2),Rect2i(w*2/3,h/2,w-w*2/3,h/2)]
	var types := [1,21,2,3,23,11]
	for index in types.size():
		_crop(train,rectangles[index],"wagon-%02d" % types[index])
	for name in ["combat-actors-kit","combat-effects-kit"]:
		var image := Image.load_from_file(BASE + name + ".png")
		var indices := [0,1,4,5,8,9] if name == "combat-actors-kit" else [4,5,6,7,8]
		for index in indices:
			_crop(image,Rect2i(index%4*image.get_width()/4,index/4*image.get_height()/3,image.get_width()/4,image.get_height()/3),name.trim_prefix("combat-")+"-%02d" % index)
	var background := Image.load_from_file(BASE + "combat-background.png")
	background.save_png("res://assets/combat/background.png")
	print("PASS: authored combat crops generated")
	quit()
func _crop(image: Image, rect: Rect2i, name: String) -> void:
	var piece := image.get_region(rect)
	if name.begins_with("wagon-"):
		piece = _trim_wagon(piece)
	var used := piece.get_used_rect()
	piece = piece.get_region(used)
	piece.save_png("res://assets/combat/"+name+".png")

func _trim_wagon(image: Image) -> Image:
	# Authored grid crop can include wheel tips from the previous row.
	# Select rows belonging to the solid carriage, using alpha128 (travel atlas).
	var top := 0
	for y in image.get_height():
		var occupied := 0
		for x in image.get_width():
			if image.get_pixel(x,y).a >= 128.0/255.0: occupied += 1
		if occupied > image.get_width()/20:
			top = y
			break
	return image.get_region(Rect2i(0,top,image.get_width(),image.get_height()-top))
