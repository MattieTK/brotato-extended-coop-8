extends "res://ui/menus/run/weapon_selection.gd"

const C8W = preload("res://mods-unpacked/MattieTK-ExtendedCoop8/c8.gd")

# With more than 4 players, weapon selection becomes a 2x4 grid where each cell
# holds that player's info panel on top and their weapon inventory below.
# Fresh nodes are created in _enter_tree (so the vanilla ready-wiring picks
# them up); the vanilla nodes are only moved into the grid in the deferred
# finalize step, after every onready lookup and focus-emulator cache resolved.

const C8_CELL_DESIGN := Vector2(470, 780)

var _c8_grid_rows: = []
var _c8_cells_built: = false
var _c8_inventories_extra: = []
var _c8_panels_extra: = []


func _get_panels() -> Array:
	var panels = ._get_panels()
	panels.append_array(_c8_panels_extra)
	return panels


func _get_inventory_containers() -> Array:
	var containers = ._get_inventory_containers()
	containers.append_array(_c8_inventories_extra)
	return containers


func _enter_tree() -> void :
	if Utils.on_console:
		return
	if RunData.c8_true_player_count() <= 4:
		return
	if not _c8_inventories_extra.empty():
		return

	var inventory_prefab = load("res://ui/menus/run/scroll_inventory.tscn")
	var panel_prefab = load("res://ui/menus/ingame/item_panel_ui.tscn")

	var inventories_row = get_node("%Inventory1").get_parent()
	var panels_row = get_node("%Panel1").get_parent()

	for i in range(4, 8):
		var n = str(i + 1)

		var inventory_instance = inventory_prefab.instance()
		inventory_instance.name = "Inventory" + n
		inventories_row.add_child(inventory_instance)
		_c8_inventories_extra.push_back(inventory_instance)

		var panel_instance = panel_prefab.instance()
		panel_instance.name = "Panel" + n
		panel_instance.visible = false
		panels_row.add_child(panel_instance)
		_c8_panels_extra.push_back(panel_instance)

	# Focus emulators cache their target nodes in their own _ready, which runs
	# before the grid rearrangement — point each at its player's inventory now.
	var template_fe = get_node("FocusEmulator4")
	var old_target = get_node("%Inventory4")
	for i in range(4, 8):
		var fe = C8W.clone_focus_emulator(self, template_fe, i)
		C8W.repoint_focus_emulator(fe, old_target, _c8_inventories_extra[i - 4])


func _c8_after_finalize(count: int) -> void :
	if count <= 4:
		return

	_player_weapons.resize(count)

	for inventory in _get_inventories():
		inventory.columns = 4
		inventory.queue_set_focus_neighbours()

	# Vanilla only auto-completed players 1-4 that have nothing to pick.
	for player_index in range(4, count):
		if not RunData.player_has_weapon_slots(player_index) and not RunData.player_has_starting_items(player_index):
			_set_selected_element(player_index)
			var panel = _get_panels()[player_index]
			panel.set_data(RunData.get_player_character(player_index), player_index)
			panel.show()

	_c8_build_cells()


func _c8_build_cells() -> void :
	if _c8_cells_built:
		return
	_c8_cells_built = true

	var panels = _get_panels()
	var inventory_containers = _get_inventory_containers()
	var inventories_row = inventory_containers[0].get_parent()
	var panels_row = panels[0].get_parent()
	var description_container = panels_row.get_parent()

	var grid_box = VBoxContainer.new()
	grid_box.name = "C8WeaponGrid"
	grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content_parent = inventories_row.get_parent()
	content_parent.add_child(grid_box)
	content_parent.move_child(grid_box, inventories_row.get_index())

	for row_index in range(2):
		var row = HBoxContainer.new()
		row.name = "C8WeaponRow" + str(row_index + 1)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_constant_override("separation", 10)
		grid_box.add_child(row)
		_c8_grid_rows.push_back(row)

	for i in range(8):
		var content = VBoxContainer.new()
		content.name = "C8WeaponCellContent" + str(i + 1)
		content.add_constant_override("separation", 8)

		var holder = Control.new()
		holder.name = "C8PanelHolder"
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.rect_min_size = Vector2(0, 500)
		holder.size_flags_vertical = 0

		var panel = panels[i]
		panel.get_parent().remove_child(panel)
		panel.anchor_left = 0
		panel.anchor_top = 0
		panel.anchor_right = 1
		panel.anchor_bottom = 1
		panel.margin_left = 0
		panel.margin_top = 0
		panel.margin_right = 0
		panel.margin_bottom = 0
		holder.add_child(panel)
		content.add_child(holder)

		var inventory_container = inventory_containers[i]
		inventory_container.get_parent().remove_child(inventory_container)
		inventory_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content.add_child(inventory_container)

		var cell = C8W.make_fit_cell(content, C8_CELL_DESIGN)
		cell.rect_min_size = Vector2(210, 300)
		_c8_grid_rows[i / 4].add_child(cell)

	# The old rows are now empty; free the vertical space they reserved.
	inventories_row.visible = false
	description_container.rect_min_size = Vector2(0, 0)
	description_container.visible = false
