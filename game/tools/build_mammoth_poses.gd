extends SceneTree
# MIT. Builds game/assets/combat/mammoth-poses.png and the frame table
# game/scripts/tactical_mammoth_frames.gd from Codex's generated sheets in
# output/imagegen/actors-20261002/ (hashes in mammoth-poses-runtime.json):
# the bare mammoth, the howdah variants (blue and olive), the rider layers and
# the dismount frames. Usage:
#   Godot --headless --path game --script res://tools/build_mammoth_poses.gd
# Swapping in corrected sheets (-v2 suffix) is a change of the SHEETS constant.
#
# Method (as build_trooper_poses.gd): opaque pixels (alpha >= OPAQUE; the soft
# halo and the background are ignored) are grouped in 8-connected components.
# Frames are named by their place in the prompt's list
# (mammoth-pose-prompts.json); the generated cells are not the 560x440 asked
# for, so the sheet grid only deals components to frames by their centre.
#
# Scales (texels per source px), all printed as SCALE lines:
#  - bare sheet: the stopped mammoth (stop 1) is drawn as tall as the former
#    single pose (actors-master pose 8, 410x295 source px shown at a 28 logical px
#    limit, i.e. 20.1 px tall).
#  - howdah sheets: the tusk is the one warm cream blob of every walk frame; the
#    ratio of its sqrt(area) to the bare sheet's, mean of the 8 walk frames,
#    sets the scale (the howdah box would corrupt a bbox comparison).
#  - dismount sheet: troopers' scale, not the mammoth's: the standing soldier
#    (frame 1, rim cut away) is STAND logical px tall. The riders sheets are tied
#    to it by the ushanka's white badge (same trooper, same badge).
# Pivots: x = centroid of the lowest FEET_BAND of the body (the hooves), y = the
# frame's sole, the common ground line (GROUND prints each body frame's gap to
# its sheet's median sole). Planted feet: hoof blobs within PLANTED px of the
# sole; consecutive walk frames are matched by the shift keeping most hooves in
# place, which gives STEP: the texels the body advances from frame i to i+1 so
# that planted hooves stay put. Rider seats are measured on the howdah frame
# (wooden rim, box width), never from the rider sheet's own positions.
const Sheets = preload("res://tools/mammoth_sheets.gd")
const SHEETS := {
	"bare": "mammoth-bare-generated.png",
	"howdah": ["mammoth-player-howdah-generated.png","mammoth-enemy-howdah-generated.png"],
	"riders": ["mammoth-player-riders-generated.png","mammoth-enemy-riders-generated.png"],
	"dismount": "mammoth-dismount-generated.png",
}
const TARGET := "res://assets/combat/mammoth-poses.png"
const TABLE := "res://scripts/tactical_mammoth_frames.gd"
const PER := 4.0 # source: the 320x200 logical scene is shown at ~x4 (1280x800).
const STAND := 13.0 # source: standing soldier height, 12.7 logical px (build_trooper_rig.gd).
const OLD_POSE := Vector2(410,295) # source: actors-master pose 8 bounds, tactical_actor_art.gd.
const OLD_LIMIT := 28.0 # source: tactical_actor_art.gd draw_pose limit for mammoths.
const ATLAS_WIDTH := 1024
const SEAT_SPLIT := 0.58 # source: authored; share of a seated rider's height above the howdah rim (hips at the rim).
const TORSO := 40 # source: measured; source px above the soles that only the soldier reaches (the rim posts stop below).
const BOOTS := 60 # source: measured; source px a boot reaches beyond the torso.
const SNOW := 6 # source: measured; rows of snow on the dismount sheet's rim above its wood.
const RIM_ROWS := 0.45 # source: authored; the rim is the first row holding this share of the widest wooden row.
const SEATED := 17 # source: the prompt: death 2 (index 17) onward the riders are airborne, not seated.
const ARC := 8.0 # source: authored; logical px a thrown rider rises above the straight path.
const RIDER_RATIO := 1.33 # source: measured 2 October 2026 on 2x crops of the dismount frame 1 and the riders frame 1: hood width 70/57 px = 1.23, hood height 75/52 px = 1.44, mean 1.33 (the riders are drawn with smaller heads; both sheets asked for 256 px standing).
const REACH := 2.2 # source: authored; logical px, the most a body advances between two walk frames (the median backward move of a hoof is 1.2).
const LEAST := 1.1 # source: authored; logical px, the least a walk frame advances: the sheets' hooves barely travel against the body (median backward move 0.7-0.9 px per frame), which at the 14 px/s gait would play the legs at 20 frames/s; at 1.1 they play at ~13.
const TOLERANCE := 0.5 # source: authored; logical px within which two hooves are the same one.
# Frame order per sheet, row-major (prompt SHEET1 / SHEET2): bare walk 8, stop 2, melee 4, hit 2, death 8;
# mounted walk 8, stop 2, hit 2, melee 4, death 5. Motions in the runtime tables' order.
const MOTIONS := ["walk","stop","melee","hit","death"]
const BARE_ORDER := [0,0,0,0,0,0,0,0,1,1,2,2,2,2,3,3,4,4,4,4,4,4,4,4]
const MOUNT_ORDER := [0,0,0,0,0,0,0,0,1,1,3,3,2,2,2,2,4,4,4,4,4]
const VARIANTS := ["bare","player","enemy"]

