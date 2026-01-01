extends Node2D

@export var noise_height_texture : NoiseTexture2D

var noise : Noise
var width : int = 75
var height : int = 75

@onready var tile_map_layer = $TestGroundLayer

var TERRAIN_OCEAN = 0
var TERRAIN_GRASS = 1
var TERRAIN_SAND = 2
var TERRAIN_MESA = 3
var TERRAIN_SNOW = 4

func _ready() -> void:
	noise = noise_height_texture.noise
	generate_world()

func generate_world():
	var half_width := width / 2.0
	var half_height := height / 2.0

	for x in range(-half_width, half_width):
		for y in range(-half_height, half_height):
			tile_map_layer.set_cells_terrain_connect([Vector2i(x, y)], 0, TERRAIN_OCEAN, false)
	
	for x in range(-half_width, half_width):
		for y in range(-half_height, half_height):
			var noise_val : float = noise.get_noise_2d(x, y)

			if noise_val >= -0.4:
				var terrain_id = get_terrain_from_noise(noise_val)
				tile_map_layer.set_cells_terrain_connect([Vector2i(x, y)], 0, terrain_id, false)

func get_terrain_from_noise(noise_val: float) -> int:
	if noise_val < -0.15:
		return TERRAIN_SAND
	elif noise_val < 0.1:
		return TERRAIN_GRASS
	elif noise_val < 0.35:
		return TERRAIN_MESA
	else:
		return TERRAIN_SNOW
