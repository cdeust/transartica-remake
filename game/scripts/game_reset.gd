extends RefCounted

# MIT. Reset composed runtime state; source module reset methods own their rules.
# source: main.gd new-game sequence plus tested campaign/world/works reset contracts.

static func restart(app) -> void:
	app.encounters.reset()
	app._boudoir_session.reset()
	app.session.reset()
	app.journey.reset()
	app.network.reset()
	app.wagons.reset()
	app.trade.reset(app._trade_rng)
	app.campaign.reset()
	app.roamers = preload("res://scripts/world_roamers.gd").new()
	app.roamers.initialize(app._trade_rng,app.campaign.state.fauna)
	app.world = preload("res://scripts/world_actions.gd").new()
	app.world.attach(app.journey, app.wagons, app.engine, app.trade, app._trade_rng)
	app._world_session.reset()
	app.works_dialog.reset()
	app.engine.train_mass = app.wagons.mass()
	app.world_view.consist.derive_from_wagons(app.wagons)
	app._city_panel.hide()
	app.world_view.selected_city = -1
	app._map_opened = false
	app.world_view.following_train = false
	app.world_view.discovery = preload("res://scripts/map_discovery.gd").new()
	app._filter_cities("")
	app.world_view.fit_discovered()
	app.clock.set_elapsed(0)
	app.calendar = app.GameCalendarScript.new()
	app._modal.hide()
	app.instruments.hide()
	preload("res://scripts/game_audio_routes.gd").new_game(app)
	app.room_controls.announce("New engine session · coal stocks restored")
