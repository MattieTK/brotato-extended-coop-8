extends "res://main.gd"

const C8 = preload("res://mods-unpacked/MattieTK-ExtendedCoop8/c8.gd")

# Horizontal band reserved on each side of the screen for the player strips
# when more than 4 players are in the run.
const C8_HUD_MARGIN := 310.0


func _ready() -> void :
	_c8_setup_full_map_camera()


func _c8_setup_full_map_camera() -> void :
	# With more than 4 players: whole map visible from the start, pinned to the
	# map center, zoomed out far enough that the arena fits between the two
	# reserved HUD bands. Uses the camera's built-in locked-coop mode; only its
	# instance variables are adjusted (its script stays untouched).
	if not RunData.is_coop_run or RunData.get_player_count() <= 4:
		return
	_camera.dynamic_camera_enabled = false
	var bounds: Rect2 = _camera._max_bounds
	var c8_zoom: float = max(
		bounds.size.x / max(1.0, Utils.project_width - 2.0 * C8_HUD_MARGIN),
		bounds.size.y / Utils.project_height
	)
	_camera._max_zoom = max(_camera._max_zoom, c8_zoom)
	ZoneService.current_zone_max_camera_rect = _camera.get_max_camera_bounds()


func on_lock_coop_camera_changed(value: bool) -> void :
	.on_lock_coop_camera_changed(value)
	# The settings toggle must not re-enable the roaming camera in 8-player runs.
	if RunData.is_coop_run and RunData.get_player_count() > 4:
		_camera.dynamic_camera_enabled = false


func _init() -> void :
	C8.pad(_upgrades_to_process, "array")
	C8.pad(_consumables_to_process, "array")
	C8.pad(_proj_on_death_stat_caches, "null")
	C8.pad(_player_is_under_half_health, "bool")


func _enter_tree() -> void :
	# main.tscn only ships HUD nodes for players 1-4; clone the P5-P8 sets before
	# any _ready code looks them up by unique name.
	if get_node_or_null("%LifeContainerP5") != null:
		return
	_c8_add_life_containers()
	_c8_add_world_life_bars()
	_c8_add_things_to_process_containers()


func _c8_add_life_containers() -> void :
	var template = get_node("%LifeContainerP4")
	var parent = template.get_parent()
	for i in range(4, 8):
		var n = str(i + 1)
		var container = template.duplicate()
		container.name = "LifeContainerP" + n
		container.get_node("UILifeBarP4").name = "UILifeBarP" + n
		container.get_node("UIXPBarP4").name = "UIXPBarP" + n
		container.get_node("UIGoldP4").name = "UIGoldP" + n
		container.hide()
		parent.add_child(container)
		C8.register_unique(container, self)
		C8.register_unique(container.get_node("UILifeBarP" + n), self)
		C8.register_unique(container.get_node("UIXPBarP" + n), self)
		C8.register_unique(container.get_node("UIGoldP" + n), self)


func _c8_add_world_life_bars() -> void :
	var template = get_node("%PlayerLifeBarContainerP4")
	var parent = template.get_parent()
	for i in range(4, 8):
		var n = str(i + 1)
		var container = template.duplicate()
		container.name = "PlayerLifeBarContainerP" + n
		container.get_node("PlayerLifeBarP4").name = "PlayerLifeBarP" + n
		parent.add_child(container)
		C8.register_unique(container, self)


func _c8_add_things_to_process_containers() -> void :
	var vbox = get_node("%ThingsToProcessMarginContainer").get_child(0)
	var row2 = vbox.get_child(1)
	var prefab = load("res://ui/hud/ui_things_to_process_player_container.tscn")

	for row_index in range(2):
		var row = row2.duplicate()
		for child in row.get_children():
			row.remove_child(child)
			child.queue_free()
		row.name = "C8HBoxContainer" + str(row_index + 3)
		vbox.add_child(row)

		for col in range(2):
			var player_index = 4 + row_index * 2 + col
			var instance = prefab.instance()
			instance.name = "UIThingsToProcessPlayerContainer%d" % (player_index + 1)
			instance.vertical_alignment = 1
			if col == 1:
				instance.horizontal_alignment = 1
			row.add_child(instance)
			C8.register_unique(instance, self)


