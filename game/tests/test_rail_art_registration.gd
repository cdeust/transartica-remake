extends SceneTree

# MIT. Source pixel anchors measured on assets/travel/rail-track-kit.png.
# Source ports remain RailGlyphs; this regression changes no route rules.
const Art = preload("res://scripts/rail_art.gd")
var failures: Array[String] = []


func _initialize() -> void:
	var texture: Texture2D = load("res://assets/travel/rail-track-kit.png")
	var image := texture.get_image()
	check(not image.is_empty(), "authored source image available")
	# Both steel centre pixels have higher alpha and brightness than the track bed
	# between them on source row100, independently of the production crop.
	for x in [159, 219]:
		var steel := image.get_pixel(x, 100)
		var bed := image.get_pixel(189, 100)
		check(steel.a > bed.a and steel.v > bed.v, "measured steel source centre %d" % x)
	check(Art.SOURCE_CENTER == (159.0 + 219.0) / 2, "source mean registered rather than crop midpoint182.5")
	check(Art.SOURCE_GAUGE == 219 - 159, "source gauge measured60 rather than70")
	var center := Vector2(70, 90)
	var straight: Array[Vector2] = [center + Vector2(-60, 0), center + Vector2(60, 0)]
	var segments: Array = Art.tile_segments(center, straight)
	check(segments.size() == 1 and segments[0] == [straight[0], straight[1]], "straight is one complete port-to-port segment")
	var junction: Array[Vector2] = [straight[0], straight[1], center + Vector2(60, -60)]
	check(Art.tile_segments(center, junction).size() == 2, "junction adds only its source branch")
	var start := center + Vector2(-60, 0)
	var finish := center + Vector2(60, -60)
	var rails: Array = Art.joined_rails(start, center, finish, Art.TRACK_GAUGE / 2)
	check(rails.size() == 2, "both steel rails have one shared bend vertex")
	for rail in rails:
		check(is_equal_approx(rail[0].distance_to(start), Art.TRACK_GAUGE / 2), "incoming gauge retained")
		check(is_equal_approx(rail[2].distance_to(finish), Art.TRACK_GAUGE / 2), "outgoing gauge retained")
		check((rail[1] - rail[0]).normalized().is_equal_approx((center - start).normalized()), "join lies on incoming offset line")
		check((rail[2] - rail[1]).normalized().is_equal_approx((finish - center).normalized()), "join lies on outgoing offset line")
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("PASS: source steel centre/gauge, complete straights and joined source-chord rails")
	quit(0 if failures.is_empty() else 1)


func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
