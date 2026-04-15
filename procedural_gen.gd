extends Node2D

const BeachBiome = preload("res://biomes/beach_biome.gd")
const GrassBiome = preload("res://biomes/grass_biome.gd")
const TundraBiome = preload("res://biomes/tundra_biome.gd")
const MesaBiome = preload("res://biomes/mesa_biome.gd")
const OceanBiome = preload("res://biomes/ocean_biome.gd")
const BiomeObjectPlacer = preload("res://object_placement.gd")

# Bounding map & world variables
@export var map_width = 100
@export var map_height = 100
@export var world_seed = 0

# Arbitrary values to input into noise generator
# Biome generation
@export var temperature_period: float = 100.0
@export var moisture_period: float = 100.0
@export var altitude_period: float = 150.0
@export var temperature_octaves: int = 7
@export var moisture_octaves: int = 7
@export var altitude_octaves: int = 8

# Elevation generation
@export var elevation_base_period: float = 120.0
@export var elevation_detail_period: float = 50.0
@export var elevation_base_octaves: int = 5
@export var elevation_detail_octaves: int = 3
@export var elevation_detail_strength: float = 0.5
@export var elevation_smoothing_passes: int = 7

@onready var groundLayer = $GroundLayer
@onready var objectLayer = $ObjectLayer
@onready var elevationLayers: Array[TileMapLayer] = [
	$Elevation1Layer,
	$Elevation2Layer,
	$Elevation3Layer,
	$Elevation4Layer,
	$Elevation5Layer,
]

var temperature = {}
var moisture = {}
var altitude = {}
var biome = {}
var elevation = {}

var fastNoiseLite = FastNoiseLite.new()
var randomNumberGenerator = RandomNumberGenerator.new()

# Center the map around the origin
var origin = Vector2i(-(map_width >> 1), -(map_height >> 1))

# Painting order of terrain
const BIOME_PAINT_ORDER = ["Grass", "Tundra", "Mesa", "Beach"]

# Land biomes and directions for bounding elevation to within the same biome type
const LAND_BIOMES = ["Grass", "Tundra", "Mesa", "Beach"]
const CARDINAL_DIRECTIONS = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var BIOME_DEFINITIONS = {}
var BIOME_OBJECTS = {}
var BIOME_TERRAINS = {}

func initialize_biomes() -> void:
	BIOME_DEFINITIONS = {
		"Grass": {
			"Terrain": 0,
			"Objects": GrassBiome.OBJECTS,
		},
		"Tundra": {
			"Terrain": 1,
			"Objects": TundraBiome.OBJECTS,
		},
		"Mesa": {
			"Terrain": 2,
			"Objects": MesaBiome.OBJECTS,
		},
		"Beach": {
			"Terrain": 3,
			"Objects": BeachBiome.OBJECTS,
		},
		"Ocean": {
			"Terrain": 4,
			"Objects": OceanBiome.OBJECTS,
		},
	}

	BIOME_OBJECTS.clear()
	BIOME_TERRAINS.clear()
	
	for biome_name in BIOME_DEFINITIONS.keys():
		var definition: Dictionary = BIOME_DEFINITIONS[biome_name]
		BIOME_OBJECTS[biome_name] = definition.get("Objects")
		BIOME_TERRAINS[biome_name] = int(definition.get("Terrain"))

func generate_map(period, octave, seed_offset: int = 0):
	# Set the seed and parameters for FastNoiseLite
	fastNoiseLite.seed = world_seed + seed_offset
	fastNoiseLite.frequency = 1.0 / period
	fastNoiseLite.fractal_octaves = octave
	
	var gridName = {}
	for x in range(map_width):
		for y in range(map_height):
			var pos = Vector2i(x, y) + origin

			# Returns the normalized value of the noise at the given coordinate position
			var rand: float = (fastNoiseLite.get_noise_2d(float(pos.x), float(pos.y)) + 1.0) * 0.5

			# Position is the key to gridName (which are the temperature, moisture, altitude dictionaries)
			gridName[pos] = rand
	
	return gridName

# Biome generation which is a function of altitude, temperature, and moisture
func get_biome(alt, temp, moist):
	if alt < 0.3:
		return "Ocean"
	elif alt < 0.35:
		return "Beach"
	elif alt >= 0.7:
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

# Main function to scatter biome objects based on object chances
func scatter_biome_objects() -> void:
	BiomeObjectPlacer.scatter_biome_objects(objectLayer, map_width, map_height, origin, biome, BIOME_OBJECTS, randomNumberGenerator)

# Helper function to check if a given position is within the bounds of the map
func is_inside_map(pos: Vector2i) -> bool:
	return pos.x >= origin.x and pos.x < origin.x + map_width and pos.y >= origin.y and pos.y < origin.y + map_height

# Helper function to checks if a tile is at least _padding_ tiles away from any biome boundary
func is_inside_biome_padding(pos: Vector2i, biome_name: String, padding: int = 3) -> bool:
	if padding <= 0:
		return true

	for dx in range(-padding, padding + 1):
		for dy in range(-padding, padding + 1):
			if absi(dx) + absi(dy) > padding:
				continue

			var neighbor = pos + Vector2i(dx, dy)
			if not is_inside_map(neighbor):
				return false

			if biome.get(neighbor) != biome_name:
				return false

	return true