func on_gold_picked_up(gold: Node, player_index: int) -> void :
	# Full override of the vanilla body: the material/xp round-robin splitter
	# uses local [0, 0, 0, 0] arrays which break with more than 4 players.
	if gold.already_picked_up:
		return

	gold.already_picked_up = true
	_active_golds.erase(gold)
	add_node_to_pool(gold, _gold_pool_id)

	if player_index >= 0:
		if ProgressData.settings.alt_gold_sounds:
			SoundManager.play(Utils.get_rand_element(gold_alt_pickup_sounds), - 5, 0.2)
		else:
			SoundManager.play(Utils.get_rand_element(gold_pickup_sounds), 0, 0.2)

		var increase_effect: int = RunData.get_player_effect(Keys.increase_material_value_hash, player_index)
		var value = gold.value
		value += value * (increase_effect / 100.0)

		var boost = RunData.apply_common_gold_pickup_effects(gold.value, player_index)
		value *= boost
		gold.boosted *= boost

		if Utils.get_chance_success(RunData.get_player_effect(Keys.heal_when_pickup_gold_hash, player_index) / 100.0):
			RunData.emit_signal("healing_effect", 1, player_index, Keys.item_cute_monkey_hash)

		var dmg_when_pickup_gold_effect = RunData.get_player_effect(Keys.dmg_when_pickup_gold_hash, player_index)
		if dmg_when_pickup_gold_effect.size() > 0:
			handle_stat_damages(dmg_when_pickup_gold_effect, player_index)

		var highest_cd_weapon_that_should_reload = null

		for weapon in _players[player_index].current_weapons:
			for effect in weapon.effects:
				if effect.key_hash == Keys.reload_when_pickup_gold_hash:
					if not weapon._is_shooting and (highest_cd_weapon_that_should_reload == null or weapon._current_cooldown > highest_cd_weapon_that_should_reload._current_cooldown):
						highest_cd_weapon_that_should_reload = weapon

		if highest_cd_weapon_that_should_reload:
			highest_cd_weapon_that_should_reload._current_cooldown = 0

		for structure in _entity_spawner.structures:
			if structure is BuilderTurret:
				for effect in structure.effects:
					if effect.key_hash == Keys.reload_when_pickup_gold_hash:
						structure._cooldown = 0

		if RunData.get_player_effect_bool(Keys.reload_when_pickup_gold_hash, player_index):
			for weapon in _players[player_index].current_weapons:
				weapon._current_cooldown = 0

		var player_count = RunData.get_player_count()
		var player_gold: = []
		var player_xp: = []
		for _i in player_count:
			player_gold.push_back(0)
			player_xp.push_back(0)
		while value > 0:
			player_gold[_next_gold_player] += 1
			player_xp[_next_gold_player] += 1
			value -= 1
			_next_gold_player = (_next_gold_player + 1) % player_count

		for i in player_count:
			RunData.add_gold(player_gold[i], i)
			RunData.add_xp(player_xp[i], i)

		ProgressData.increment_stat("materials_collected")
		return

	if _cleaning_up:
		RunData.add_bonus_gold(gold.value)


func _on_EntitySpawner_players_spawned(players: Array) -> void :
	._on_EntitySpawner_players_spawned(players)
	if _players_ui.size() > 4:
		_c8_build_hud_columns()


const C8_HUD_SCALE := 0.6
const C8_BAND_WIDTH := 240.0

var _c8_hud_bands: = []
var _c8_hud_columns: = []


func _c8_build_hud_columns() -> void :
	# With more than 4 players the four screen corners are not enough; instead,
	# each player's stats strip goes into a colour-tagged column running down
	# the left (players 1-4) or right (players 5-8) edge of the screen, scaled
	# down and placed in the side margins the locked camera reserves.
	var hud = _players_ui[0].hud_container.get_parent()
	var ui = hud.get_parent()
	if not _c8_hud_bands.empty():
		return

	for side_index in range(2):
		var on_left: bool = side_index == 0
		var band = Control.new()
		band.name = "C8HudLeftBand" if on_left else "C8HudRightBand"
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.anchor_top = 0
		band.anchor_bottom = 1
		if on_left:
			band.anchor_left = 0
			band.anchor_right = 0
			band.margin_left = 8
			band.margin_right = 8 + C8_BAND_WIDTH
		else:
			band.anchor_left = 1
			band.anchor_right = 1
			band.margin_left = - (8 + C8_BAND_WIDTH)
			band.margin_right = - 8
		band.margin_top = 8
		band.margin_bottom = - 8
		ui.add_child(band)
		# Draw right above the HUD but below the pause menu, level-up screen
		# and other full-screen overlays that come later in the UI layer.
		ui.move_child(band, hud.get_index() + 1 + _c8_hud_bands.size())
		_c8_hud_bands.push_back(band)

		var bg = ColorRect.new()
		bg.name = "C8BandBg"
		bg.color = Color(0, 0, 0, 0.45)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.anchor_right = 1
		bg.anchor_bottom = 1
		band.add_child(bg)

		var column = VBoxContainer.new()
		column.name = "C8HudLeft" if on_left else "C8HudRight"
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_constant_override("separation", 26)
		column.rect_scale = Vector2(C8_HUD_SCALE, C8_HUD_SCALE)
		band.add_child(column)
		_c8_hud_columns.push_back(column)

	for i in range(_players_ui.size()):
		var player_ui = _players_ui[i]
		var hc: Container = player_ui.hud_container
		var on_left: bool = i < 4

		var wrap = HBoxContainer.new()
		wrap.name = "C8HudWrap" + str(i + 1)
		wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_constant_override("separation", 10)

		var chip = ColorRect.new()
		chip.name = "C8Chip"
		chip.color = CoopService.get_player_color(i)
		chip.rect_min_size = Vector2(12, 10)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE

		hc.get_parent().remove_child(hc)
		hc.size_flags_horizontal = 0
		hc.size_flags_vertical = 0
		hc.visible = true
		wrap.add_child(chip)
		wrap.add_child(hc)

		hc.move_child(player_ui.gold, player_ui.xp_bar.get_index() + 1)
		player_ui.gold.alignment = BoxContainer.ALIGN_BEGIN

		_c8_hud_columns[0 if on_left else 1].add_child(wrap)

	call_deferred("_c8_center_hud_columns")


func _c8_center_hud_columns() -> void :
	# Vertically center each scaled column inside its band (scale is ignored by
	# container layout, so the position is set manually once sizes are known).
	for side_index in range(_c8_hud_columns.size()):
		var band = _c8_hud_bands[side_index]
		var column = _c8_hud_columns[side_index]
		if not is_instance_valid(band) or not is_instance_valid(column):
			continue
		var scaled_size = column.rect_size * C8_HUD_SCALE
		column.rect_position = Vector2(
			max(6.0, (band.rect_size.x - scaled_size.x) / 2.0),
			max(6.0, (band.rect_size.y - scaled_size.y) / 2.0)
		)
