extends RefCounted
# MIT. Sheet reading, cutting and measuring for res://tools/build_mammoth_poses.gd: the
# 8-connected opaque components of one of Codex's generated sheets (alpha >= OPAQUE; the soft
# halo and the background are ignored) dealt to the frames of its grid by centre, sprites cut
# out of a frame and shrunk by a scale (hard alpha), and the stance measures of a body frame
# (sole, hooves, mass centre, pivot). The source of every constant is the builder's header.
const DIR := "res://../output/imagegen/actors-20261002/"
const OPAQUE := 0.75 # source: measured sheet alpha; softer pixels are halo.
const NOISE := 40 # source: measured; smaller components are specks.
const FEET_BAND := 0.08 # source: authored; share of the body's height counted as hooves.
const PLANTED := 3 # source: authored; a hoof this close (source px) to the sole is planted.
const HOOF_GAP := 3 # source: measured; columns of clear space between two hooves.
var pieces := [] # {"image": Image}; table entries refer to them by index until packed.

func load_image(file: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(DIR+file))
	image.convert(Image.FORMAT_RGBA8)
	return image


# {image, ids, w, frames}: frames are row-major cells of the grid, each {comps, box}:
# the components (left to right) whose centre falls in the cell and their union.
func read(file: String, grid: Vector2i) -> Dictionary:
	var image := load_image(file)
	var w := image.get_width()
	var h := image.get_height()
	var ids := PackedInt32Array()
	ids.resize(w*h)
	var comps := []
	var count := 0
	for y in h:
		for x in w:
			if ids[y*w+x] != 0 or image.get_pixel(x,y).a < OPAQUE: continue
			count += 1
			var stack: Array[Vector2i] = [Vector2i(x,y)]
			ids[y*w+x] = count
			var low := Vector2i(x,y)
			var high := Vector2i(x,y)
			var area := 0
			while not stack.is_empty():
				var point: Vector2i = stack.pop_back()
				area += 1
				low = Vector2i(mini(low.x,point.x),mini(low.y,point.y))
				high = Vector2i(maxi(high.x,point.x),maxi(high.y,point.y))
				for dy in range(-1,2):
					for dx in range(-1,2):
						var next := point+Vector2i(dx,dy)
						if next.x < 0 or next.y < 0 or next.x >= w or next.y >= h or ids[next.y*w+next.x] != 0: continue
						if image.get_pixelv(next).a >= OPAQUE:
							ids[next.y*w+next.x] = count
							stack.append(next)
			if area >= NOISE: comps.append({"id":count,"box":Rect2i(low,high-low+Vector2i.ONE)})
	var frames := []
	for index in grid.x*grid.y: frames.append({"comps":[],"box":Rect2i(),"row":index/grid.x})
	for comp in comps:
		var centre := Vector2(comp.box.get_center())
		var column := clampi(int(centre.x/(w/float(grid.x))),0,grid.x-1)
		var row := clampi(int(centre.y/(h/float(grid.y))),0,grid.y-1)
		frames[row*grid.x+column].comps.append(comp)
	for frame in frames:
		frame.comps.sort_custom(func(a,b): return a.box.position.x < b.box.position.x)
		frame.box = frame.comps[0].box
		for comp in frame.comps: frame.box = frame.box.merge(comp.box)
	return {"image":image,"ids":ids,"w":w,"frames":frames,"scale":0.0}


func contains(sheet: Dictionary, frame: Dictionary, at: Vector2i) -> bool:
	var id: int = sheet.ids[at.y*sheet.w+at.x]
	if id == 0: return false
	for comp in frame.comps:
		if comp.id == id: return true
	return false


# Cut one sprite out of a frame: its component pixels where keep(at, colour)
# holds (all when invalid) and at least `above` source rows above `floor_y`
# (rows >= floor_y dropped; -1: none), made opaque, shrunk by scale. Components
# smaller than prune x the largest are dropped afterwards (rim strands). Returns
# {piece: index into pieces, origin: Vector2i source, size, foot: source px of the feet centroid at the sole}.
func cut(sheet: Dictionary, frame: Dictionary, scale: float, keep := Callable(), floor_y := -1, prune := 0.0) -> Dictionary:
	var box: Rect2i = frame.box
	var piece := Image.create(box.size.x,box.size.y,false,Image.FORMAT_RGBA8)
	for y in box.size.y:
		for x in box.size.x:
			var at := box.position+Vector2i(x,y)
			if (floor_y >= 0 and at.y >= floor_y) or not contains(sheet,frame,at): continue
			var colour: Color = sheet.image.get_pixelv(at)
			if keep.is_valid() and not keep.call(at,colour): continue
			piece.set_pixel(x,y,Color(colour.r,colour.g,colour.b,1.0))
	if prune > 0.0: prune(piece,prune)
	var used := piece.get_used_rect()
	piece = piece.get_region(used)
	var origin := box.position+used.position
	var band := maxi(2,int(used.size.y*FEET_BAND*1.5))
	var foot_sum := 0.0
	var foot_count := 0
	for y in range(used.size.y-band,used.size.y):
		for x in used.size.x:
			if piece.get_pixel(x,y).a > 0.5:
				foot_sum += x
				foot_count += 1
	var foot := Vector2(origin.x+foot_sum/maxi(foot_count,1),origin.y+used.size.y)
	var size := Vector2i(maxi(1,roundi(used.size.x*scale)),maxi(1,roundi(used.size.y*scale)))
	while piece.get_width() > size.x*2:
		piece.resize(piece.get_width()/2,piece.get_height()/2,Image.INTERPOLATE_BILINEAR)
	piece.resize(size.x,size.y,Image.INTERPOLATE_BILINEAR)
	# Opaque texels carry premultiplied colour (the rest is black): divide it out.
	for y in size.y:
		for x in size.x:
			var colour := piece.get_pixel(x,y)
			piece.set_pixel(x,y,Color(colour.r/colour.a,colour.g/colour.a,colour.b/colour.a,1.0) if colour.a >= 0.5 else Color(0,0,0,0))
	pieces.append({"image":piece})
	return {"piece":pieces.size()-1,"origin":origin,"size":size,"foot":foot}


