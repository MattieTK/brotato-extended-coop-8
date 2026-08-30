extends "res://ui/menus/run/coop_end_run.gd"

const C8 = preload("res://mods-unpacked/MattieTK-ExtendedCoop8/c8.gd")

# End-of-run screen. Vanilla _ready runs with the menu guard capping the count
# at 4 (its onready node arrays only hold 4 entries); this extension then adds
# and wires players 5-8. Extra nodes are tracked by direct reference (no
# unique-name registration); grid restructuring happens last, in _ready.

var _c8_guarding: = false
var _c8_containers: = []
var _c8_item_popups: = []
var _c8_stat_popups: = []
var _c8_built: = false


func _init() -> void :
	RunData.c8_guard_inc()
	_c8_guarding = true


func _enter_tree() -> void :
	if RunData.c8_true_player_count() <= 4 or _c8_built:
		return
	_c8_built = true

	var template = get_node("%PlayerContainer4")
	var row1 = template.get_parent()

	for i in range(4, 8):
		var container = template.duplicate()
		container.name = "PlayerContainer%d" % (i + 1)
		container.player_index = i
		row1.add_child(container)
		_c8_containers.push_back(container)

	var item_popup_template = get_node("%ItemPopup4")
	for i in range(4, 8):
		var popup = item_popup_template.duplicate()
		popup.name = "ItemPopup%d" % (i + 1)
		popup.visible = false
		item_popup_template.get_parent().add_child(popup)
		_c8_item_popups.push_back(popup)

	var stat_popup_template = get_node("%StatPopup4")
	for i in range(4, 8):
		var popup = stat_popup_template.duplicate()
		popup.name = "StatPopup%d" % (i + 1)
		popup.visible = false
		stat_popup_template.get_parent().add_child(popup)
		_c8_stat_popups.push_back(popup)

	var template_fe = get_node("FocusEmulator4")
	for i in range(4, 8):
		var fe = C8.clone_focus_emulator(self, template_fe, i)
		C8.repoint_focus_emulator(fe, template, _c8_containers[i - 4])


func _ready() -> void :
	if _c8_guarding:
		_c8_guarding = false
		RunData.c8_guard_dec()

	var player_count: int = RunData.get_player_count()
	if player_count <= 4 or not _c8_built:
		return

	# Extend the onready arrays and re-trigger per-player configuration now
	# that the real player count is visible again.
	for i in range(4):
		player_containers.push_back(_c8_containers[i])
		item_popups.push_back(_c8_item_popups[i])
		stat_popups.push_back(_c8_stat_popups[i])
		_c8_containers[i].player_index = i + 4
		_c8_containers[i].visible = i + 4 < player_count

	for player_index in range(4, player_count):
		var player_container = player_containers[player_index]

		var weapons_container = player_container.weapons_container
		var weapons = RunData.get_player_weapons(player_index)
		weapons_container.visible = not weapons.empty()
		weapons_container.set_data("WEAPONS", Category.WEAPON, weapons)

		var items_container = player_container.items_container
		var items = RunData.get_player_items(player_index)
		items_container.set_data("ITEMS", Category.ITEM, items, true, true)

		var item_popup = item_popups[player_index]
		item_popup.connect("popup_toggled", self, "_on_popup_toggled")
		item_popup.player_index = player_index
		item_popup.parent_node_path = player_container.carousel.get_path()
		_popup_manager.add_item_popup(item_popup, player_index)
		_popup_manager.connect_inventory_container(weapons_container)
		_popup_manager.connect_inventory_container(items_container)

		var stat_popup = stat_popups[player_index]
		stat_popup.parent_node_path = player_container.carousel.get_path()
		_popup_manager.add_stat_popup(stat_popup, player_index)
		_popup_manager.connect_stats_container(player_container.primary_stats_container)
		_popup_manager.connect_stats_container(player_container.secondary_stats_container)

		player_container.focus()

	_c8_build_grid()


func _c8_build_grid() -> void :
	print("C8| end run grid: start")
	var row1 = player_containers[0].get_parent()
	var design_size = player_containers[3].rect_size

	var row2 = HBoxContainer.new()
	row2.name = "C8Row2"
	row2.size_flags_horizontal = row1.size_flags_horizontal
	row2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rows_parent = row1.get_parent()
	rows_parent.add_child(row2)
	rows_parent.move_child(row2, row1.get_index() + 1)

	for i in range(8):
		var cell = C8.make_fit_cell(player_containers[i], design_size)
		if i >= 4:
			cell.get_parent().remove_child(cell)
			row2.add_child(cell)

	# Anchor every popup to its player's (unscaled) grid cell: the popups'
	# built-in clamping then keeps them inside that player's own area.
	for i in range(min(RunData.get_player_count(), player_containers.size())):
		var cell_path = player_containers[i].get_parent().get_path()
		if i < item_popups.size() and item_popups[i] != null:
			item_popups[i].parent_node_path = cell_path
		if i < stat_popups.size() and stat_popups[i] != null:
			stat_popups[i].parent_node_path = cell_path
	print("C8| end run grid: done")


func _exit_tree() -> void :
	if _c8_guarding:
		_c8_guarding = false
		RunData.c8_guard_dec()
