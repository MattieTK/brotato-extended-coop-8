extends "res://ui/menus/ingame/upgrades_ui.gd"

const C8 = preload("res://mods-unpacked/MattieTK-ExtendedCoop8/c8.gd")

# CoopUpgradesUI lives inside main.tscn. With more than 4 players the vanilla
# _ready aborts once it reads its local 4-slot stat popup array at index 4
# (players 1-4 are already fully wired at that point); this extension adds the
# extra containers and wires players 5-8. Extra nodes are tracked by direct
# reference (no unique-name registration), and the grid restructuring happens
# in _ready after all wiring has cached its references.

var _c8_extra_containers: = []
var _c8_extra_popups: = []
var _c8_built: = false


func _init() -> void :
	C8.pad(_showing_option, "null")
	C8.pad(_player_is_choosing, "bool")
	C8.pad(_extra_items_to_process, "array")


func _enter_tree() -> void :
	if not is_coop_ui or _c8_built:
		return
	if not RunData.is_coop_run or RunData.get_player_count() <= 4:
		return
	_c8_built = true

	var player_count = RunData.get_player_count()
	var prefab = load("res://ui/menus/ingame/coop_upgrades_ui_player_container.tscn")
	var template = get_node("%UpgradesUIPlayerContainer4")
	var row1 = template.get_parent()

	for i in range(4, 8):
		var container = prefab.instance()
		container.player_index = i
		container.name = "UpgradesUIPlayerContainer%d" % (i + 1)
		container.visible = i < player_count
		row1.add_child(container)
		_c8_extra_containers.push_back(container)

	var popup_template = get_node("%StatPopup4")
	for i in range(4, 8):
		var popup = popup_template.duplicate()
		popup.name = "StatPopup%d" % (i + 1)
		popup.visible = false
		popup_template.get_parent().add_child(popup)
		_c8_extra_popups.push_back(popup)

	var template_fe = get_node("FocusEmulator4")
	for i in range(4, 8):
		var fe = C8.clone_focus_emulator(self, template_fe, i)
		C8.repoint_focus_emulator(fe, template, _c8_extra_containers[i - 4])


func _ready() -> void :
	if RunData.is_coop_run != is_coop_ui:
		return
	var player_count = RunData.get_player_count()
	if player_count <= 4 or not _c8_built:
		return

	# Wire players 5-8 the same way vanilla _ready wires 1-4.
	for player_index in range(4, player_count):
		var player_container = _get_player_container(player_index)
		if player_container == null:
			continue
		if not player_container.is_connected("choose_button_pressed", self, "_on_choose_button_pressed"):
			var _e = player_container.connect("choose_button_pressed", self, "_on_choose_button_pressed", [player_index])
			_e = player_container.connect("item_take_button_pressed", self, "_on_take_button_pressed", [player_index])
			_e = player_container.connect("item_discard_button_pressed", self, "_on_discard_button_pressed", [player_index])
			_e = player_container.connect("item_ban_button_pressed", self, "_on_ban_button_pressed", [player_index])

		var stat_popup = _c8_extra_popups[player_index - 4]
		stat_popup.parent_node_path = player_container.carousel.get_path()
		_popup_manager.add_stat_popup(stat_popup, player_index)

		player_container.focus_emulator = Utils.get_focus_emulator(player_index, self)
		_popup_manager.connect_stats_container(player_container.primary_stats_container)
		_popup_manager.connect_stats_container(player_container.secondary_stats_container)
		_popup_manager.add_item_popup(player_container.item_popup, player_index)
		_popup_manager.connect_inventory_container(player_container.player_gear_container.weapons_container)
		_popup_manager.connect_inventory_container(player_container.player_gear_container.items_container)

	_c8_build_grid()


func _c8_build_grid() -> void :
	print("C8| upgrades grid: start")
	var containers = []
	for i in range(8):
		containers.push_back(_get_player_container(i))
	var row1 = containers[0].get_parent()
	var design_size = containers[3].rect_size

	row1.anchor_bottom = 0.5
	var row2 = HBoxContainer.new()
	row2.name = "C8Row2"
	row2.anchor_left = 0
	row2.anchor_top = 0.5
	row2.anchor_right = 1
	row2.anchor_bottom = 1
	row2.add_constant_override("separation", 0)
	row1.get_parent().add_child(row2)
	row1.get_parent().move_child(row2, row1.get_index() + 1)

	for i in range(8):
		var cell = C8.make_fit_cell(containers[i], design_size)
		if i >= 4:
			cell.get_parent().remove_child(cell)
			row2.add_child(cell)

	# Anchor every popup to its player's (unscaled) grid cell: the popups'
	# built-in clamping then keeps them inside that player's own area.
	var stat_popups = [_stat_popup1, _stat_popup2, _stat_popup3, _stat_popup4]
	stat_popups.append_array(_c8_extra_popups)
	for i in range(min(RunData.get_player_count(), stat_popups.size())):
		if containers[i] == null:
			continue
		var cell_path = containers[i].get_parent().get_path()
		if stat_popups[i] != null:
			stat_popups[i].parent_node_path = cell_path
		if containers[i].item_popup != null:
			containers[i].item_popup.parent_node_path = cell_path
	print("C8| upgrades grid: done")


func _get_player_container(player_index: int) -> UpgradesUIPlayerContainer:
	if player_index < 4:
		return ._get_player_container(player_index)
	if player_index - 4 < _c8_extra_containers.size():
		return _c8_extra_containers[player_index - 4]
	return null
