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
	# A ports-only refusal may not write this transient marker. Classify only
	# a contact refused by the current solve, never a previous draw/visit.
	journey._render_refused_cell = Vector2i(-1,-1)
	# Station emergence legitimately has hidden vehicles. It does not establish
	# a full occupied rail footprint from which an approach can be measured.
	var occupied: Array = renderer.poses(view,journey,view.consist,0.0)
	if occupied.size() != count:
		# Emergence may hide wagons in the original station. That does not
		# authorize continuing into a newly refused station/works/special site.
		# Earned10646..10738 otherwise shrinks20contacts to1 before arrival.
		var missing: Vector2i = journey._render_refused_cell
		if _is_physical_boundary(journey,missing):
			journey.physical_obstacle = missing
			journey.physical_heading = journey._render_refused_heading
			journey.blocked = true
			journey.stop_reason = journey.network.entry_boundary(missing)
			return
		journey.advance(speed)
		return
	# Chord searches can predict rails ahead of the leading contact. Discard
	# that unoccupied forecast before consulting live switches for this step.
	preload("res://scripts/reverse_switch_contact.gd").retire(journey)
	if not occupied.is_empty():
		Render._retain_reverse_occupied_path(journey,occupied[-1].rear_distance)
	var before: Dictionary = journey.snapshot()
	journey._render_refused_cell = Vector2i(-1,-1)
	journey.advance(speed)
	if renderer.poses(view,journey,view.consist,0.0).size() == count:
		return
	var cell: Vector2i = journey._render_refused_cell
	var approach: int = journey._render_refused_heading
	if not _is_physical_boundary(journey,cell):
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


static func _is_physical_boundary(journey, cell: Vector2i) -> bool:
	# Share the accepted boundary classes for full and incomplete footprints.
	# A station-emergence seed ends inside its origin; there is no refused
	# station contact there. Only the solver's actual refused cell is handled.
	if cell == Vector2i(-1,-1): return false
	var reason: String = journey.network.entry_boundary(cell)
	return not Works.kind_for(journey.network.tile(cell)).is_empty() or reason in ["station","special site"]
