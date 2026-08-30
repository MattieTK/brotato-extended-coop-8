extends "res://ui/menus/run/character_selection.gd"

const C8C = preload("res://mods-unpacked/MattieTK-ExtendedCoop8/c8.gd")

# Coop uses a full 2x4 grid of player slots (each slot holds that player's
# character panel, locked panel and join panel); solo keeps the vanilla layout.
# All extra nodes are tracked by direct reference. Vanilla nodes are only moved
# after their onready lookups resolved (lazily, on the first mode switch).

const C8_SLOT_DESIGN := Vector2(440, 500)

var _c8_rows_box = null
var _c8_slots: = []
var _c8_panels_extra: = []
var _c8_join_extras: = []
var _c8_locked_extras: = []
var _c8_slots_populated: = false
var _c8_hbox = null


func _get_panels() -> Array:
	var panels = ._get_panels()
	panels.append_array(_c8_panels_extra)
	return panels


func _enter_tree() -> void :
	C8C.pad(_player_characters, "null")
	if Utils.on_console:
		return
	if _c8_rows_box == null:
		_c8_build_structure()


func _c8_build_structure() -> void :
	var panel_prefab = load("res://ui/menus/ingame/character_panel_ui.tscn")
	var locked_panel_prefab = load("res://ui/menus/run/locked_panel.tscn")
	var coop_join_panel_prefab = load("res://ui/menus/run/coop_join_panel.tscn")

	_c8_hbox = get_node("%CoopJoinPanel1").get_parent()

	_c8_rows_box = VBoxContainer.new()
	_c8_rows_box.name = "C8SlotRows"
	_c8_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_c8_rows_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_c8_rows_box.visible = false
	_c8_hbox.add_child(_c8_rows_box)
	_c8_hbox.move_child(_c8_rows_box, 0)

	var rows: = []
	for row_index in range(2):
		var row = HBoxContainer.new()
		row.name = "C8SlotRow" + str(row_index + 1)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.add_constant_override("separation", 10)
		rows.push_back(row)
		_c8_rows_box.add_child(row)

	for i in range(8):
		var slot = Control.new()
		slot.name = "C8Slot" + str(i + 1)
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_c8_slots.push_back(slot)
		var cell = C8C.make_fit_cell(slot, C8_SLOT_DESIGN)
		cell.rect_min_size = Vector2(210, 235)
		rows[i / 4].add_child(cell)

	# Players 5-8 get fresh nodes, created directly inside their slots.
	for i in range(4, 8):
		var n = str(i + 1)
		var slot = _c8_slots[i]

		var panel_instance = panel_prefab.instance()
		panel_instance.player_index = i
		panel_instance.name = "Panel" + n
		panel_instance.visible = false
		_c8_anchor_full(panel_instance)
		slot.add_child(panel_instance)
		_c8_panels_extra.push_back(panel_instance)

		var locked_panel_instance = locked_panel_prefab.instance()
		locked_panel_instance.name = "LockedPanel" + n
		locked_panel_instance.visible = false
		_c8_anchor_full(locked_panel_instance)
		slot.add_child(locked_panel_instance)
		_c8_locked_extras.push_back(locked_panel_instance)

		var coop_panel_instance = coop_join_panel_prefab.instance()
		coop_panel_instance.player_index = i
		coop_panel_instance.name = "CoopJoinPanel" + n
		coop_panel_instance.visible = false
		_c8_anchor_full(coop_panel_instance)
		slot.add_child(coop_panel_instance)
		_c8_join_extras.push_back(coop_panel_instance)

	var template_fe = get_node("FocusEmulator4")
	for i in range(4, 8):
		var _fe = C8C.clone_focus_emulator(self, template_fe, i)


func _c8_anchor_full(node: Control) -> void :
	node.anchor_left = 0
	node.anchor_top = 0
	node.anchor_right = 1
	node.anchor_bottom = 1
	node.margin_left = 0
	node.margin_top = 0
	node.margin_right = 0
	node.margin_bottom = 0


func _c8_populate_slots_once() -> void :
	# Move the vanilla per-player nodes into their slots. Runs after onready
	# lookups resolved (first _play_mode_init call happens inside _ready).
	if _c8_slots_populated:
		return
	_c8_slots_populated = true
	var vanilla_trios = [
		[null, null, _coop_join_panel1],
		[_panel2, _locked_panel2, _coop_join_panel2],
		[_panel3, _locked_panel3, _coop_join_panel3],
		[_panel4, _locked_panel4, _coop_join_panel4],
	]
	for i in range(4):
		for node in vanilla_trios[i]:
			if node == null:
				continue
			node.get_parent().remove_child(node)
			_c8_anchor_full(node)
			_c8_slots[i].add_child(node)


func _c8_set_grid_mode(coop: bool) -> void :
	if _c8_rows_box == null:
		return
	_c8_populate_slots_once()
	_c8_rows_box.visible = coop
	# Player 1's panels live in the vanilla row for solo, in slot 1 for coop.
	var slot_1 = _c8_slots[0]
	if coop:
		for node in [_panel1, _locked_panel1]:
			if node.get_parent() != slot_1:
				node.get_parent().remove_child(node)
				_c8_anchor_full(node)
				slot_1.add_child(node)
	else:
		for node_index in range(2):
			var node = [_panel1, _locked_panel1][node_index]
			if node.get_parent() != _c8_hbox:
				node.get_parent().remove_child(node)
				_c8_hbox.add_child(node)
				_c8_hbox.move_child(node, node_index + 1)


func _play_mode_init(mode: int, initialize: bool) -> void :
	._play_mode_init(mode, initialize)
	if not Utils.on_console:
		_c8_set_grid_mode(RunData.is_coop_run)


func _c8_after_finalize(_count: int) -> void :
	_update_character_selection_player_count_ui()


func _get_coop_join_panels() -> Array:
	var ret = [_coop_join_panel1, _coop_join_panel2, _coop_join_panel3, _coop_join_panel4]
	ret.append_array(_c8_join_extras)
	ret.resize(CoopService.get_max_players())
	return ret


func _get_locked_panels() -> Array:
	var ret = [_locked_panel1, _locked_panel2, _locked_panel3, _locked_panel4]
	ret.append_array(_c8_locked_extras)
	ret.resize(CoopService.get_max_players())
	return ret


func _on_ZoneSelectionButton_item_selected(index: int) -> void :
	._on_ZoneSelectionButton_item_selected(index)
	_c8_update_extra_panel_backgrounds()


func _setup_zone(index: int) -> void :
	._setup_zone(index)
	_c8_update_extra_panel_backgrounds()


func _c8_update_extra_panel_backgrounds() -> void :
	for panel in _c8_panels_extra:
		panel._update_bg()
