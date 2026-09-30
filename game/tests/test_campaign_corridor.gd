extends SceneTree

# Source-backed corridor regression. This isolated map-unit test is not a
# full-campaign claim; campaign-route.md records TABLE-start shopping/replay.
const Rails = preload("res://scripts/rail_network.gd")
const Glyphs = preload("res://scripts/rail_glyphs.gd")
const Journey = preload("res://scripts/train_journey.gd")

func _initialize() -> void:
	var data = preload("res://scripts/world_data.gd").new()
	var failures: Array[String] = []
	if not data.load_from_project(ProjectSettings.globalize_path("res://").trim_suffix("/")):
		push_error("Original map unavailable")
		quit(1)
		return
	var network = Rails.new()
	network.load_bytes(data.map_bytes)
	for cell in Rails.OASIS_CORRIDOR:
		if not network.set_campaign_tile(cell,Rails.OASIS_CORRIDOR[cell]):
			failures.append("Original Oasis write rejected")
		if network.entry_boundary(cell) != "special site":
			failures.append("Standalone network must retain uninstalled campaign frontier")
	network.campaign_entry_enabled = true
	for cell in Rails.OASIS_CORRIDOR:
		if not network.entry_boundary(cell).is_empty():
			failures.append("Disclosed original corridor must permit entry")
		if network.turn(cell,4) != 4 or network.turn(cell,6) != 6:
			failures.append("Original TIME retains the E-W heading")
		if Glyphs.ports_for_code(network.tile(cell)) != Glyphs.ports_for_code(2):
			failures.append("Disclosed corridor must have its adjoining E-W rail ports")
	if network.entry_boundary(Vector2i(23,67)) != "special site":
		failures.append("Unrevealed Urga must remain concealed")
	# Real advance() proves traversal, both directions, after exact verified writes.
	for heading in [4,6]:
		var journey = Journey.new()
		journey.network = network
		journey.position = Vector2i(29,67) if heading == 6 else Vector2i(30,67)
		journey.heading = heading
		journey.incoming_heading = heading
		var destination: Vector2i = journey.position + Rails.DELTAS[heading]
		while journey.position != destination and not journey.blocked:
			journey.advance(Journey.MAX_PROGRESS_SPEED)
		if journey.blocked or journey.position != destination:
			failures.append("Actual journey rejects verified corridor leg")
	for failure in failures:push_error(failure)
	if failures.is_empty():print("PASS: exact disclosed Oasis corridor traversal, heading, ports and retained concealment")
	quit(0 if failures.is_empty() else 1)
