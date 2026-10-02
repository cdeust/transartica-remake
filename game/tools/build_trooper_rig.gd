extends SceneTree
# MIT. Builds game/assets/combat/trooper-rig.png: cut-out pieces of the standing
# trooper of Codex's sheet (output/imagegen/actors-20261002/troopers-concept-v2.png,
# sha256 036edbc4…) for the procedural rig in scripts/tactical_trooper_rig.gd.
# Usage: Godot --headless --path game --script res://tools/build_trooper_rig.gd
# Prints the piece rectangles and pivots (texels) to paste into the rig.
const SOURCE := "res://../output/imagegen/actors-20261002/troopers-concept-v2.png"
const TARGET := "res://assets/combat/trooper-rig.png"
const PER := 4.0 # source: the 320x200 logical scene is shown at ~x4 (1280x800).
const STAND := 13.0 # source: current standing soldier height, 12.7 logical px.
const OPAQUE := 0.75 # source: measured sheet alpha; softer pixels are halo.
# Standing frames (connected components measured 2 October 2026); row1 = olive.
const FRAMES := [Rect2i(34,134,230,336),Rect2i(34,590,231,339)]
# Cut lines measured on the blue frame at 10px grid (belt 289-295, hem 405,
# coat slit x~130, front boot shaft 139-176, toe to 193). Olive frame: +456 rows.
const PIECES := {
	"upper": [Rect2i(34,134,232,163),Vector2(130,293)], # waist pivot
	"back": [Rect2i(34,290,98,121),Vector2(130,293)], # rear coat panel
	"front": [Rect2i(128,290,80,121),Vector2(130,293)], # front coat panel
	"boot": [Rect2i(135,412,62,61),Vector2(157,413)], # shaft-top pivot
}
const OLIVE_ROWS := 456
const TROUSER := [Vector2i(150,404),Vector2i(118,404)] # dark cloth under the hem

func _initialize() -> void:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	sheet.convert(Image.FORMAT_RGBA8)
	var scale := STAND*PER/FRAMES[0].size.y
	var pieces := []
	var height := 0
	for side in 2:
		var mask := _body(sheet,FRAMES[side])
		for name in PIECES:
			var cut: Rect2i = PIECES[name][0]
			cut.position.y += OLIVE_ROWS*side
			var pivot: Vector2 = PIECES[name][1]+Vector2(0,OLIVE_ROWS*side)
			var piece := Image.create(cut.size.x,cut.size.y,false,Image.FORMAT_RGBA8)
			for y in cut.size.y:
				for x in cut.size.x:
					var at := cut.position+Vector2i(x,y)
					if mask.has(at): piece.set_pixel(x,y,sheet.get_pixelv(at))
			var used := piece.get_used_rect()
			piece = piece.get_region(used)
			var origin := Vector2(cut.position+used.position)
			_bleed(piece,12)
			var size := Vector2i(maxi(1,roundi(used.size.x*scale)),maxi(1,roundi(used.size.y*scale)))
			while piece.get_width() > size.x*2:
				piece.resize(piece.get_width()/2,piece.get_height()/2,Image.INTERPOLATE_BILINEAR)
			piece.resize(size.x,size.y,Image.INTERPOLATE_BILINEAR)
			for y in size.y:
				for x in size.x:
					var colour := piece.get_pixel(x,y)
					piece.set_pixel(x,y,Color(colour.r,colour.g,colour.b,1.0) if colour.a >= 0.5 else Color(0,0,0,0))
			pieces.append({"side":side,"name":name,"image":piece,"pivot":(pivot-origin)*scale})
			height = maxi(height,size.y)
		for point in TROUSER:
			var colour := sheet.get_pixelv(point+Vector2i(0,OLIVE_ROWS*side))
			print("TROUSER ",side," ",colour.to_html(false))
	var atlas := Image.create(64*4,(height+2)*2,false,Image.FORMAT_RGBA8)
	for index in pieces.size():
		var entry: Dictionary = pieces[index]
		var at := Vector2i((index%4)*64+1,(index/4)*(height+2)+1)
		atlas.blit_rect(entry.image,Rect2i(Vector2i.ZERO,entry.image.get_size()),at)
		print("PIECE %d %s Rect2(%d,%d,%d,%d) pivot Vector2(%.1f,%.1f)" % [entry.side,entry.name,at.x,at.y,entry.image.get_width(),entry.image.get_height(),entry.pivot.x,entry.pivot.y])
	print("SCALE texels per source px %.4f" % scale)
	atlas.save_png(ProjectSettings.globalize_path(TARGET))
	quit()

# Opaque pixels connected to the frame's body (excludes neighbours' muzzles).
func _body(sheet: Image, frame: Rect2i) -> Dictionary:
	var seed := Vector2i(frame.position.x+frame.size.x/2,frame.position.y+frame.size.y/2)
	while sheet.get_pixelv(seed).a < OPAQUE: seed.y += 1
	var stack: Array[Vector2i] = [seed]
	var seen := {seed: true}
	while not stack.is_empty():
		var point: Vector2i = stack.pop_back()
		for step in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var next: Vector2i = point+step
			if seen.has(next) or not frame.has_point(next): continue
			if sheet.get_pixelv(next).a >= OPAQUE:
				seen[next] = true
				stack.append(next)
	return seen

# Spread edge colours into transparent texels so filtering adds no dark fringe.
func _bleed(image: Image, passes: int) -> void:
	for pass_index in passes:
		var source := image.duplicate()
		for y in image.get_height():
			for x in image.get_width():
				if source.get_pixel(x,y).a > 0: continue
				var sum := Vector3.ZERO
				var count := 0
				for step in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
					var nx: int = x+step.x
					var ny: int = y+step.y
					if nx < 0 or ny < 0 or nx >= image.get_width() or ny >= image.get_height(): continue
					var near: Color = source.get_pixel(nx,ny)
					if near.a > 0 or near.r+near.g+near.b > 0:
						sum += Vector3(near.r,near.g,near.b)
						count += 1
				if count > 0: image.set_pixel(x,y,Color(sum.x/count,sum.y/count,sum.z/count,0.0))
