extends Node2D

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

# Weighted tile variants by biome
# TODO: Label which tiles are which
const BIOME_TILE_VARIANTS = {
	"Grass": [
		# Plain Grass
		{"Atlas_Origin": Vector2i(0, 0), "Weight": 90},

		# Seeded Grass
		{"Atlas_Origin": Vector2i(3, 0), "Weight": 10},
	],
	"Tundra": [
		{"Atlas_Origin": Vector2i(0, 3), "Weight": 90},
		{"Atlas_Origin": Vector2i(3, 3), "Weight": 10},
	],
	"Mesa": [
		{"Atlas_Origin": Vector2i(0, 6), "Weight": 90},
		{"Atlas_Origin": Vector2i(3, 6), "Weight": 10},
	],
	"Beach": [
		{"Atlas_Origin": Vector2i(0, 9), "Weight": 95},
		{"Atlas_Origin": Vector2i(3, 9), "Weight": 5},
	],
	"Ocean": [
		{"Atlas_Origin": Vector2i(0, 12), "Weight": 95},
		{"Atlas_Origin": Vector2i(3, 12), "Weight": 2},
		{"Atlas_Origin": Vector2i(6, 12), "Weight": 1},
		{"Atlas_Origin": Vector2i(9, 12), "Weight": 1},
		{"Atlas_Origin": Vector2i(12, 12), "Weight": 1},
	],
}

