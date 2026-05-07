extends Node2D

const TreeHandlerScript = preload("res://decor/scripts/tree_handler.gd")
const DetailHandlerScript = preload("res://decor/scripts/detail_handler.gd")

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
@onready var decorLayer = $DecorLayer

# Bounding map & world variables
@export var map_width: int = 125
@export var map_height: int = 125
@export var map_origin: Vector2i = Vector2i(-(map_width >> 1), -(map_height >> 1))
@export var world_seed: int

# Arbitrary values to input into noise generator
var fastNoiseLite = FastNoiseLite.new()

# Biome generation
var temperature_period: float = 200.0
var moisture_period: float = 200.0
var altitude_period: float = 100.0
var temperature_octaves: int = 3
var moisture_octaves: int = 3
var altitude_octaves: int = 3

# Elevation generation
var elevation_base_period: float = 50.0
var elevation_detail_period: float = 20.0
var elevation_base_octaves: int = 10
var elevation_detail_octaves: int = 10

var temperature = {}
var moisture = {}
var altitude = {}
var biome = {}
var elevation = {}

var biome_cells = {}
const BIOME_TERRAINS := { # Terrain IDs
	"Grass": 0,
	"Tundra": 1,
	"Mesa": 2,
	"Beach": 3,
	"Ocean": 4,
}
const BIOME_MAX_ELEVATION := { # Grass = Hilly, Tundra = Mountainous, Mesa = Rocky, Beach = Flat
	"Grass": 3,
	"Tundra": 5,
	"Mesa": 4,
	"Beach": 2,
}
const BIOME_INSET_PER_LAYER := {
	"Grass": 3,
	"Tundra": 1,
	"Mesa": 2,
	"Beach": 1, # >^•⩊•^<
}

func generate_map(period, octave, seed_offset: int = 0) -> Dictionary:
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

func get_maps() -> void:
	temperature = generate_map(temperature_period, temperature_octaves, 1111)
	moisture = generate_map(moisture_period, moisture_octaves, 2222)
	altitude = generate_map(altitude_period, altitude_octaves, 3333)

# Biome generation which is a function of altitude, temperature, and moisture
func get_biome(alt, temp, moist):
	if alt < 0.275:
		return "Ocean"
	elif alt < 0.3:
		return "Beach"
	elif alt >= 0.65:
		return "Tundra"

	if moist < 0.4:
		if temp <= 0.5:
			return "Grass"
		return "Mesa"
	elif moist < 0.9:
		if temp <= 0.7:
			return "Grass"
		return "Mesa"
	else:
		return "Grass"

# Helper function to check if a given position is within the bounds of the map
func is_inside_map(pos: Vector2i) -> bool:
	if pos.x >= map_origin.x and pos.x < map_origin.x + map_width:
		if pos.y >= map_origin.y and pos.y < map_origin.y + map_height:
			return true
	return false

# Helper function to check if a tile is at least _padding_ tiles away from any biome boundary
func is_inside_biome_padding(pos: Vector2i, biome_name: String, padding: int) -> bool:
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

# Helper function to check if a tile is at least _padding_ tiles away from the edge of a painted layer
func is_inside_layer_padding(pos: Vector2i, layer_lookup: Dictionary, padding: int) -> bool:
	if padding <= 0:
		return true

	for dir in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		for step in range(1, padding + 1):
			var neighbor = pos + (dir * step)
			if not is_inside_map(neighbor):
				return false

			if not layer_lookup.has(neighbor):
				return false

	return true

# Helper function to shrink/expand the given biome cells' perimeter by a specified border size; +1 tile by default
func resize_cells_with_border(cells: Array, border_size: int = 1) -> Array:
	# Shrink logic
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

	# Expand logic
	var expanded_lookup = {}

	for cell in cells:
		for dx in range(-border_size, border_size + 1):
			for dy in range(-border_size, border_size + 1):
				var expanded_pos = cell + Vector2i(dx, dy)
				if is_inside_map(expanded_pos):
					expanded_lookup[expanded_pos] = true

	return expanded_lookup.keys()

# Natural elevation generation using multi-layer noise approach from: https://www.youtube.com/shorts/rV99G-t8CYk
func generate_elevation_map() -> void:
	var base_noise = generate_map(elevation_base_period, elevation_base_octaves, 4444)
	var detail_noise = generate_map(elevation_detail_period, elevation_detail_octaves, 5555)

	# Combine the base and detail noise layers to create a mixed elevation value
	# Turn it into discrete levels 1-5
	for biome_name in ["Grass", "Tundra", "Mesa", "Beach"]:
		var cells: Array = biome_cells.get(biome_name)
		for pos in cells:
			# Padding of 1 tile to allow for the groundLayer's biome transitions to be shown
			if not is_inside_biome_padding(pos, biome_name, 1):
				continue

			var base_value: float = base_noise.get(pos)
			var detail_value: float = detail_noise.get(pos)
			var mixed_value = clamp(base_value * 0.55 + detail_value - 0.45, 0.0, 1.0)
			var calculated_level = int(round(lerpf(1.0, 5.0, mixed_value)))

			# Cap the elevation level depending on the biome
			var max_level = BIOME_MAX_ELEVATION.get(biome_name)
			elevation[pos] = clampi(calculated_level, 1, max_level)

