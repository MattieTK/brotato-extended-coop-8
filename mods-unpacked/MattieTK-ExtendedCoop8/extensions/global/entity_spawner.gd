extends "res://global/entity_spawner.gd"

const C8 = preload("res://mods-unpacked/MattieTK-ExtendedCoop8/c8.gd")


func _ready() -> void :
	C8.pad(lootworms, "null")
	C8.pad(queues_to_spawn_structures, "array")
	C8.pad(queues_to_spawn_pets, "array")


func init(
		zone_min_pos: Vector2,
		zone_max_pos: Vector2,
		current_wave_data: WaveData,
		wave_timer: Timer
	) -> void :
	# Full override of the vanilla body: the vanilla 2x2 spawn grid makes players
	# 5-8 spawn exactly on top of players 1-4. We use a 4x2 grid for > 4 players.

	_main = Utils.get_scene_node()

	_current_wave_data = current_wave_data
	_zone_min_pos = zone_min_pos
	_zone_max_pos = zone_max_pos
	_wave_timer = wave_timer

	var player_count = RunData.get_player_count()
	for player_index in player_count:
		var position: Vector2
		if player_count > 4:
			position = Vector2(
				zone_max_pos.x / 2 - 150 + (player_index % 4) * 100,
				zone_max_pos.y / 2 - 50 + int(player_index / 4) * 100
			)
		elif player_count > 1:
			position = Vector2(
				zone_max_pos.x / 2 - 100 + (player_index % 2) * 100,
				zone_max_pos.y / 2 + (int(player_index / 2) % 2) * 100
			)
		else:
			position = Vector2(zone_max_pos.x / 2, zone_max_pos.y / 2)

		_spawn_entity_args._init(position, EntityType.PLAYER)
		_spawn_entity_args.player_index = player_index
		var player = spawn_entity(player_scene, _spawn_entity_args)
		if RunData.is_coop_run:
			player._movement_behavior.device = CoopService.connected_players[player_index][0]
		_players.push_back(player)

		_restrict_turret_count(player_index)

	for player in _players:
		for weapon in player.current_weapons:
			weapon.connect("wanted_to_reset_turrets_cooldown", self, "on_weapon_wanted_to_reset_turrets_cooldown")

	emit_signal("players_spawned", _players)
	PetService.reset()
