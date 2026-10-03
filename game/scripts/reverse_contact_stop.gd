extends RefCounted
# MIT. Owner-approved adaptation: tasks/reverse-obstacle-adaptation-20261003.md.
# Uses the renderer's exact contact/chord solver. TIME and works costs retain
# their decoded rules; the reverse-leading rear contact owns obstacle timing.
const Render = preload("res://scripts/train_journey_render.gd")
const Works = preload("res://scripts/track_works.gd")
const SEARCH_STEPS := preload("res://scripts/train_renderer.gd").CHORD_ITERATIONS

static func advance(view, journey, speed: int) -> void:
	if not journey.reverse or journey.blocked or speed <= 0:
		journey.advance(speed)
		return
	if journey.physical_obstacle != Vector2i(-1,-1) and not journey.network.entry_boundary(journey.physical_obstacle).is_empty():
		journey.blocked = true
		journey.stop_reason = journey.network.entry_boundary(journey.physical_obstacle)
		return
	var renderer = view.train_renderer
	var count: int = view.consist.vehicles.size()
	# Station emergence legitimately has hidden vehicles. It does not establish
	# a full occupied rail footprint from which an approach can be measured.
	if renderer.poses(view,journey,view.consist,0.0).size() != count:
		journey.advance(speed)
		return
	var before: Dictionary = journey.snapshot()
	journey._render_refused_cell = Vector2i(-1,-1)
	journey.advance(speed)
	if renderer.poses(view,journey,view.consist,0.0).size() == count:
		return
	var cell: Vector2i = journey._render_refused_cell
	var reason: String = journey.network.entry_boundary(cell)
	var approach: int = journey._render_refused_heading
	if Works.kind_for(journey.network.tile(cell)).is_empty() and reason != "station":
		return
	if not _restore_or_stop(journey,before,cell,approach,"initial"):
		return
	var progress: int = mini(journey.network.progress_speed(journey.position,journey.heading,speed),journey.MAX_PROGRESS_SPEED)
	var fraction := float(progress/20)/float(journey.PHASES_PER_TILE*journey.DISTANCE_STEP)
	var low := 0.0
	var high := fraction
	var accepted: Dictionary = before
	# Same 24 halvings as the contact solver: interval is one source clock step,
	# so uncertainty is smaller than its already documented subpixel bracket.
	for iteration in SEARCH_STEPS:
		if not _restore_or_stop(journey,before,cell,approach,"search"):
			return
		var middle := (low+high)*0.5
		Render._advance_render(journey,middle)
		if renderer.poses(view,journey,view.consist,0.0).size() == count:
			low = middle
			accepted = journey.snapshot()
		else:
			high = middle
	if not _restore_or_stop(journey,accepted,cell,approach,"accepted"):
		return
	journey.physical_obstacle = cell
	journey.physical_heading = approach
	journey.blocked = true
	journey.stop_reason = journey.network.entry_boundary(journey.physical_obstacle)


static func _restore_or_stop(journey, snapshot: Dictionary, cell: Vector2i, approach: int, stage: String) -> bool:
	# restore validates atomically (train_journey.gd). Evaluate outside assert:
	# Godot release builds omit assertion expressions and their side effects.
	if journey.restore(snapshot):
		return true
	# A rejected snapshot must not leave the search advancing an unsafe footprint.
	journey.physical_obstacle = cell
	journey.physical_heading = approach
	journey.blocked = true
	journey.stop_reason = journey.network.entry_boundary(cell)
	push_error("Reverse contact stop could not restore %s snapshot; travel blocked" % stage)
	return false
