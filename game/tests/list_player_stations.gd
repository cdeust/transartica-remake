extends SceneTree
# MIT. Navigation aid only; source rail_network.station_lookup (TIME0x26fb).
# Original station enumeration also used by test_campaign_route.gd.
# Write the derived station inventory only to the ignored private cache.

func _initialize() -> void:
	var data = preload("res://scripts/world_data.gd").new()
	var network = preload("res://scripts/rail_network.gd").new()
	assert(data.load_from_project(ProjectSettings.globalize_path("res://")))
	network.load_bytes(data.map_bytes)
	network.set_city_anchors(data.city_anchors())
	var stations: Array = []
	for x in network.WIDTH:
		for y in network.HEIGHT:
			var cell := Vector2i(x,y)
			if network.tile(cell) not in [34,35,36,37]: continue
			var city: int = network.station_lookup(cell)
			stations.append({"cell":[x,y],"city":city,
				"name":data.cities[city].name if city >= 0 else str(city)})
	for cell: Vector2i in network.STATION_SPECIALS:
		if not stations.any(func(record): return record.cell == [cell.x,cell.y]):
			var city: int = network.STATION_SPECIALS[cell]
			stations.append({"cell":[cell.x,cell.y],"city":city,"name":str(city)})
	var path := ProjectSettings.globalize_path("res://../.cache/player-navigation/stations.json")
	var output := FileAccess.open(path,FileAccess.WRITE)
	output.store_string(JSON.stringify(stations,"\t"))
	print("PRIVATE_STATION_INVENTORY ",stations.size())
	quit()
