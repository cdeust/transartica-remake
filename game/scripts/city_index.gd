extends RefCounted

# MIT. Hidden city selection model and status; discovery policy remains in world_view.
# source: PR7 main.gd city index behavior, preserved during integration.

static func focus_city(app, index: int) -> void:
	app.world_view.focus_city(index)
	app._update_status()


static func _filter_cities(app, query: String) -> void:
	app.city_list.clear()
	app.city_indices.clear()
	for index in app.world_data.cities.size():
		if not app._city_discovered(index):
			continue
		var city_name := String(app.world_data.cities[index].name)
		if query.is_empty() or city_name.to_lower().contains(query.to_lower()):
			app.city_indices.append(index)
			app.city_list.add_item(city_name)


static func _on_chart_city_picked(app, _index: int) -> void:
	app._update_status()
	app.city_list.deselect_all()
	app._select_visible_city()


static func _on_city_selected(app, list_index: int) -> void:
	if list_index < app.city_indices.size():
		app.focus_city(app.city_indices[list_index])


static func _select_visible_city(app) -> void:
	if app.city_list == null or app.world_view.selected_city < 0:
		return
	for index in app.city_indices.size():
		if app.city_indices[index] == app.world_view.selected_city:
			app.city_list.select(index)
			return


static func _update_status(app) -> void:
	if app.status_label == null:
		return
	var selected := "No city selected"
	if app.world_view.selected_city >= 0:
		selected = String(app.world_data.cities[app.world_view.selected_city].name)
	app.status_label.text = "Position (%d, %d) · %s\n%s\n%d discovered cities" % [app.journey.position.x, app.journey.position.y, app.journey.heading_name(), selected, app.city_indices.size()]


static func _city_discovered(app, index: int) -> bool:
	var city: Dictionary = app.world_data.cities[index]
	return app.world_view._city_is_visible(city)
