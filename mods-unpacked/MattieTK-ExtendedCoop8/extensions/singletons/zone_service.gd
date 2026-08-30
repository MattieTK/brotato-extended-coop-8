extends "res://singletons/zone_service.gd"

# With more than 4 players the vanilla arena is far too cramped: hand out a
# pre-enlarged copy of the zone data, so the tilemap, borders, spawner, camera
# bounds and wave manager all size themselves consistently downstream (the
# same pipeline the vanilla map_size item effect uses).

const C8_MAP_SCALE := 1.5


func get_zone_data(my_id: int) -> Resource:
	var zone = .get_zone_data(my_id)
	if zone != null and RunData.is_coop_run and RunData.c8_true_player_count() > 4:
		zone = zone.duplicate()
		zone.width = int(zone.width * C8_MAP_SCALE)
		zone.height = int(zone.height * C8_MAP_SCALE)
	return zone
