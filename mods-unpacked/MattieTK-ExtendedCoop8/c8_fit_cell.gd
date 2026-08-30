extends Control
# A grid cell that uniformly scales its single content control to fit the
# cell's height while letting the content keep its designed layout size.

var content: Control = null
var design_size: = Vector2(480, 1030)


func _init() -> void :
	size_flags_horizontal = SIZE_EXPAND_FILL
	size_flags_vertical = SIZE_EXPAND_FILL
	mouse_filter = MOUSE_FILTER_IGNORE


func set_content(c: Control) -> void :
	content = c
	var _e = connect("resized", self, "_fit")
	_e = c.connect("visibility_changed", self, "_sync_visibility")


func _ready() -> void :
	call_deferred("_fit")
	_sync_visibility()


func _fit() -> void :
	if content == null:
		return
	var w: float = max(design_size.x, 1.0)
	var h: float = max(design_size.y, 1.0)
	var s: float = clamp(min(rect_size.x / w, rect_size.y / h), 0.05, 1.0)
	content.rect_scale = Vector2(s, s)
	content.rect_size = Vector2(max(rect_size.x / s, w), h)
	content.rect_position = Vector2.ZERO


func _sync_visibility() -> void :
	if content != null and visible != content.visible:
		visible = content.visible