var sheets := Sheets.new()

func _initialize() -> void:
	var bare := sheets.read(SHEETS.bare,Vector2i(6,4))
	var height := OLD_POSE.y*minf(OLD_LIMIT/OLD_POSE.x,OLD_LIMIT/OLD_POSE.y) # logical px
	var stop_box: Rect2i = bare.frames[8].box
	var base := height*PER/stop_box.size.y
	print("SCALE bare %.4f texel/px: stop frame %d x %d px -> %.2f x %.2f logical px (former pose %.2f x %.2f)" % [base,stop_box.size.x,stop_box.size.y,stop_box.size.x*base/PER,stop_box.size.y*base/PER,OLD_POSE.x*minf(OLD_LIMIT/OLD_POSE.x,OLD_LIMIT/OLD_POSE.y),height])
	var table := {"body":[],"step":[],"feet":[],"seat":[],"riders":[],"dismount":[],"scale":{}}
	table.scale["bare"] = base
	table.body.append(_body(bare,BARE_ORDER,base,"bare",table))
	var bare_tusks := []
	for i in 8: bare_tusks.append(sheets.tusk(bare,bare.frames[i]))
	var mounts := []
	for side in 2:
		var sheet := sheets.read(SHEETS.howdah[side],Vector2i(7,3))
		var ratios := []
		for i in 8: ratios.append(sqrt(float(bare_tusks[i])/maxi(1,sheets.tusk(sheet,sheet.frames[i]))))
		var scale: float = base*_mean(ratios)
		print("SCALE %s howdah %.4f texel/px (tusk ratio mean %.3f, min %.3f, max %.3f)" % [VARIANTS[side+1],scale,_mean(ratios),ratios.min(),ratios.max()])
		table.scale[VARIANTS[side+1]] = scale
		sheet.scale = scale
		table.body.append(_body(sheet,MOUNT_ORDER,scale,VARIANTS[side+1],table))
		mounts.append(sheet)
	var trooper := _dismount(table)
	for side in 2: _riders(side,table,mounts[side],trooper)
	_pack(table)
	quit()


# ------------------------------------------------------------------ sheets

func _mean(values: Array) -> float:
	var sum := 0.0
	for value in values: sum += value
	return sum/maxi(1,values.size())


