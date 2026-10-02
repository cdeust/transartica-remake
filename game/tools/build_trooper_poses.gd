extends SceneTree
# MIT. Builds game/assets/combat/trooper-poses.png: whole-body sprite poses the
# cut-out rig cannot do (climb and mantle, kneeling to light a charge, two
# deaths), cut from Codex's generated sheets in output/imagegen/actors-20261002/
# (*-generated.png, hashes in trooper-poses-runtime.json). Row 0 is the blue
# side, row 1 the olive one.
# Usage: Godot --headless --path game --script res://tools/build_trooper_poses.gd
# Prints every frame's atlas Rect2 and ground pivot (texels) to paste into
# scripts/tactical_trooper_poses.gd.
# Method: opaque pixels (alpha >= OPAQUE, soft halo and background ignored) are
# grouped in 8-connected components; every small component (a flying or fallen
# rifle) joins the nearest body of its frame, so detached parts survive.
# Scale: the soldiers of the sheets are drawn at different sizes, so each sheet
# is scaled by its head against the rig's standing soldier: the cream pompom on
# the hood is round, side-on and visible in every pose; its diameter
# sqrt(area) on the sheet's reference frame is compared with the same measure
# on troopers-concept-v2's standing frame, which the rig is cut from. The
# numbers are printed (HEAD lines).
# Pivots are computed: climb and plant frames sit on the centroid of their
# lowest band of body pixels (the feet); falls hang from the body's centroid (the
# hip stays where it was while he drops); y is one ground line per row (the
# reference frame's sole), except grounded frames, which stand on their own
# lowest pixel (the mantle on the roof). x is shared by both rows.
const DIR := "res://../output/imagegen/actors-20261002/"
const CONCEPT := "res://../output/imagegen/actors-20261002/troopers-concept-v2.png"
const CONCEPT_FRAME := Rect2i(34,134,230,336) # standing blue soldier (build_trooper_rig.gd).
const TARGET := "res://assets/combat/trooper-poses.png"
const PER := 4.0 # source: the 320x200 logical scene is shown at ~x4 (1280x800).
const STAND := 13.0 # source: standing soldier height, 12.7 logical px (build_trooper_rig.gd).
const OPAQUE := 0.75 # source: measured sheet alpha; softer pixels are halo.
const BODY_AREA := 15000 # source: measured; bodies are 25000+ px, rifles and boxes under 8000.
const NOISE := 60 # source: measured; smaller components are specks.
const JOIN := 80 # source: measured; a rifle lies within this many px of its body.
const ATLAS_WIDTH := 512
const FEET_BAND := 0.12 # source: authored; share of the body's height counted as feet.
const POMPOM_MIN := 0.62 # source: measured; the pompom's shaded part is still above this on every sheet.
const POMPOM_MAX := 1200 # source: measured; the collar beside it is 1300+ px, the pompom 320-830.
const POMPOM_SPREAD := 0.25 # source: measured; cream stays near grey.
# ref: frame whose sole is the row's ground line and whose head sets the scale.
# feet: false hangs the frame from its centroid. grounded: frames standing on
# their own lowest pixel. cuts: rectangles of row 0 (olive: shifted by the row
# offset) that are not the soldier (the box and its fuse; the game draws the
# charge itself); box: x of the box's left edge, for the reach printed.
const SHEETS := [
	{"name":"climb","file":"trooper-climb-mantle-generated.png","ref":2,"feet":true,"grounded":[4],"cuts":{}},
	{"name":"plant","file":"trooper-plant-generated.png","ref":2,"frames":2,"feet":true,"grounded":[0,1],
	 "box":[352,849],"cuts":{0:[Rect2i(352,450,300,100),Rect2i(410,400,100,60)],1:[Rect2i(849,450,300,100),Rect2i(862,0,400,500)]}},
	{"name":"fall_forward","file":"trooper-death-forward-generated.png","ref":0,"feet":false,"grounded":[],"cuts":{}},
	{"name":"fall_back","file":"trooper-death-backward-generated.png","ref":1,"feet":false,"grounded":[],"cuts":{}},
]

var _head_area := 0

