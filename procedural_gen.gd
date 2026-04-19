extends Node2D

const BeachBiome = preload("res://biomes/beach_biome.gd")
const GrassBiome = preload("res://biomes/grass_biome.gd")
const TundraBiome = preload("res://biomes/tundra_biome.gd")
const MesaBiome = preload("res://biomes/mesa_biome.gd")
const OceanBiome = preload("res://biomes/ocean_biome.gd")
const BiomeObjectPlacer = preload("res://object_placement.gd")

# TileMapLayer nodes
@onready var underwaterLayers: Array[TileMapLayer] = [
	$Underwater1Layer,
	$Underwater2Layer,
	$Underwater3Layer
]
@onready var oceanLayer = $OceanLayer
@onready var groundLayer = $GroundLayer
@onready var elevationLayers: Array[TileMapLayer] = [
	$Elevation1Layer,
	$Elevation2Layer,
	$Elevation3Layer,
	$Elevation4Layer,
	$Elevation5Layer
]
@onready var objectLayer = $ObjectLayer

# Bounding map & world variables
@export var map_width = 100
@export var map_height = 100
@export var world_seed = 0

# TODO: Find better values for larger sized maps
# Arbitrary values to input into noise generator
# Biome generation
var temperature_period: float = 150.0
var moisture_period: float = 150.0
var altitude_period: float = 120.0
var temperature_octaves: int = 6
var moisture_octaves: int = 6
var altitude_octaves: int = 8

# Elevation generation
var elevation_base_period: float = 120.0
var elevation_detail_period: float = 60.0
var elevation_base_octaves: int = 6
var elevation_detail_octaves: int = 8
var elevation_detail_strength: float = 0.5
var elevation_smoothing_passes: int = 4

var temperature = {}
var moisture = {}
var altitude = {}
var biome = {}
var elevation = {}

var fastNoiseLite = FastNoiseLite.new()
var randomNumberGenerator = RandomNumberGenerator.new()

var map_origin = Vector2i(-(map_width >> 1), -(map_height >> 1))

var BIOME_DEFINITIONS = {}
var BIOME_OBJECTS = {}
var BIOME_TERRAINS = {}

# Self-defined land biomes + directions for bounding elevation layers
const LAND_BIOMES = ["Grass", "Tundra", "Mesa", "Beach"]
const CARDINAL_DIRECTIONS = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

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

			# TODO: Get rid of this eventually, doesn't work since this is just the beach/ocean transition terrain
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
			var pos = Vector2i(x, y) + map_origin

			# Returns the normalized value of the noise at the given coordinate position
			var rand: float = (fastNoiseLite.get_noise_2d(float(pos.x), float(pos.y)) + 1.0) * 0.5

			# Position is the key to gridName (which are the temperature, moisture, altitude dictionaries)
			gridName[pos] = rand
	
	return gridName

# TODO: Improve ranges to be more fitting (and hopefully get rid of certain autotiling errors because of grass prioritization across 3+ biomes)
# Biome generation which is a function of altitude, temperature, and moisture
func get_biome(alt, temp, moist):
	if alt < 0.325:
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

# Helper function to check if a given position is within the bounds of the map
func is_inside_map(pos: Vector2i) -> bool:
	return pos.x >= map_origin.x and pos.x < map_origin.x + map_width and pos.y >= map_origin.y and pos.y < map_origin.y + map_height

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

# Helper function to checks if a tile is at least _padding_ tiles away from the edge of a painted layer
func is_inside_layer_padding(pos: Vector2i, layer_lookup: Dictionary, padding: int = 2) -> bool:
	if padding <= 0:
		return true

	for dir in CARDINAL_DIRECTIONS:
		for step in range(1, padding + 1):
			var neighbor = pos + (dir * step)
			if not is_inside_map(neighbor):
				return false

			if not layer_lookup.has(neighbor):
				return false

	return true

# Helper function to expand/shrink the given biome cells' perimeter by a specified border size; +1 tile by default
func expand_cells_with_border(cells: Array, border_size: int = 1) -> Array:
	# Shrinkage
	if border_size < 0:
		var cell_lookup = {}

		for cell in cells:
			cell_lookup[cell] = true

		var shrunk_lookup = {}
		var radius = absi(border_size)

		for cell in cells:
			var is_valid = true
			for dx in range(-radius, radius + 1):
				for dy in range(-radius, radius + 1):
					var neighbor = cell + Vector2i(dx, dy)
					if not cell_lookup.has(neighbor):
						is_valid = false
						break
				if not is_valid:
					break

			if is_valid:
				shrunk_lookup[cell] = true

		return shrunk_lookup.keys()

	# Expansion
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
			# Padding of THREE tiles to allow for the groundLayer's biome transitions to be shown
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
	for biome_name in LAND_BIOMES:
		var cells: Array = biome_cells.get(biome_name)
		if cells.is_empty():
			continue

		var terrain = BIOME_TERRAINS.get(biome_name)
		if terrain == -1:
			continue

		var previous_layer_lookup = {}

		for level in range(1, 6):
			var level_cells: Array = []
			for pos in cells:
				# Default value of 0 for tiles w/o elevation
				if elevation.get(pos, 0) < level:
					continue

				# Each higher layer is inset from the layer below by TWO tiles
				if level > 1 and not is_inside_layer_padding(pos, previous_layer_lookup, 2):
					continue

				level_cells.append(pos)

			if not level_cells.is_empty():
				elevationLayers[level - 1].set_cells_terrain_connect(level_cells, 0, terrain, false)

			previous_layer_lookup.clear()
			for pos in level_cells:
				previous_layer_lookup[pos] = true