# The body frames of a sheet by motion: [motion][index] = {piece, pivot, rim}; records
# STEP and the planted feet of the walk (texels, relative to the pivot).
func _body(sheet: Dictionary, order: Array, scale: float, name: String, table: Dictionary) -> Array:
	var motions := []
	for motion in MOTIONS.size(): motions.append([])
	var stances := []
	for index in order.size():
		var frame: Dictionary = sheet.frames[index]
		var stance := sheets.stance(sheet,frame)
		stances.append(stance)
	var rows := {}
	for index in order.size():
		var row: int = sheet.frames[index].row
		if not rows.has(row): rows[row] = []
		rows[row].append(stances[index].sole)
	for row in rows: rows[row].sort()
	for index in order.size():
		var frame: Dictionary = sheet.frames[index]
		var cut := sheets.cut(sheet,frame,scale)
		var stance: Dictionary = stances[index]
		var pivot := (Vector2(stance.x,stance.sole)-Vector2(cut.origin))*scale
		var entry := {"piece":cut.piece,"pivot":pivot,"size":cut.size,"stance":stance,"frame":frame}
		motions[order[index]].append(entry)
		print("FRAME %s %s #%d box %s pivot %s feet %s ground %+d px" % [name,MOTIONS[order[index]],motions[order[index]].size()-1,frame.box,pivot,stance.feet,stance.sole-rows[frame.row][rows[frame.row].size()/2]])
	var walk: Array = motions[0]
	var feet := []
	for index in 8:
		var row := []
		for foot in walk[index].stance.feet: row.append((foot-walk[index].stance.x)*scale/PER)
		feet.append(row)
	var usual := _usual(feet)
	var steps := []
	for index in 8: steps.append(_shift(feet[index],feet[(index+1)%8],usual)) # logical px the body advances while the planted hooves stay
	print("STEP %s logical px per frame %s ; usual %.2f ; stride %.2f px per cycle" % [name,steps.map(func(v): return snappedf(v,0.01)),usual,_sum(steps)])
	table.step.append(steps)
	table.feet.append(feet)
	return motions


func _sum(values: Array) -> float:
	var sum := 0.0
	for value in values: sum += value
	return sum


# Logical px the body advances from walk frame a to b keeping the most planted hooves where they
# are (within TOLERANCE, advance within LEAST..REACH); among equally good shifts the one nearest
# `usual`. Hoof offsets are in logical px from each frame's pivot.
func _shift(a: Array, b: Array, usual: float) -> float:
	var best := usual
	var votes := 0
	var candidates := [maxf(usual,LEAST)]
	for foot_a in a:
		for foot_b in b:
			var shift: float = foot_a-foot_b
			if shift >= LEAST and shift <= REACH: candidates.append(shift)
	for shift in candidates:
		var inliers := []
		for foot_a in a:
			for foot_b in b:
				var other: float = foot_a-foot_b
				if absf(other-shift) <= TOLERANCE: inliers.append(other)
		if inliers.size() > votes or (inliers.size() == votes and absf(_mean(inliers)-usual) < absf(best-usual)):
			votes = inliers.size()
			best = _mean(inliers)
	return maxf(best,LEAST)


# Median of the backward moves (logical px) of each planted hoof to its nearest hoof of the next frame.
func _usual(feet: Array) -> float:
	var moves := []
	for index in 8:
		for foot in feet[index]:
			var near: float = feet[(index+1)%8].reduce(func(best, other): return other if absf(other-foot) < absf(best-foot) else best)
			if foot-near > 0.0 and foot-near < 5.0: moves.append(foot-near)
	moves.sort()
	return moves[moves.size()/2]


# ------------------------------------------------------------------ rim and seats

func _wood(colour: Color) -> bool:
	var high := maxf(colour.r,maxf(colour.g,colour.b))
	var low := minf(colour.r,minf(colour.g,colour.b))
	return colour.a > 0.9 and colour.r > colour.g*1.05 and colour.g > colour.b*1.05 and high > 0.2 and high < 0.75 and (high-low)/high > 0.25


# Wooden rim of a howdah (or the dismount sheet's rim) in a frame: {y: first row of wood, left, right}, source px.
func _rim(sheet: Dictionary, frame: Dictionary) -> Dictionary:
	var box: Rect2i = frame.box
	var rows := {}
	var widest := 0
	for y in range(box.position.y,box.end.y):
		var n := 0
		for x in range(box.position.x,box.end.x):
			if sheets.contains(sheet,frame,Vector2i(x,y)) and _wood(sheet.image.get_pixel(x,y)): n += 1
		rows[y] = n
		widest = maxi(widest,n)
	var top := box.position.y
	for y in range(box.position.y,box.end.y):
		if rows[y] >= widest*RIM_ROWS:
			top = y
			break
	var left := box.end.x
	var right := box.position.x
	for y in range(top+3,top+13):
		for x in range(box.position.x,box.end.x):
			if sheets.contains(sheet,frame,Vector2i(x,y)) and _wood(sheet.image.get_pixel(x,y)):
				left = mini(left,x)
				right = maxi(right,x+1)
	return {"y":top,"left":left,"right":right}