func _initialize() -> void:
	var concept := Image.load_from_file(ProjectSettings.globalize_path(CONCEPT))
	concept.convert(Image.FORMAT_RGBA8)
	_head_area = _head(concept,CONCEPT_FRAME)
	var frames := []
	for sheet in SHEETS: frames.append_array(_sheet(sheet))
	var rows := []
	var cursor := Vector2i(1,1)
	var shelf := 0
	var atlas := Image.create(ATLAS_WIDTH,1024,false,Image.FORMAT_RGBA8)
	for frame in frames:
		var size: Vector2i = frame.image.get_size()
		if cursor.x+size.x+1 > ATLAS_WIDTH:
			cursor = Vector2i(1,cursor.y+shelf+1)
			shelf = 0
		atlas.blit_rect(frame.image,Rect2i(Vector2i.ZERO,size),cursor)
		print("FRAME %s side %d #%d Rect2(%d,%d,%d,%d) pivot Vector2(%.1f,%.1f)" % [frame.name,frame.side,frame.index,cursor.x,cursor.y,size.x,size.y,frame.pivot.x,frame.pivot.y])
		cursor.x += size.x+1
		shelf = maxi(shelf,size.y)
	atlas = atlas.get_region(Rect2i(0,0,ATLAS_WIDTH,cursor.y+shelf+1))
	atlas.save_png(ProjectSettings.globalize_path(TARGET))
	print("ATLAS ",atlas.get_size())
	quit()


func _sheet(sheet: Dictionary) -> Array:
	var image := Image.load_from_file(ProjectSettings.globalize_path(DIR+sheet.file))
	image.convert(Image.FORMAT_RGBA8)
	var label := _label(image)
	var groups := _group(label,image.get_size())
	var head := _head(image,groups[0][sheet.ref].bbox)
	var scale: float = STAND*PER/CONCEPT_FRAME.size.y*sqrt(float(_head_area)/head)
	print("HEAD %s pompom area %d (concept %d) -> scale %.4f texels per source px; reference frame %d px tall = %.1f logical px" % [sheet.name,head,_head_area,scale,groups[0][sheet.ref].bbox.size.y,groups[0][sheet.ref].bbox.size.y*scale/PER])
	var out := []
	var base := [0.0,0.0]
	for side in 2:
		var row: Array = groups[side]
		base[side] = row[sheet.ref].bbox.end.y
	for side in 2:
		var row: Array = groups[side]
		for index in row.size():
			if sheet.has("frames") and index >= sheet.frames: continue
			var group: Dictionary = row[index]
			var box: Rect2i = group.bbox
			var ids: Array = group.ids
			var cuts: Array = sheet.cuts.get(index,[])
			var shift := int(base[side]-base[0])
			var piece := Image.create(box.size.x,box.size.y,false,Image.FORMAT_RGBA8)
			var body: Array[Vector2i] = []
			for y in box.size.y:
				for x in box.size.x:
					var at := box.position+Vector2i(x,y)
					if not ids.has(label.ids[at.y*image.get_width()+at.x]) or _cut(cuts,at,shift): continue
					var colour := image.get_pixelv(at)
					piece.set_pixel(x,y,Color(colour.r,colour.g,colour.b,1.0))
					if label.ids[at.y*image.get_width()+at.x] == ids[0]: body.append(at)
			var used := piece.get_used_rect()
			piece = piece.get_region(used)
			var origin := box.position+used.position
			var size := Vector2i(maxi(1,roundi(used.size.x*scale)),maxi(1,roundi(used.size.y*scale)))
			while piece.get_width() > size.x*2:
				piece.resize(piece.get_width()/2,piece.get_height()/2,Image.INTERPOLATE_BILINEAR)
			piece.resize(size.x,size.y,Image.INTERPOLATE_BILINEAR)
			# Opaque texels carry premultiplied colour (the rest is black): divide it out.
			for y in size.y:
				for x in size.x:
					var colour := piece.get_pixel(x,y)
					piece.set_pixel(x,y,Color(colour.r/colour.a,colour.g/colour.a,colour.b/colour.a,1.0) if colour.a >= 0.5 else Color(0,0,0,0))
			var anchor := _anchor(body,sheet.feet)
			var ground: float = _bottom(body) if sheet.grounded.has(index) else base[side]
			var pivot: Vector2 = (Vector2(anchor,ground)-Vector2(origin))*scale
			if side == 0:
				var front: float = (_right(body)-anchor)*scale/PER # logical px from the pivot to the frame's front
				var reach: float = ((sheet.box[index]-anchor)*scale/PER) if sheet.has("box") else 0.0
				print("EXTENT %s #%d front %.2f box edge %.2f logical px ahead of the pivot" % [sheet.name,index,front,reach])
			out.append({"name":sheet.name,"side":side,"index":index,"image":piece,"pivot":pivot})
	return out