# Helper function to expand the given biome cells' perimeter by a specified border size; 1 tile by default
func expand_cells_with_border(cells: Array, border_size: int = 1) -> Array:
	var expanded_lookup = {}

	for cell in cells:
		for dx in range(-border_size, border_size + 1):
			for dy in range(-border_size, border_size + 1):
				var expanded_pos = cell + Vector2i(dx, dy)
				if is_inside_map(expanded_pos):
					expanded_lookup[expanded_pos] = true

	return expanded_lookup.keys()

# Natural elevation generation using multi-layer noise approach from: https://www.youtube.com/shorts/rV99G-t8CYk
func generate_elevation_map(biome_cells: Dictionary) -> void:
	elevation.clear()
	var base_noise = generate_map(elevation_base_period, elevation_base_octaves, 1111)
	var detail_noise = generate_map(elevation_detail_period, elevation_detail_octaves, 2222)

	# Combine the base and detail noise layers to create a blended elevation value
	# Turn it into discrete levels 1-5
	for biome_name in LAND_BIOMES:
		var cells: Array = biome_cells.get(biome_name)
		for pos in cells:
			# Padding of 3 tiles to allow for the groundLayer's biome transitions to be shown
			if not is_inside_biome_padding(pos, biome_name, 3):
				continue

			var base_value: float = base_noise.get(pos)
			var detail_value: float = detail_noise.get(pos)
			var blended_value = clamp(base_value + ((detail_value - 0.5) * 2.0 * elevation_detail_strength), 0.0, 1.0)
			var calculated_level = int(round(lerpf(1.0, 5.0, blended_value)))
			elevation[pos] = clampi(calculated_level, 1, 5)

	# Smooth elevation levels by making adjacent tiles within the same biome type have elevation levels that differ by at most 1
	for _pass in range(elevation_smoothing_passes):
		var updates = {}
		var changed = false

		for biome_name in LAND_BIOMES:
			var cells: Array = biome_cells.get(biome_name)
			for pos in cells:
				if not elevation.has(pos):
					continue

				var current_level = int(elevation[pos])
				var next_level = current_level

				for dir in CARDINAL_DIRECTIONS:
					var neighbor = pos + dir
					if biome.get(neighbor) != biome_name or not elevation.has(neighbor):
						continue

					var neighbor_level = int(elevation[neighbor])
					if next_level - neighbor_level > 1:
						next_level = neighbor_level + 1
					elif neighbor_level - next_level > 1:
						next_level = neighbor_level - 1

				next_level = clampi(next_level, 1, 5)
				if next_level != current_level:
					updates[pos] = next_level
					changed = true

		# Add the updates to the elevation after processing everything to not mess up the smoothing process
		for pos in updates.keys():
			elevation[pos] = updates[pos]

		if not changed:
			break

# Paint elevation layers based on the generated elevation map
func paint_elevation_layers(biome_cells: Dictionary) -> void:
	for layer in elevationLayers:
		layer.clear()

	for biome_name in LAND_BIOMES:
		var cells: Array = biome_cells.get(biome_name)
		if cells.is_empty():
			continue

		var terrain = BIOME_TERRAINS.get(biome_name)
		if terrain == -1:
			continue

		for level in range(1, 6):
			var level_cells: Array = []
			for pos in cells:
				# Default value of 0 for tiles w/o elevation
				if elevation.get(pos, 0) >= level:
					level_cells.append(pos)

			if not level_cells.is_empty():
				elevationLayers[level - 1].set_cells_terrain_connect(level_cells, 0, terrain, false)

func set_tile():
	groundLayer.clear()
	for layer in elevationLayers:
		layer.clear()

	biome.clear()
	var biome_cells = {}

	# First - Compute the biome for every tile
	for x in range(map_width):
		for y in range(map_height):
			var pos = Vector2i(x, y) + origin

			var alt = altitude[pos]
			var temp = temperature[pos]
			var moist = moisture[pos]

			var biome_name = get_biome(alt, temp, moist)
			biome[pos] = biome_name

			if not biome_cells.has(biome_name):
				biome_cells[biome_name] = []
			biome_cells[biome_name].append(pos)

	# Second - Paint all biome tiles through terrain connection
	for biome_name in BIOME_PAINT_ORDER:
		var cells: Array = biome_cells.get(biome_name)

		# If there are *NO* cells for this biome; skip
		if cells.is_empty():
			continue

		var terrain = BIOME_TERRAINS.get(biome_name)
		var expanded_cells = expand_cells_with_border(cells, 1)

		groundLayer.set_cells_terrain_connect(expanded_cells, 0, terrain, false)

	generate_elevation_map(biome_cells)
	paint_elevation_layers(biome_cells)

# Helper function to better visualize the procedurally generated world when pressing space bar/enter
func _input(event):
	if event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if world_seed == 0:
		randomize()
		world_seed = randi()

	# Ensure consistent tile variant selection based on world_seed
	randomNumberGenerator.seed = world_seed
	initialize_biomes()

	temperature = generate_map(temperature_period, temperature_octaves)
	moisture = generate_map(moisture_period, moisture_octaves)
	altitude = generate_map(altitude_period, altitude_octaves)
	
	set_tile()

	# TODO: Improve object sprites and potentially implement a more robust system for object placement that can handle larger objects and more complex rules 
	# (e.g., proximity to other objects, specific biome requirements, etc.)
	# scatter_biome_objects()
