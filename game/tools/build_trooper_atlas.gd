extends SceneTree
# MIT. Builds game/assets/combat/troopers.png from Codex's trooper concept sheet
# (output/imagegen/actors-20261002/troopers-concept-v2.png, sha256 036edbc4…).
# Usage: Godot --headless --path game --script res://tools/build_trooper_atlas.gd
# Steps: binary alpha, one connected body per frame (the sheet's frames overlap
# in x: a muzzle enters the next frame's rectangle), colour bleed, box-like
# halving to PER texels per logical px, binary alpha again, bottom-aligned cells.
const SOURCE := "res://../output/imagegen/actors-20261002/troopers-concept-v2.png"
const TARGET := "res://assets/combat/troopers.png"
const PER := 4.0 # source: the 320x200 logical scene is shown at ~x4 (1280x800).
const STAND := 13.0 # source: current standing soldier height, 12.7 logical px.
const OPAQUE := 0.75 # source: measured sheet alpha; softer pixels are halo.
# Frame rectangles: connected components >= 2000 px of the binary sheet,
# measured 2 October 2026. Order per row: stand, run a-d, crouch; row0 blue
# (player), row1 olive (enemy).
const FRAMES := [Rect2i(34,134,230,336),Rect2i(242,140,286,330),Rect2i(494,178,292,295),Rect2i(775,148,275,325),Rect2i(1035,134,264,339),Rect2i(1262,246,268,227),
	Rect2i(34,590,231,339),Rect2i(242,594,286,337),Rect2i(493,634,294,301),Rect2i(775,608,275,327),Rect2i(1035,592,265,343),Rect2i(1262,705,268,229)]

func _initialize() -> void:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SOURCE))
	sheet.convert(Image.FORMAT_RGBA8)
	var scale := STAND*PER/FRAMES[0].size.y
	var cell := Vector2i(int(ceil(300*scale))+4,int(ceil(345*scale))+4)
	var atlas := Image.create(cell.x*6,cell.y*2,false,Image.FORMAT_RGBA8)
	var lines := []
	for index in FRAMES.size():
		var body := _body(sheet.get_region(FRAMES[index]))
		var used := body.get_used_rect()
		body = body.get_region(used)
		var head := _head_column(body)
		_bleed(body,12)
		var size := Vector2i(maxi(1,roundi(used.size.x*scale)),maxi(1,roundi(used.size.y*scale)))
		while body.get_width() > size.x*2:
			body.resize(body.get_width()/2,body.get_height()/2,Image.INTERPOLATE_BILINEAR)
		body.resize(size.x,size.y,Image.INTERPOLATE_BILINEAR)
		for y in size.y:
			for x in size.x:
				var colour := body.get_pixel(x,y)
				body.set_pixel(x,y,Color(colour.r,colour.g,colour.b,1.0) if colour.a >= 0.5 else Color(0,0,0,0))
		var at := Vector2i((index%6)*cell.x+2,(index/6)*cell.y+cell.y-2-size.y)
		atlas.blit_rect(body,Rect2i(Vector2i.ZERO,size),at)
		lines.append("Rect2(%d,%d,%d,%d) head %.1f" % [at.x,at.y,size.x,size.y,head*scale])
	atlas.save_png(ProjectSettings.globalize_path(TARGET))
	for line in lines: print("CELL ",line)
	quit()

# The frame's own body: flood fill from its central column, binary alpha.
func _body(region: Image) -> Image:
	var size := region.get_size()
	var body := Image.create(size.x,size.y,false,Image.FORMAT_RGBA8)
	var seed := Vector2i(-1,-1)
	for y in range(size.y/3,size.y):
		if region.get_pixel(size.x/2,y).a >= OPAQUE:
			seed = Vector2i(size.x/2,y)
			break
	var stack: Array[Vector2i] = [seed]
	var seen := {seed: true}
	while not stack.is_empty():
		var point: Vector2i = stack.pop_back()
		var colour := region.get_pixelv(point)
		body.set_pixelv(point,Color(colour.r,colour.g,colour.b,1.0))
		for step in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var next: Vector2i = point+step
			if next.x < 0 or next.y < 0 or next.x >= size.x or next.y >= size.y or seen.has(next): continue
			if region.get_pixelv(next).a >= OPAQUE:
				seen[next] = true
				stack.append(next)
	return body

# Stable pivot: mean column of the hat (top 12%), unaffected by coat/rifle swing.
func _head_column(body: Image) -> float:
	var total := 0.0
	var count := 0
	for y in int(body.get_height()*0.12):
		for x in body.get_width():
			if body.get_pixel(x,y).a > 0:
				total += x
				count += 1
	return total/count

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
