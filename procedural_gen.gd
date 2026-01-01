extends Node2D

@export var noise_height_texture : NoiseTexture2D
var noise : Noise

var width : int = 100
var height : int = 100

@onready var tile_map_layer = $TileMapLayer

var source_id = 0
var water_atlas = Vector2i(12, 0)
var grass_atlas = Vector2i(0, 0)

func _ready() -> void:
	noise = noise_height_texture.noise
	generate_world()

func generate_world():
	for x in range(-width / 2, width / 2):
		for y in range(-height / 2, height / 2):
			var noise_val : float = noise.get_noise_2d(x, y)
			if noise_val >= 0.0:
				tile_map_layer.set_cell(Vector2(x, y), source_id, grass_atlas)
			elif noise_val < 0.0:
				tile_map_layer.set_cell(Vector2(x, y), source_id, water_atlas)
