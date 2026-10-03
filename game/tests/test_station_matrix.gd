extends SceneTree
# requires-native-renderer
# MIT. Enumerate the supplied CARTE station tiles, not an authored town list.
const Rails = preload("res://scripts/rail_network.gd")
const Glyphs = preload("res://scripts/rail_glyphs.gd")
const Journey = preload("res://scripts/train_journey.gd")
const Works = preload("res://scripts/track_works.gd")
const Campaign = preload("res://scripts/campaign_state.gd")
const Wagons = preload("res://scripts/train_wagons.gd")
const Data = preload("res://scripts/world_data.gd")
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var data = Data.new()
	assert(data.load_from_project(ProjectSettings.globalize_path("res://").trim_suffix("/")))
	var stations := 0
	var approaches := 0
	var towns := {}
	var isolated: Array[Vector2i] = []
	var campaign = Campaign.new()
	campaign.load_data()
	var wagons = Wagons.new()
	for x in Rails.WIDTH:
		for y in Rails.HEIGHT:
			var station := Vector2i(x,y)
			if not data.map_code(x,y) in [34,35,36,37]: continue
			stations += 1
			var covered := false
			for heading in Rails.DELTAS:
				if heading == 5: continue
				if not -Vector2(Rails.DELTAS[heading])*0.5 in Glyphs.ports_for_code(data.map_code(x,y)): continue
				var cell: Vector2i = station - Rails.DELTAS[heading]
				var approach_code := data.map_code(cell.x,cell.y)
				var ports := Glyphs.ports_for_code(Works.repaired_code(approach_code) if not Works.kind_for(approach_code).is_empty() else approach_code)
				if not Vector2(Rails.DELTAS[heading])*0.5 in ports: continue
				for backing in [false,true]:
					var network = Rails.new()
					network.load_bytes(data.map_bytes)
					network.set_city_anchors(data.city_anchors())
					if not Works.kind_for(network.tile(cell)).is_empty(): network.repair(cell)
					campaign.prepare_entry(cell,heading,wagons,network)
					ports = Glyphs.ports_for_code(network.tile(cell))
					var incoming := 0
					for candidate in Rails.DELTAS:
						if candidate == 5: continue
						if -Vector2(Rails.DELTAS[candidate])*0.5 in ports and network.turn(cell,candidate) == heading:
							incoming = candidate
							break
					if incoming == 0 and network.is_switch(cell):
						network.toggle_switch(cell)
						for candidate in Rails.DELTAS:
							if candidate != 5 and -Vector2(Rails.DELTAS[candidate])*0.5 in ports and network.turn(cell,candidate) == heading:
								incoming = candidate
								break
					if incoming == 0 and network.tile(cell) in [34,35,36,37]: incoming = heading
					if incoming == 0: continue
					var journey = Journey.new()
					journey.network = network
					journey.position = cell
					journey.heading = incoming
					# Build backing from an actual reversal on this approach's exit.
					if backing:
						journey.heading = 10-heading
						journey.phase = 2
						journey.fractional_position()
						journey.reverse_direction()
					for cycle in 8: # 3 source phases, at most 22/23 progress per cycle.
						if journey.blocked: break
						journey.advance(450)
					if not journey.at_station() or journey.next_cell() != station:
						failures.append("arrival %s heading %d backing %s: %s -> %s" % [station,heading,backing,journey.position,journey.next_cell()])
						continue
					covered = true
					approaches += 1
					var port := Vector2(cell)+Vector2(Rails.DELTAS[heading])*0.5
					if not journey.fractional_position().is_equal_approx(port):
						failures.append("displayed arrival %s backing %s: %s != %s" % [station,backing,journey.fractional_position(),port])
					var city := journey.station_result()
					if city >= 0: towns[city] = true
					journey.depart_from_station()
					if not journey.fractional_position().is_equal_approx(port):
						failures.append("displayed departure %s backing %s" % [station,backing])
			if not covered:
				if station in [Vector2i(150,41),Vector2i(150,42)]:
					# Supplied adjacent terminals face each other, with no external rail.
					isolated.append(station)
				else: failures.append("no tested rail approach for station %s" % station)
	print("MATRIX: %d stations, %d forward/backward approaches, %d static cities, isolated source pair %s" % [stations,approaches,towns.size(),isolated])
	if stations != 75 or approaches != 150 or towns.size() != 45 or isolated.size() != 0: failures.append("incomplete supplied station inventory")
	for failure in failures: push_error(failure)
	if failures.is_empty(): print("PASS: 75 station ports entered forward/backward and departed (isolated pair tested locally, no fabricated access)")
	quit(0 if failures.is_empty() else 1)