# Atlas_Origin refers to the tile unit position of the object in the tileset
# Size refers to width x height in tile units
# Chance is the per-tile percent chance for each object to be selected for potential placement (depends on available biome space, etc.)
# TODO: Label which objects are which
const BIOME_OBJECTS = {
	"Grass": [
		# Shrub
		{"Atlas_Origin": Vector2i(11, 0), "Size": Vector2i(1, 1), "Chance": 3.0},

		#Flower
		{"Atlas_Origin": Vector2i(11, 1), "Size": Vector2i(1, 1), "Chance": 3.0},

		# Tree 1x2
		{"Atlas_Origin": Vector2i(12, 0), "Size": Vector2i(1, 2), "Chance": 5.0},

		# Stacked Rocks
		{"Atlas_Origin": Vector2i(13, 0), "Size": Vector2i(1, 1), "Chance": 1.0},

		# Pebbles
		{"Atlas_Origin": Vector2i(14, 0), "Size": Vector2i(1, 1), "Chance": 1.0},

		# Mushrooms
		{"Atlas_Origin": Vector2i(15, 0), "Size": Vector2i(1, 1), "Chance": 1.0},

		# Bush
		{"Atlas_Origin": Vector2i(13, 1), "Size": Vector2i(1, 1), "Chance": 1.0},

		# Flower Patch
		{"Atlas_Origin": Vector2i(14, 1), "Size": Vector2i(1, 1), "Chance": 1.0},

		# Mini-Bush
		{"Atlas_Origin": Vector2i(15, 1), "Size": Vector2i(1, 1), "Chance": 1.0},

		# Tree 3x3
		{"Atlas_Origin": Vector2i(16, 0), "Size": Vector2i(3, 3), "Chance": 10.0},
	],
	"Tundra": [
		{"Atlas_Origin": Vector2i(11, 3), "Size": Vector2i(1, 1), "Chance": 3.0},
		{"Atlas_Origin": Vector2i(11, 4), "Size": Vector2i(1, 1), "Chance": 3.0},
		{"Atlas_Origin": Vector2i(12, 3), "Size": Vector2i(1, 1), "Chance": 1.0},
		{"Atlas_Origin": Vector2i(12, 4), "Size": Vector2i(1, 1), "Chance": 1.0},
		{"Atlas_Origin": Vector2i(13, 3), "Size": Vector2i(2, 2), "Chance": 5.0},
		{"Atlas_Origin": Vector2i(15, 3), "Size": Vector2i(1, 1), "Chance": 1.0},
		{"Atlas_Origin": Vector2i(15, 4), "Size": Vector2i(1, 1), "Chance": 1.0},
		{"Atlas_Origin": Vector2i(16, 3), "Size": Vector2i(3, 3), "Chance": 10.0},
	],
	"Mesa": [
		{"Atlas_Origin": Vector2i(11, 6), "Size": Vector2i(1, 1), "Chance": 3.0},
		{"Atlas_Origin": Vector2i(11, 7), "Size": Vector2i(1, 1), "Chance": 3.0},
		{"Atlas_Origin": Vector2i(12, 6), "Size": Vector2i(1, 2), "Chance": 5.0},
		{"Atlas_Origin": Vector2i(13, 6), "Size": Vector2i(2, 2), "Chance": 5.0},
		{"Atlas_Origin": Vector2i(15, 6), "Size": Vector2i(1, 1), "Chance": 1.0},
		{"Atlas_Origin": Vector2i(15, 7), "Size": Vector2i(1, 1), "Chance": 1.0},
		{"Atlas_Origin": Vector2i(16, 6), "Size": Vector2i(3, 3), "Chance": 2.5},
	],
	"Beach": [
		{"Atlas_Origin": Vector2i(11, 9), "Size": Vector2i(1, 1), "Chance": 3.0},
		{"Atlas_Origin": Vector2i(11, 10), "Size": Vector2i(1, 1), "Chance": 3.0},
		{"Atlas_Origin": Vector2i(12, 9), "Size": Vector2i(1, 1), "Chance": 0.5},
		{"Atlas_Origin": Vector2i(12, 10), "Size": Vector2i(1, 1), "Chance": 0.5},
		{"Atlas_Origin": Vector2i(13, 9), "Size": Vector2i(2, 2), "Chance": 5.0},
		{"Atlas_Origin": Vector2i(15, 9), "Size": Vector2i(1, 1), "Chance": 0.5},
		{"Atlas_Origin": Vector2i(15, 10), "Size": Vector2i(1, 1), "Chance": 0.5},
		{"Atlas_Origin": Vector2i(16, 9), "Size": Vector2i(3, 3), "Chance": 2.5},
	],
	"Ocean": [],
}

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
# TODO: Add more biomes and polish these ranges
func get_biome(alt, temp, moist):
	if alt < 0.2:
		return "Ocean"
	elif in_between(alt, 0.2, 0.35):
		return "Beach"
	elif in_between(alt, 0.35, 0.8):
		if in_between(moist, 0, 0.9) and in_between(temp, 0, 0.6):
			return "Grass"
		elif in_between(moist, 0.4, 0.9) and temp > 0.6:
			return "Mesa"
		elif temp > 0.6 and moist < 0.4:
			return "Mesa"
		elif moist >= 0.9:
			return "Ocean"
	else:
		return "Tundra"

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
func can_place_object(anchor_pos: Vector2i, biome_name: String, size: Vector2i, occupied: Dictionary) -> bool:
	# Require the target biome for the full area plus a 1-tile border on all sides
	for dx in range(-1, size.x + 1):
		for dy in range(-1, size.y + 1):
			var check_pos = anchor_pos + Vector2i(dx, dy)
			if biome.get(check_pos) != biome_name:
				return false

	# But keep overlap prevention limited to the actual tile area
	for dx in range(size.x):
		for dy in range(size.y):
			var check_pos = anchor_pos + Vector2i(dx, dy)
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
			var place_pos = anchor_pos + Vector2i(dx, dy)
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

	for x in range(map_width):
		for y in range(map_height):
			var pos = Vector2i(x, y) + origin

			var alt = altitude[pos]
			var temp = temperature[pos]
			var moist = moisture[pos]

			var current_biome = get_biome(alt, temp, moist)
			biome[pos] = current_biome
			environmentLayer.set_cell(pos, 0, pick_weighted_tile(current_biome))

# Helper comparison function to determine biome
func in_between(val, start, end):
	if start <= val and val < end:
		return true

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

	# Arbitrary values to input into noise generator
	temperature = generate_map(300, 5)
	moisture = generate_map(300, 5)
	altitude = generate_map(150, 5)
	
	set_tile()
	scatter_biome_objects()
