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

	# Popups get pinned to a fixed slot inside their owner's cell: the vanilla
	# per-frame repositioning maths breaks inside scaled trees (popups drifted
	# off-screen and across row boundaries), so it is disabled per instance and
	# replaced with a visibility-driven pin. They are also shrunk to cover less
	# of the cramped cells.
	for i in range(RunData.get_player_count()):
		if containers[i] == null:
			continue
		var cell_path = containers[i].get_parent().get_path()
		var popup = _get_stat_popup(i)
		if popup != null:
			popup.parent_node_path = cell_path
			popup.rect_scale = Vector2(0.75, 0.75)
			_c8_register_popup_pin(popup, containers[i])
		if containers[i].item_popup != null:
			containers[i].item_popup.parent_node_path = cell_path
			containers[i].item_popup.rect_scale = Vector2(0.75, 0.75)
			_c8_register_popup_pin(containers[i].item_popup, containers[i])
	print("C8| shop grid: done")


func _c8_register_popup_pin(popup: Control, container: Control) -> void :
	popup.set_process(false)
	if not popup.is_connected("visibility_changed", self, "_c8_on_popup_visibility"):
		var _e = popup.connect("visibility_changed", self, "_c8_on_popup_visibility", [popup, container])


func _c8_on_popup_visibility(popup: Control, container: Control) -> void :
	if popup.visible:
		call_deferred("_c8_pin_popup", popup, container)


func _c8_pin_popup(popup: Control, container: Control) -> void :
	# Fixed tooltip slot: upper third of the owner's cell, shifted up if the
	# popup would reach the GO button at the bottom. Never leaves the cell.
	if not is_instance_valid(popup) or not is_instance_valid(container) or not popup.visible:
		return
	var cell = container.get_parent()
	var rect: Rect2 = cell.get_global_rect()
	var popup_scale: Vector2 = popup.get_global_transform().get_scale()
	var estimated_height := 260.0
	if "_panel" in popup and popup._panel != null:
		estimated_height = popup._panel.rect_size.y * popup_scale.y * 1.6
	var y: float = min(rect.position.y + rect.size.y * 0.28, rect.end.y - 55.0 - estimated_height)
	popup.rect_global_position = Vector2(rect.position.x + 4.0, max(rect.position.y + 4.0, y))


func _on_GoButton_pressed(player_index: int) -> void :
	._on_GoButton_pressed(player_index)
	# A readied player's lingering tooltips must not cover anyone's buttons.
	if RunData.get_player_count() > 4 and _player_pressed_go_button[player_index]:
		_popup_manager.reset_focus(player_index)
		var stat_popup = _get_stat_popup(player_index)
		if stat_popup != null:
			stat_popup.hide()
		var container = _get_coop_player_container(player_index)
		if container != null and container.item_popup != null:
			container.item_popup.hide()


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
