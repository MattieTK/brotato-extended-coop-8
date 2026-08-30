extends "res://ui/menus/shop/coop_shop.gd"

const C8S = preload("res://mods-unpacked/MattieTK-ExtendedCoop8/c8.gd")

# Extra nodes are tracked by direct reference — unique (%) names are never
# added or re-registered here, and the 2x4 grid restructuring happens in
# _ready, after all vanilla wiring has cached its node references.

var _c8_containers: = []
var _c8_popups: = []
var _c8_built: = false


func _enter_tree() -> void :
	if RunData.get_player_count() <= 4 or _c8_built:
		return
	_c8_built = true

	var player_count = RunData.get_player_count()
	var prefab = load("res://ui/menus/shop/coop_shop_player_container.tscn")
	var template = get_node("%CoopShopPlayerContainer4")
	var row1 = template.get_parent()

	for i in range(4, 8):
		var container = prefab.instance()
		container.name = "CoopShopPlayerContainer%d" % (i + 1)
		container.player_index = i
		container.visible = i < player_count
		row1.add_child(container)
		_c8_containers.push_back(container)

	var popup_template = get_node("%StatPopup4")
	for i in range(4, 8):
		var popup = popup_template.duplicate()
		popup.name = "StatPopup%d" % (i + 1)
		popup.visible = false
		popup_template.get_parent().add_child(popup)
		_c8_popups.push_back(popup)

	# Clone the focus emulators now, pointing each at its own container while
	# the pre-grid paths still resolve; FocusEmulator._ready caches node
	# references, so the later reparenting cannot break them.
	var template_fe = get_node("FocusEmulator4")
	for i in range(4, 8):
		var fe = C8S.clone_focus_emulator(self, template_fe, i)
		C8S.repoint_focus_emulator(fe, template, _c8_containers[i - 4])


func _ready() -> void :
	var player_count = RunData.get_player_count()
	if player_count <= 4 or not _c8_built:
		return
	for i in range(4, 8):
		_c8_containers[i - 4].visible = i < player_count
	_c8_build_grid()


func _c8_build_grid() -> void :
	print("C8| shop grid: start")
	_find_nodes()
	var containers = []
	for i in range(8):
		containers.push_back(_get_coop_player_container(i))
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
		var cell = C8S.make_fit_cell(containers[i], design_size)
		if i >= 4:
			cell.get_parent().remove_child(cell)
			row2.add_child(cell)

	# Anchor every popup to its player's (unscaled) grid cell — the popups'
	# built-in clamping then keeps them inside that player's own area — and
	# shrink them so they cover less of the cramped cells.
	for i in range(RunData.get_player_count()):
		if containers[i] == null:
			continue
		var cell_path = containers[i].get_parent().get_path()
		var popup = _get_stat_popup(i)
		if popup != null:
			popup.parent_node_path = cell_path
			popup.rect_scale = Vector2(0.75, 0.75)
		if containers[i].item_popup != null:
			containers[i].item_popup.parent_node_path = cell_path
			containers[i].item_popup.rect_scale = Vector2(0.75, 0.75)
	print("C8| shop grid: done")


func _find_nodes() -> void :
	._find_nodes()


func _get_coop_player_container(player_index: int) -> CoopShopPlayerContainer:
	if player_index < 4:
		return ._get_coop_player_container(player_index)
	if player_index - 4 < _c8_containers.size():
		return _c8_containers[player_index - 4]
	return null


func _get_stat_popup(player_index: int) -> StatPopup:
	if player_index < 4:
		return ._get_stat_popup(player_index)
	if player_index - 4 < _c8_popups.size():
		return _c8_popups[player_index - 4]
	return null