func _cut(cuts: Array, at: Vector2i, shift: int) -> bool:
	for rect in cuts:
		if Rect2i(rect.position+Vector2i(0,shift),rect.size).has_point(at): return true
	return false


# 8-connected components of opaque pixels: {ids: id per pixel, boxes: {id: [Rect2i, area]}}.
func _label(image: Image) -> Dictionary:
	var w := image.get_width()
	var h := image.get_height()
	var ids := PackedInt32Array()
	ids.resize(w*h)
	var boxes := {}
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
			if area >= NOISE: boxes[count] = [Rect2i(low,high-low+Vector2i.ONE),area]
	return {"ids":ids,"boxes":boxes}


# Frames per row: each body (big component) plus the small ones beside it.
# Returns [row0, row1], frames left to right: {ids, bbox}.
func _group(label: Dictionary, size: Vector2i) -> Array:
	var bodies := []
	var small := []
	for id in label.boxes:
		var entry: Array = label.boxes[id]
		(bodies if entry[1] >= BODY_AREA else small).append({"id":id,"box":entry[0]})
	var frames := []
	for body in bodies: frames.append({"ids":[body.id],"bbox":body.box})
	for part in small:
		var best := -1
		var near := float(JOIN)
		for index in frames.size():
			var gap := _gap(frames[index].bbox,part.box)
			if gap < near:
				near = gap
				best = index
		if best >= 0:
			frames[best].ids.append(part.id)
			frames[best].bbox = frames[best].bbox.merge(part.box)
	var rows := [[],[]]
	for frame in frames: rows[0 if frame.bbox.get_center().y < size.y/2.0 else 1].append(frame)
	for row in rows: row.sort_custom(func(a,b): return a.bbox.position.x < b.bbox.position.x)
	return rows


func _gap(a: Rect2i, b: Rect2i) -> float:
	var dx := maxi(0,maxi(a.position.x-b.end.x,b.position.x-a.end.x))
	var dy := maxi(0,maxi(a.position.y-b.end.y,b.position.y-a.end.y))
	return Vector2(dx,dy).length()


# Pivot x in sheet px: centroid of the lowest FEET_BAND of the body (feet) or of all of it.
func _anchor(body: Array[Vector2i], feet: bool) -> float:
	var low := _bottom(body)
	var top := low
	for point in body: top = mini(top,point.y)
	var sum := 0.0
	var count := 0
	for point in body:
		if feet and point.y < low-(low-top)*FEET_BAND: continue
		sum += point.x
		count += 1
	return sum/maxi(count,1)


func _bottom(body: Array[Vector2i]) -> int:
	var low := 0
	for point in body: low = maxi(low,point.y+1)
	return low


func _right(body: Array[Vector2i]) -> int:
	var far := 0
	for point in body: far = maxi(far,point.x+1)
	return far


# Pompom area in px: the topmost cream blob of the soldier inside frame.
func _head(image: Image, frame: Rect2i) -> int:
	var seen := {}
	var best := [INF,0]
	for y in range(frame.position.y,frame.end.y):
		for x in range(frame.position.x,frame.end.x):
			var point := Vector2i(x,y)
			if seen.has(point) or not _cream(image.get_pixelv(point)): continue
			var stack: Array[Vector2i] = [point]
			seen[point] = true
			var area := 0
			while not stack.is_empty():
				var at: Vector2i = stack.pop_back()
				area += 1
				for step in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
					var next: Vector2i = at+step
					if seen.has(next) or not frame.has_point(next) or not _cream(image.get_pixelv(next)): continue
					seen[next] = true
					stack.append(next)
			if area >= 100 and area < POMPOM_MAX and y < best[0]: best = [y,area]
	return best[1]


func _cream(colour: Color) -> bool:
	var high := maxf(colour.r,maxf(colour.g,colour.b))
	var low := minf(colour.r,minf(colour.g,colour.b))
	return colour.a > 0.9 and low > POMPOM_MIN and high-low < POMPOM_SPREAD
