extends "res://scripts/map_entities.gd"

# MIT. Keep source city/spy/enemy placement and perception; only authored scenery
# replaces the private original map pixels in the travel presentation.
func draw_city_tile(view, cell: Vector2i, code: int) -> bool:
	# Terrain is painted once behind rails. City label pass must not cover rails
	# a second time with historical pixels.
	return view.terrain.textures.has(view.terrain.resource_code(code))