# Function to compute the biome for every tile
func compute_biome_cells() -> Dictionary:
	biome.clear()
	var biome_cells = {}

	for x in range(map_width):
		for y in range(map_height):
			var pos = Vector2i(x, y) + map_origin

			var alt = altitude[pos]
			var temp = temperature[pos]
			var moist = moisture[pos]

			var biome_name = get_biome(alt, temp, moist)
			biome[pos] = biome_name

			if not biome_cells.has(biome_name):
				biome_cells[biome_name] = []
			biome_cells[biome_name].append(pos)

	return biome_cells

# Function to paint underwater tiles on underwaterLayers | 3 total layers to create a divot
func paint_underwater_tiles(biome_cells: Dictionary) -> void:
	var ocean_cells: Array = biome_cells.get("Ocean")
	var underwater1Layer = underwaterLayers[0]
	var underwater2Layer = underwaterLayers[1]
	var underwater3Layer = underwaterLayers[2]

	# Underwater3Layer
	var layer3_cells: Array = ocean_cells
	underwater3Layer.set_cells_terrain_connect(layer3_cells, 0, 0, false)
	underwater3Layer.set_cells_terrain_connect(expand_cells_with_border(ocean_cells, -2), 0, -1, false)

	# Underwater2Layer
	var layer2_cells: Array = expand_cells_with_border(ocean_cells, -1)
	underwater2Layer.set_cells_terrain_connect(layer2_cells, 0, 0, false)
	underwater2Layer.set_cells_terrain_connect(expand_cells_with_border(ocean_cells, -4), 0, -1, false)

	# Underwater1Layer
	var layer1_cells: Array = expand_cells_with_border(ocean_cells, -3)
	underwater1Layer.set_cells_terrain_connect(layer1_cells, 0, 0, false)

# Function to paint "real" ocean tiles on oceanLayer
func paint_ocean_tiles(biome_cells: Dictionary) -> void:
	var ocean_cells: Array = biome_cells.get("Ocean")

	for pos in ocean_cells:
		oceanLayer.set_cell(pos, 0, Vector2i(0, 0))

# Function to paint the terrain of all biomes on groundLayer using autotiling for terrain connection
func paint_normal_tiles(biome_cells: Dictionary) -> void:
	# Paint "ghost" ocean tiles on groundLayer to properly autotile the beach/ocean transition
	var ocean_cells: Array = biome_cells.get("Ocean")
	var ocean_terrain = BIOME_TERRAINS.get("Ocean")
	groundLayer.set_cells_terrain_connect(ocean_cells, 0, ocean_terrain, false)

	# Specific painting order to avoid grass prioritization
	const BIOME_PAINT_ORDER = ["Grass", "Tundra", "Mesa", "Beach", "Ocean"]

	# Paint the rest of the biomes' terrain normally on groundLayer
	for biome_name in BIOME_PAINT_ORDER:
		if biome_name == "Ocean":
			# Handled later on oceanLayer
			continue

		var cells: Array = biome_cells.get(biome_name)

		# If there are *NO* cells for this biome; skip
		if cells.is_empty():
			continue

		var terrain = BIOME_TERRAINS.get(biome_name)
		var expanded_cells = expand_cells_with_border(cells, 1)

		groundLayer.set_cells_terrain_connect(expanded_cells, 0, terrain, false)

	# Erase the "ghost" ocean tiles; shrunk by 1 tile to not destroy the beach/ocean transition tiles
	for pos in expand_cells_with_border(ocean_cells, -1):
		groundLayer.erase_cell(pos)

# Function to generate and paint the elevation layers that are above groundLayer
func paint_elevation_tiles(biome_cells: Dictionary) -> void:
	generate_elevation_map(biome_cells)
	paint_elevation_layers(biome_cells)

func set_tile():
	for layer in underwaterLayers:
		layer.clear()
	oceanLayer.clear()
	groundLayer.clear()
	for layer in elevationLayers:
		layer.clear()

	var biome_cells = compute_biome_cells()

	paint_underwater_tiles(biome_cells)
	paint_ocean_tiles(biome_cells)
	paint_normal_tiles(biome_cells)
	paint_elevation_tiles(biome_cells)

func scatter_biome_objects() -> void:
	BiomeObjectPlacer.scatter_biome_objects(objectLayer, map_width, map_height, map_origin, biome, BIOME_OBJECTS, randomNumberGenerator)

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
	
	# set_tile()

	# TODO: Improve object sprites and potentially implement a more robust system for object placement that can handle larger objects and more complex rules 
	# (e.g., proximity to other objects, specific biome requirements, etc.)
	# scatter_biome_objects()
