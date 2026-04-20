extends Node

# Area that must always be visible
const BASE_SIZE: Vector2 = Vector2(128.0, 128.0)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_update_size()
	get_tree().get_root().size_changed.connect(_update_size)

func _update_size() -> void:
	var size: Vector2 = DisplayServer.window_get_size()
	var ratio: float = min(size.x / BASE_SIZE.x, size.y / BASE_SIZE.y)
	ratio = max(1, floor(ratio))
	get_window().content_scale_factor = ratio