# ------------------------------------------------------------------ dismount and riders

# Dismount sheet: 5 columns x 2 rows (blue, olive). The rim fragments are cut away (rows below
# the soldier's soles in frames 1-2, wood, snow and iron by colour in frame 3). Returns the trooper
# scale. table.dismount[side][k] = {piece, pivot}.
func _dismount(table: Dictionary) -> Dictionary:
	var sheet := sheets.read(SHEETS.dismount,Vector2i(5,2))
	var stand := 0.0
	var scale := 0.0
	var rows := []
	var floors := {} # the olive row repeats the blue row's geometry, one row lower: its rim is cut at the same rows
	var drop: int = sheet.image.get_height()/2
	for side in 2:
		var row := []
		for k in 5:
			var frame: Dictionary = sheet.frames[side*5+k]
			var cut := {}
			if k < 2:
				if side == 0:
					var rim := _rim(sheet,frame)
					floors[k] = rim.y-SNOW
					if k == 0:
						stand = floors[k]-frame.box.position.y
						scale = STAND*PER/stand
						print("SCALE dismount %.4f texel/px: standing soldier %d px (rim row %d) -> %.1f logical px" % [scale,stand,rim.y,STAND])
				var reach := _torso(sheet,frame,floors[k]+side*drop)
				cut = sheets.cut(sheet,frame,scale,func(at: Vector2i, _colour: Color): return at.x >= reach.x and at.x < reach.y,floors[k]+side*drop,0.1)
			elif k == 2:
				var rim := Rect2i(frame.box.position,Vector2i(frame.box.size.x,int(frame.box.size.y*0.32)))
				var thick := _opened(sheet,rim,3)
				var hugging := _hugging(sheet,rim,2)
				cut = sheets.cut(sheet,frame,scale,func(at: Vector2i, colour: Color): return not rim.has_point(at) or not (_rim_colour(colour) or (_ink(colour) and not thick.has(at) and not hugging.has(at))),-1,0.05)
			else:
				cut = sheets.cut(sheet,frame,scale)
			row.append({"piece":cut.piece,"pivot":(cut.foot-Vector2(cut.origin))*scale,"size":cut.size})
		rows.append(row)
	table.dismount = rows
	return {"scale":scale}


# Columns [first, last+1) the standing soldier spans above his boots (more than TORSO rows over the cut) widened by
# BOOTS each way: the rim's posts, farther out, are not his.
func _torso(sheet: Dictionary, frame: Dictionary, floor_y: int) -> Vector2i:
	var low: int = frame.box.end.x
	var high: int = frame.box.position.x
	for y in range(frame.box.position.y,floor_y-TORSO):
		for x in range(frame.box.position.x,frame.box.end.x):
			if sheets.contains(sheet,frame,Vector2i(x,y)):
				low = mini(low,x)
				high = maxi(high,x+1)
	return Vector2i(low-BOOTS,high+BOOTS)


# Neutral near-black (outlines, gloves, boots), not a dark coat.
func _ink(colour: Color) -> bool:
	return colour.a > 0.9 and maxf(colour.r,maxf(colour.g,colour.b)) < 0.22 and absf(colour.r-colour.b) < 0.08


# Ink pixels of a rect that survive an opening of the given radius: the thick ones (gloves), not the thin outlines.
func _opened(sheet: Dictionary, rect: Rect2i, radius: int) -> Dictionary:
	var core := {}
	for y in range(rect.position.y+radius,rect.end.y-radius):
		for x in range(rect.position.x+radius,rect.end.x-radius):
			var inside := true
			for dy in range(-radius,radius+1):
				for dx in range(-radius,radius+1):
					inside = inside and _ink(sheet.image.get_pixel(x+dx,y+dy))
					if not inside: break
				if not inside: break
			if inside: core[Vector2i(x,y)] = true
	var kept := {}
	for point in core:
		for dy in range(-radius,radius+1):
			for dx in range(-radius,radius+1): kept[point+Vector2i(dx,dy)] = true
	return kept


