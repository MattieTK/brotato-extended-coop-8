# ExtendedCoop8 shared helpers.
# Static utilities used by the script extensions. Not registered as an autoload;
# extensions preload this script directly.

const MAX_PLAYERS := 8


static func pad(arr: Array, kind: String, size: int = MAX_PLAYERS) -> void :
	# Grows a per-player array to `size`, appending a fresh value per slot.
	while arr.size() < size:
		match kind:
			"dict":
				arr.push_back({})
			"array":
				arr.push_back([])
			"int":
				arr.push_back(0)
			"bool":
				arr.push_back(false)
			_:
				arr.push_back(null)


static func register_unique(node: Node, owner_node: Node) -> void :
	# Makes a runtime-added node addressable via get_node("%Name") on the scene root.
	node.unique_name_in_owner = false
	node.owner = owner_node
	node.unique_name_in_owner = true


static func clone_focus_emulator(root: Node, template: Node2D, player_index: int) -> Node2D:
	# Duplicates an existing FocusEmulator node for an extra player. Base data
	# resources are duplicated so later path edits never touch the originals.
	var fe = template.duplicate()
	fe.name = "FocusEmulator%d" % (player_index + 1)
	root.add_child(fe)
	var new_data: = []
	for data in fe.focus_base_data:
		new_data.push_back(data.duplicate())
	fe.focus_base_data = new_data
	fe.player_index = player_index
	return fe


static func repoint_focus_emulator(fe: Node2D, old_target: Node, new_target: Node) -> void :
	# Re-targets any base data entry that pointed at old_target (or that no longer
	# resolves, e.g. after the target was reparented into a grid cell).
	if fe == null:
		return
	var new_data: = []
	for data in fe.focus_base_data:
		var d = data.duplicate()
		var resolved = fe.get_node_or_null(d.path)
		if resolved == old_target or resolved == null:
			d.path = fe.get_path_to(new_target)
		new_data.push_back(d)
	fe.focus_base_data = new_data


static func make_fit_cell(content: Control, design_size: Vector2) -> Control:
	# Wraps `content` in an expand-fill cell that uniformly scales it to the
	# cell's height, so full-size UI panels can live in a half-height grid row.
	var cell = load("res://mods-unpacked/MattieTK-ExtendedCoop8/c8_fit_cell.gd").new()
	cell.name = "C8Cell_" + content.name
	cell.design_size = design_size
	var parent = content.get_parent()
	if parent != null:
		var idx = content.get_index()
		parent.remove_child(content)
		parent.add_child(cell)
		parent.move_child(cell, idx)
	content.anchor_left = 0
	content.anchor_top = 0
	content.anchor_right = 0
	content.anchor_bottom = 0
	cell.add_child(content)
	cell.set_content(content)
	return cell