# Clear the opaque 8-connected components of an image smaller than share x the largest.
func prune(image: Image, share: float) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var seen := PackedInt32Array()
	seen.resize(w*h)
	var comps := []
	for y in h:
		for x in w:
			if seen[y*w+x] != 0 or image.get_pixel(x,y).a < 0.5: continue
			var members: Array[Vector2i] = []
			var stack: Array[Vector2i] = [Vector2i(x,y)]
			seen[y*w+x] = 1
			while not stack.is_empty():
				var point: Vector2i = stack.pop_back()
				members.append(point)
				for dy in range(-1,2):
					for dx in range(-1,2):
						var next := point+Vector2i(dx,dy)
						if next.x < 0 or next.y < 0 or next.x >= w or next.y >= h or seen[next.y*w+next.x] != 0 or image.get_pixelv(next).a < 0.5: continue
						seen[next.y*w+next.x] = 1
						stack.append(next)
			comps.append(members)
	var largest := 0
	for members in comps: largest = maxi(largest,members.size())
	for members in comps:
		if members.size() < largest*share:
			for point in members: image.set_pixelv(point,Color(0,0,0,0))


# Source-px geometry of a frame's body: sole (bottom row), pivot x (centroid of
# the lowest FEET_BAND) and the hoof blobs' centres of the planted feet.
func measure(sheet: Dictionary, frame: Dictionary) -> Dictionary:
	var box: Rect2i = frame.box
	var sole := box.end.y
	var band := maxi(2,int(box.size.y*FEET_BAND))
	var sum := 0.0
	var count := 0
	var columns := {}
	var mass := 0.0
	var area := 0
	for y in range(box.position.y,sole):
		for x in range(box.position.x,box.end.x):
			if not contains(sheet,frame,Vector2i(x,y)): continue
			mass += x
			area += 1
			if y < sole-band: continue
			sum += x
			count += 1
			if y >= sole-PLANTED: columns[x] = true
	var xs := columns.keys()
	xs.sort()
	var blobs := []
	var start := -1
	var last := -1
	for x in xs:
		if start < 0:
			start = x
		elif x-last > HOOF_GAP:
			blobs.append((start+last+1)/2.0)
			start = x
		last = x
	if start >= 0: blobs.append((start+last+1)/2.0)
	var feet_x := sum/maxi(count,1)
	var centre := mass/maxi(area,1)
	return {"sole":sole,"feet_x":feet_x,"centre":centre,"feet":blobs}


# Stance of a frame with the pivot on the body's mass centre, offset by what the stopped frame
# (index 8) measures between hooves and mass: a frame with few hooves down (a blow, a fall)
# keeps the body where it was instead of jumping with its hoof centroid.
func stance(sheet: Dictionary, frame: Dictionary) -> Dictionary:
	if not sheet.has("delta"):
		var stopped := measure(sheet,sheet.frames[8])
		sheet.delta = stopped.feet_x-stopped.centre
	var stance := measure(sheet,frame)
	stance.x = stance.centre+sheet.delta
	return stance


# sqrt of the largest warm cream blob (tusk) area of a frame, source px.
func tusk(sheet: Dictionary, frame: Dictionary) -> float:
	var seen := {}
	var best := 0
	var box: Rect2i = frame.box
	for y in range(box.position.y,box.end.y):
		for x in range(box.position.x,box.end.x):
			var point := Vector2i(x,y)
			if seen.has(point) or not warm(sheet.image.get_pixelv(point)): continue
			var stack: Array[Vector2i] = [point]
			seen[point] = true
			var area := 0
			while not stack.is_empty():
				var at: Vector2i = stack.pop_back()
				area += 1
				for step in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
					var next: Vector2i = at+step
					if seen.has(next) or not box.has_point(next) or not warm(sheet.image.get_pixelv(next)): continue
					seen[next] = true
					stack.append(next)
			best = maxi(best,area)
	return best


func warm(colour: Color) -> bool:
	return colour.a > 0.9 and colour.r > 0.78 and colour.r-colour.b > 0.1 and colour.g > 0.6