# Wood, snow and iron of the howdah rim, by colour: brown planks, bluish white snow, grey ring and rivets
# (the coat is blue or olive, the gloves ink, the skin and the collar warm and brighter).
func _rim_colour(colour: Color) -> bool:
	if colour.a < 0.9: return false
	var high := maxf(colour.r,maxf(colour.g,colour.b))
	var low := minf(colour.r,minf(colour.g,colour.b))
	if colour.r > colour.g*1.2 and colour.g > colour.b*1.1 and colour.r-colour.b > 0.1 and high < 0.75: return true # planks (olive coats are not as red)
	if colour.b >= colour.r and low > 0.7: return true # snow
	return high-low < 0.1 and high > 0.3 and high < 0.8 # iron


# Pixels of a rect within radius of a soldier colour (not ink, not rim): the soldier's own outline.
func _hugging(sheet: Dictionary, rect: Rect2i, radius: int) -> Dictionary:
	var near := {}
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			var colour: Color = sheet.image.get_pixel(x,y)
			if colour.a < 0.9 or _ink(colour) or _rim_colour(colour): continue
			for dy in range(-radius,radius+1):
				for dx in range(-radius,radius+1): near[Vector2i(x+dx,y+dy)] = true
	return near


# Rider layers of one side: table.riders[side][motion][index] = {parts: [{piece, off}], merged}.
# A seated pair is cut at the hips (SEAT_SPLIT of its height) and its hips set on the howdah rim of
# the same frame; the airborne frames are single sprites on an authored arc from the seat to the
# ground beside the fallen body.
func _riders(side: int, table: Dictionary, mount: Dictionary, trooper: Dictionary) -> void:
	var sheet := sheets.read(SHEETS.riders[side],Vector2i(7,3))
	var scale: float = trooper.scale*RIDER_RATIO
	print("SCALE riders %d %.4f texel/px (dismount %.4f x %.2f)" % [side,scale,trooper.scale,RIDER_RATIO])
	var motions := []
	for motion in MOTIONS.size(): motions.append([])
	var seats := []
	for motion in MOTIONS.size(): seats.append([])
	var anchor := Vector2.ZERO
	var landing := Vector2.ZERO
	var last := sheets.stance(mount,mount.frames[20])
	landing.x = (mount.frames[20].box.position.x-last.x)*mount.scale
	for index in 21:
		var frame: Dictionary = sheet.frames[index]
		var stance := sheets.stance(mount,mount.frames[index])
		var rim := _rim(mount,mount.frames[index])
		var seat := Vector2(((rim.left+rim.right)/2.0-stance.x)*mount.scale,(rim.y-stance.sole)*mount.scale)
		var entry := {"parts":[],"merged":frame.comps.size() == 1}
		if index == 16: anchor = seat
		if index < SEATED:
			var clip: int = frame.box.position.y+int(SEAT_SPLIT*frame.box.size.y)
			for comp in frame.comps:
				var cut := sheets.cut(sheet,{"comps":[comp],"box":comp.box},scale,Callable(),clip)
				var off := seat+(Vector2(cut.origin)-Vector2(frame.box.get_center().x,clip))*scale
				entry.parts.append({"piece":cut.piece,"off":off})
		else:
			var cut := sheets.cut(sheet,frame,scale)
			var t := float(index-16)/4.0
			var x := lerpf(anchor.x,landing.x-cut.size.x/2.0,t)
			var y := lerpf(anchor.y,0.0,t)-sin(PI*t)*ARC*PER
			entry.parts.append({"piece":cut.piece,"off":Vector2(x-cut.size.x/2.0,y-cut.size.y)})
			entry.merged = true
		motions[MOUNT_ORDER[index]].append(entry)
		seats[MOUNT_ORDER[index]].append(seat)
		print("RIDERS %d %s #%d parts %d seat %s" % [side,MOTIONS[MOUNT_ORDER[index]],motions[MOUNT_ORDER[index]].size()-1,entry.parts.size(),seat])
	table.riders.append(motions)
	table.seat.append(seats)


# ------------------------------------------------------------------ atlas and table

