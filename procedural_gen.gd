extends Node2D

const BeachBiome = preload("res://biomes/beach_biome.gd")
const GrassBiome = preload("res://biomes/grass_biome.gd")
const TundraBiome = preload("res://biomes/tundra_biome.gd")
const MesaBiome = preload("res://biomes/mesa_biome.gd")
const OceanBiome = preload("res://biomes/ocean_biome.gd")

@export var map_width = 400
@export var map_height = 400
@export var world_seed = 0
@onready var environmentLayer = $EnvironmentLayer
@onready var objectLayer = $ObjectLayer

var temperature = {}
var moisture = {}
var altitude = {}
var biome = {}

var fastNoiseLite = FastNoiseLite.new()
var randomNumberGenerator = RandomNumberGenerator.new()

# Center the map around the origin
var origin = Vector2i(-(map_width >> 1), -(map_height >> 1))

var BIOME_DEFINITIONS = {}
var BIOME_TILE_VARIANTS = {}
var BIOME_OBJECTS = {}

func initialize_biomes() -> void:
	BIOME_DEFINITIONS = {
		"Grass": {
			"TileVariants": GrassBiome.TILE_VARIANTS,
			"Objects": GrassBiome.OBJECTS,
		},
		"Tundra": {
			"TileVariants": TundraBiome.TILE_VARIANTS,
			"Objects": TundraBiome.OBJECTS,
		},
		"Mesa": {
			"TileVariants": MesaBiome.TILE_VARIANTS,
			"Objects": MesaBiome.OBJECTS,
		},
		"Beach": {
			"TileVariants": BeachBiome.TILE_VARIANTS,
			"Objects": BeachBiome.OBJECTS,
			"PickTile": Callable(BeachBiome, "pick_tile"),
		},
		"Ocean": {
			"TileVariants": OceanBiome.TILE_VARIANTS,
			"Objects": OceanBiome.OBJECTS,
		},
	}

	BIOME_TILE_VARIANTS.clear()
	BIOME_OBJECTS.clear()
	for biome_name in BIOME_DEFINITIONS.keys():
		var definition: Dictionary = BIOME_DEFINITIONS[biome_name]
		BIOME_TILE_VARIANTS[biome_name] = definition.get("TileVariants", [])
		BIOME_OBJECTS[biome_name] = definition.get("Objects", [])


func generate_map(period, octave):
	# Set the seed and parameters for FastNoiseLite
	fastNoiseLite.seed = world_seed
	fastNoiseLite.frequency = 1.0 / period
	fastNoiseLite.fractal_octaves = octave
	
	var gridName = {}
	for x in range(map_width):
		for y in range(map_height):
			var pos = Vector2i(x, y) + origin

			# Returns the value of the noise at the given coordinate position
			var rand: float = 2 * abs(fastNoiseLite.get_noise_2d(float(pos.x), float(pos.y)))

			# Position is the key to gridName (which are the temperature, moisture, altitude dictionaries)
			gridName[pos] = rand
	
	return gridName

# Biome generation which is a function of altitude, temperature, and moisture
func get_biome(alt, temp, moist):
	if alt < 0.2:
		return "Ocean"
	elif alt < 0.35:
		return "Beach"
	elif alt >= 0.8:
		return "Tundra"

	if moist < 0.4:
		if temp <= 0.6:
			return "Grass"
		return "Mesa"
	elif moist < 0.9:
		if temp <= 0.6:
			return "Grass"
		return "Mesa"
	else:
		return "Grass"

# Function to pick the tile variant based on the biome and its weights
func pick_weighted_tile(biome_name: String) -> Vector2i:
	var variants = BIOME_TILE_VARIANTS.get(biome_name)
	if variants.is_empty():
		return Vector2i.ZERO

	var total_weight = 0.0
	for variant in variants:
		total_weight += float(variant["Weight"])

	var roll = randomNumberGenerator.randf_range(0.0, total_weight)
	var running = 0.0
	for variant in variants:
		running += float(variant["Weight"])
		if roll < running:
			return variant["Atlas_Origin"]

	# Fallback
	return variants[-1]["Atlas_Origin"]

