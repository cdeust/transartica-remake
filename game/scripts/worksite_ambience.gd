extends RefCounted

# MIT. Authored lamp/entrance positions measured from mine/track-works plates.
# See tasks/validation/living-ambience-20261001.md for visual recipes and captures.
const Effects = preload("res://scripts/living_effects.gd")
const Atlas = preload("res://scripts/living_effects_atlas.gd")
const MINE_LAMPS := [Vector2(61,82),Vector2(170,96),Vector2(264,96)] # source: measured authored mine plate in logical320×149 canvas.
const WORK_LAMPS := [Vector2(46,84),Vector2(209,81)] # source: measured authored track-works lanterns in the same canvas.
var effects = Effects.new()
var atlas = Atlas.new()
var time := 0.0
var emitted_phase := -1
var scene_key := ""


func clear() -> void:
	effects.clear()
	time = 0
	emitted_phase = -1
	scene_key = ""


func advance(delta: float, mode: String, working: bool) -> void:
	if not is_finite(delta) or delta <= 0: return
	var key := "%s/%s" % [mode,working]
	if key != scene_key:
		clear()
		scene_key = key
	time += delta
	effects.advance(delta)
	# Authored three-quarter-second dust pulses keep this a sparse worksite,
	# rather than implying new source resource collection or blast damage.
	var phase := int(time/0.75)
	if working and phase != emitted_phase:
		emitted_phase = phase
		# Native track-work capture: contact on the deck at(158,105).
		var point := Vector2(104,116) if mode == "mine" else Vector2(158,105)
		effects.add("dust",point,Vector2.UP,0.55)
		if mode != "mine": effects.add("sparks",point,Vector2.UP,0.35)


func draw(canvas: CanvasItem, mode: String) -> void:
	if not atlas.loaded: atlas.load_art()
	var lamps := MINE_LAMPS if mode == "mine" else WORK_LAMPS
	var frame := int(time*8)%4 # Authored fire keyposes share engine-room8Hz rate.
	for point in lamps:
		atlas.draw(canvas,"flame-%d" % frame,point,Vector2(4,6),Color(1,0.65,0.25,0.45))
	effects.draw(canvas)
