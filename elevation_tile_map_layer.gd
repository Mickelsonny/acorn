extends TileMapLayer

var _3d_layer: int = 0

var brightness_base: float = 0.95
var brightness_fade_step: float = 0.05

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	z_index = _3d_layer - 1
	
	var brightness: float = brightness_base + ((_3d_layer - 1) * brightness_fade_step)
	brightness = clamp(brightness, 0.0, 2.0) 
	modulate = Color(brightness, brightness, brightness)
