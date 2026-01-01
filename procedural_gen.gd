extends Node2D

@export var noise_height_texture : NoiseTexture2D

var noise : Noise

var width : int = 100
var height : int = 100

@onready var tile_map_layer = $TileMapLayer

var source_id = 0

var TERRAIN_GRASS = 0
var TERRAIN_MESA = 1
var TERRAIN_OCEAN = 2
var TERRAIN_SAND = 3
var TERRAIN_SNOW = 4

func _ready() -> void:
	noise = noise_height_texture.noise
	generate_world()

func generate_world():
	for x in range(-width / 2, width / 2):
		for y in range(-height / 2, height / 2):
			var noise_val : float = noise.get_noise_2d(x, y)
			var terrain_id = get_terrain_from_noise(noise_val, x, y)

			tile_map_layer.set_cells_terrain_connect([Vector2i(x, y)], 0, terrain_id, false)

func get_terrain_from_noise(noise_val: float, _x: int, _y: int) -> int:
	if noise_val < -0.4:
		return TERRAIN_OCEAN
	elif noise_val < -0.2:
		return TERRAIN_SAND
	elif noise_val < 0.2:
		return TERRAIN_GRASS
	elif noise_val < 0.4:
		return TERRAIN_MESA
	else:
		return TERRAIN_SNOW