func _pack(table: Dictionary) -> void:
	var cursor := Vector2i(1,1)
	var shelf := 0
	var atlas := Image.create(ATLAS_WIDTH,2048,false,Image.FORMAT_RGBA8)
	for piece in sheets.pieces:
		var size: Vector2i = piece.image.get_size()
		if cursor.x+size.x+1 > ATLAS_WIDTH:
			cursor = Vector2i(1,cursor.y+shelf+1)
			shelf = 0
		atlas.blit_rect(piece.image,Rect2i(Vector2i.ZERO,size),cursor)
		piece.rect = Rect2i(cursor,size)
		cursor.x += size.x+1
		shelf = maxi(shelf,size.y)
	atlas = atlas.get_region(Rect2i(0,0,ATLAS_WIDTH,cursor.y+shelf+1))
	atlas.save_png(ProjectSettings.globalize_path(TARGET))
	print("ATLAS ",atlas.get_size()," pieces ",sheets.pieces.size())
	var text := "extends RefCounted\n"
	text += "# MIT. GENERATED by res://tools/build_mammoth_poses.gd from the sheets of output/imagegen/actors-20261002/\n"
	text += "# (hashes: mammoth-poses-runtime.json); do not edit by hand. Units are atlas texels, PER per logical px;\n"
	text += "# every pivot is the frame's ground contact (feet centroid, sole row).\n"
	text += "const TEXTURE = preload(\"res://assets/combat/mammoth-poses.png\")\n"
	text += "const PER := %.1f\n" % PER
	text += "# Texels per source px of each sheet: %s\n" % JSON.stringify(table.scale)
	text += "# BODY[variant][motion][index] = [Rect2, pivot]; variants: 0 bare, 1 player howdah, 2 enemy howdah;\n"
	text += "# motions: 0 walk (8), 1 stop (2), 2 melee (4), 3 hit (2), 4 death (8 bare, 5 howdah).\n"
	text += "const BODY := %s\n" % _lines(table.body.map(func(variant): return variant.map(func(motion): return motion.map(func(f): return "[%s,%s]" % [_rect(sheets.pieces[f.piece].rect),_vec(f.pivot)]))))
	text += "# STEP[variant][i]: logical px the body advances from walk frame i to i+1 with its planted hooves still.\n"
	text += "const STEP := %s\n" % JSON.stringify(table.step.map(func(v): return v.map(func(x): return snappedf(x,0.001))))
	text += "# FEET[variant][i]: planted hoof offsets from the pivot of walk frame i, logical px.\n"
	text += "const FEET := %s\n" % JSON.stringify(table.feet.map(func(v): return v.map(func(r): return r.map(func(x): return snappedf(x,0.001)))))
	text += "# SEAT[side][motion][index]: rider seat (hips on the howdah rim), texels from the howdah frame's pivot.\n"
	text += "const SEAT := %s\n" % _lines(table.seat.map(func(side): return side.map(func(motion): return motion.map(func(v): return _vec(v)))))
	text += "# RIDERS[side][motion][index] = [[Rect2, offset of its top-left from the howdah pivot], ...]: spotter then gunner; one part: both, merged.\n"
	text += "const RIDERS := %s\n" % _lines(table.riders.map(func(side): return side.map(func(motion): return motion.map(func(e): return "[%s]" % ",".join(e.parts.map(func(p): return "[%s,%s]" % [_rect(sheets.pieces[p.piece].rect),_vec(p.off)]))))))
	text += "# DISMOUNT[side][k] = [Rect2, pivot]: stand, leg over, hang, drop, land.\n"
	text += "const DISMOUNT := %s\n" % _lines(table.dismount.map(func(row): return row.map(func(f): return "[%s,%s]" % [_rect(sheets.pieces[f.piece].rect),_vec(f.pivot)])))
	var file := FileAccess.open(ProjectSettings.globalize_path(TABLE),FileAccess.WRITE)
	file.store_string(text)
	file.close()
	print("TABLE written ",TABLE)


func _rect(r: Rect2i) -> String:
	return "Rect2(%d,%d,%d,%d)" % [r.position.x,r.position.y,r.size.x,r.size.y]


func _vec(v: Vector2) -> String:
	return "Vector2(%.1f,%.1f)" % [v.x,v.y]


# Nested arrays of strings as GDScript source, one innermost list per line.
func _lines(value: Variant, depth := 0) -> String:
	if value is String: return value
	var parts := []
	for item in value: parts.append(_lines(item,depth+1))
	if depth >= 2 or (value.size() > 0 and value[0] is String): return "[%s]" % ",".join(parts)
	return "[\n%s]" % ",\n".join(parts.map(func(p): return "\t".repeat(depth+1)+p))
