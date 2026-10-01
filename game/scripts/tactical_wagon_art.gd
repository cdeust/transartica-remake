extends RefCounted
# MIT. Measured full silhouettes from supplied authored masters; presentation only.
# Exact opaque bounds: tasks/validation/wagon-master-measure-20260930.log.
# Runtime cropping retains source pixels and recovers geometry lost by grid crops.
const MASTERS := [preload("res://assets/combat/train-master.png"),
	preload("res://assets/combat/wagons-master-04-10.png"),
	preload("res://assets/combat/wagons-master-10-17.png"),
	preload("res://assets/combat/wagons-master-17-25.png")]
const HERO := preload("res://assets/combat/wagon-01.png")
const HERO_REGION := Rect2i(16,35,2002,673) # source: measured alpha>=128 bounds, locomotive-consistency.md.
const REGIONS := {
	1:[0,Rect2i(34,120,796,245)],
	2:[0,Rect2i(1392,124,749,241)],
	3:[0,Rect2i(26,420,688,236)],
	4:[1,Rect2i(35,42,711,334)],
	5:[1,Rect2i(787,136,716,240)],
	6:[1,Rect2i(21,437,745,250)],
	7:[1,Rect2i(787,437,729,250)],
	8:[1,Rect2i(21,741,744,231)],
	9:[1,Rect2i(781,759,734,213)],
	10:[2,Rect2i(31,66,731,269)],
	11:[0,Rect2i(1449,481,692,175)],
	12:[2,Rect2i(783,129,725,206)],
	13:[2,Rect2i(28,455,735,200)],
	14:[2,Rect2i(783,403,725,252)],
	15:[2,Rect2i(31,720,731,237)],
	16:[2,Rect2i(783,731,725,231)],
	17:[3,Rect2i(38,53,635,202)],
	18:[3,Rect2i(717,59,804,196)],
	19:[3,Rect2i(23,309,690,194)],
	20:[3,Rect2i(737,305,782,198)],
	21:[0,Rect2i(847,156,524,211)],
	22:[3,Rect2i(27,510,631,241)],
	23:[0,Rect2i(737,426,692,230)],
	24:[3,Rect2i(675,556,843,195)],
	25:[3,Rect2i(38,771,665,218)],
}
var textures := {}

func texture_for(kind: int) -> Texture2D:
	if textures.has(kind):return textures[kind]
	if kind == 1:
		textures[kind]=ImageTexture.create_from_image(HERO.get_image().get_region(HERO_REGION))
		return textures[kind]
	var spec: Array=REGIONS[kind]
	var master: Image=MASTERS[spec[0]].get_image()
	# One source-pixel alpha fringe surrounds measured opaque silhouette bounds.
	var region: Rect2i=spec[1].grow(1).intersection(Rect2i(Vector2i.ZERO,master.get_size()))
	var image: Image=master.get_region(region)
	textures[kind]=ImageTexture.create_from_image(image)
	return textures[kind]