# Function to pick one object by chance in the range [0, 100)
func pick_object_by_chance(biome_name: String) -> Dictionary:
	var objects = BIOME_OBJECTS.get(biome_name)
	if objects.is_empty():
		return {}

	var roll = randomNumberGenerator.randf_range(0.0, 100.0)
	var running = 0.0
	for object in objects:
		running += float(object.get("Chance"))
		if roll < running:
			return object

	# Fallback
	return {}

# Helper function to check if an object can be placed at the given position based on its size and the respective biome
# Note: Anchor tile is bottom left for multi-tile objects
func can_place_object(anchor_pos: Vector2i, biome_name: String, size: Vector2i, occupied: Dictionary) -> bool:
	# Require the target biome for the full area plus a 1-tile border on all sides
	for dx in range(-1, size.x + 1):
		for dy in range(-size.y, 2):
			var check_pos = anchor_pos + Vector2i(dx, dy)
			if biome.get(check_pos) != biome_name:
				return false

	# But keep overlap prevention limited to the actual tile area
	for dx in range(size.x):
		for dy in range(size.y):
			var check_pos = anchor_pos + Vector2i(dx, -dy)
			if occupied.has(check_pos):
				return false

	return true

# Helper function to place the object on the ObjectLayer and mark its occupied tiles
func place_object(anchor_pos: Vector2i, object: Dictionary, occupied: Dictionary) -> void:
	var size: Vector2i = object.get("Size")
	var atlas_origin: Vector2i = object.get("Atlas_Origin")

	# Atlas textures that are beyond 1x1 are placed once at the anchor
	objectLayer.set_cell(anchor_pos, 0, atlas_origin)

	# The full area is still accounted for through occupied cells
	for dx in range(size.x):
		for dy in range(size.y):
			var place_pos = anchor_pos + Vector2i(dx, -dy)
			occupied[place_pos] = true

# Main function to scatter biome objects based on object chances
func scatter_biome_objects() -> void:
	objectLayer.clear()
	var occupied = {}

	for x in range(map_width):
		for y in range(map_height):
			var pos = Vector2i(x, y) + origin
			if occupied.has(pos):
				continue

			var biome_name = biome.get(pos)
			var objects = BIOME_OBJECTS.get(biome_name)
			if objects.is_empty():
				continue

			var object = pick_object_by_chance(biome_name)
			if object.is_empty():
				continue

			var size: Vector2i = object.get("Size")
			if can_place_object(pos, biome_name, size, occupied):
				place_object(pos, object, occupied)

func set_tile():
	environmentLayer.clear()

	# First - Compute the biome for every tile
	for x in range(map_width):
		for y in range(map_height):
			var pos = Vector2i(x, y) + origin

			var alt = altitude[pos]
			var temp = temperature[pos]
			var moist = moisture[pos]

			biome[pos] = get_biome(alt, temp, moist)

	# Second - Place tiles using the completed biome map
	for x in range(map_width):
		for y in range(map_height):
			var pos = Vector2i(x, y) + origin
			var current_biome = biome[pos]
			
			# Check if the biome has a custom tile picking function and use it if available
			# Otherwise, pick a weighted tile variant
			var biome_definition: Dictionary = BIOME_DEFINITIONS.get(current_biome, {})
			var custom_pick_tile: Callable = biome_definition.get("PickTile", Callable())
			if custom_pick_tile.is_valid():
				environmentLayer.set_cell(pos, 0, custom_pick_tile.call(pos, biome, Callable(self, "pick_weighted_tile")))
			else:
				environmentLayer.set_cell(pos, 0, pick_weighted_tile(current_biome))

# Helper function to better visualize the procedurally generated world when pressing space bar/enter
func _input(event):
	if event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if world_seed == 0:
		randomize()
		world_seed = randi()

	# Set the random number generator seed to world_seed
	# Ensures consistent tile variant selection across runs
	randomNumberGenerator.seed = world_seed
	initialize_biomes()

	# Arbitrary values to input into noise generator
	temperature = generate_map(300, 5)
	moisture = generate_map(300, 5)
	altitude = generate_map(150, 5)
	
	set_tile()
	scatter_biome_objects()