# Paint elevation layers based on the generated elevation map
func paint_elevation_layers() -> void:
	for biome_name in ["Grass", "Tundra", "Mesa", "Beach"]:
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
				# Default value of 0 for tiles without elevation
				if elevation.get(pos, 0) < level:
					continue

				# Each higher layer is inset from the layer below
				if level > 1 and not is_inside_layer_padding(pos, previous_layer_lookup, BIOME_INSET_PER_LAYER[biome_name]):
					continue

				level_cells.append(pos)

			if not level_cells.is_empty():
				elevationLayers[level - 1].set_cells_terrain_connect(level_cells, 0, terrain, false)

			previous_layer_lookup.clear()
			for pos in level_cells:
				previous_layer_lookup[pos] = true

# Function to compute the biome for every tile
func compute_biome_cells() -> Dictionary:
	var calculated_biome_cells = {}

	for x in range(map_width):
		for y in range(map_height):
			var pos = Vector2i(x, y) + map_origin

			var alt = altitude[pos]
			var temp = temperature[pos]
			var moist = moisture[pos]

			var biome_name = get_biome(alt, temp, moist)
			biome[pos] = biome_name

			if not calculated_biome_cells.has(biome_name):
				calculated_biome_cells[biome_name] = []
			calculated_biome_cells[biome_name].append(pos)

	return calculated_biome_cells

# Function to paint underwater beach cliff tiles; 3 total TileMapLayers to create a concave divot
func paint_underwater_tiles() -> void:
	var ocean_cells: Array = biome_cells.get("Ocean")
	var underwater1Layer = underwaterLayers[0]
	var underwater2Layer = underwaterLayers[1]
	var underwater3Layer = underwaterLayers[2]

	# Underwater3Layer
	var layer3_cells: Array = ocean_cells
	underwater3Layer.set_cells_terrain_connect(layer3_cells, 0, 0, false)
	underwater3Layer.set_cells_terrain_connect(resize_cells_with_border(ocean_cells, -2), 0, -1, false)

	# Underwater2Layer
	var layer2_cells: Array = resize_cells_with_border(ocean_cells, -1)
	underwater2Layer.set_cells_terrain_connect(layer2_cells, 0, 0, false)
	underwater2Layer.set_cells_terrain_connect(resize_cells_with_border(ocean_cells, -4), 0, -1, false)

	# Underwater1Layer
	var layer1_cells: Array = resize_cells_with_border(ocean_cells, -3)
	underwater1Layer.set_cells_terrain_connect(layer1_cells, 0, 0, false)

# Function to paint "real" ocean tiles on oceanLayer
func paint_ocean_tiles() -> void:
	var ocean_cells: Array = biome_cells.get("Ocean")

	# No autotiling
	for pos in ocean_cells:
		oceanLayer.set_cell(pos, 0, Vector2i(0, 0))

# Function to paint the terrain of land biomes on groundLayer
func paint_land_tiles() -> void:
	# Paint "ghost" ocean tiles on groundLayer to properly autotile the beach/ocean transition
	var ocean_cells: Array = biome_cells.get("Ocean")
	var ocean_terrain = BIOME_TERRAINS.get("Ocean")
	groundLayer.set_cells_terrain_connect(ocean_cells, 0, ocean_terrain, false)

	# Specific painting order to avoid grass prioritization?
	const BIOME_PAINT_ORDER = ["Grass", "Tundra", "Mesa", "Beach", "Ocean"]

	# Paint the rest of the biomes' terrain normally
	for biome_name in BIOME_PAINT_ORDER:
		if biome_name == "Ocean":
			# Handled later on oceanLayer
			continue

		var cells: Array = biome_cells.get(biome_name)

		# If there are *NO* cells for this biome; skip
		if cells.is_empty():
			continue

		var terrain = BIOME_TERRAINS.get(biome_name)
		var expanded_cells = resize_cells_with_border(cells, 1)

		groundLayer.set_cells_terrain_connect(expanded_cells, 0, terrain, false)

	# Erase the "ghost" ocean tiles; shrunk by 1 tile to not destroy the beach/ocean transition tiles
	for pos in resize_cells_with_border(ocean_cells, -1):
		groundLayer.erase_cell(pos)

# Function to generate and paint the elevation layers
func paint_elevation_tiles() -> void:
	generate_elevation_map()
	paint_elevation_layers()

func set_tiles() -> void:
	biome_cells = compute_biome_cells()

	paint_underwater_tiles()
	paint_ocean_tiles()
	paint_land_tiles()
	paint_elevation_tiles()

func set_seed() -> void:
	randomize()
	world_seed = randi()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_seed()

	get_maps()
	
	set_tiles()
	
	# Register collisions before calling detail/tree placement
	await get_tree().create_timer(1.0).timeout
	
	DetailHandlerScript.place_details(self, biome_cells, decorLayer, "Grass", 7777)

	TreeHandlerScript.place_trees(self, biome_cells)
