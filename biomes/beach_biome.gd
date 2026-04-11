extends RefCounted

const TILE_VARIANTS = [
    # Plain Sand
	{"Atlas_Origin": Vector2i(0, 9), "Weight": 95},

    # Seeded Sand
	{"Atlas_Origin": Vector2i(0, 10), "Weight": 5},
]

const OBJECTS = [
    # Cut Log
	{"Atlas_Origin": Vector2i(11, 9), "Size": Vector2i(1, 1), "Chance": 3.0},

    # Flower
	{"Atlas_Origin": Vector2i(11, 10), "Size": Vector2i(1, 1), "Chance": 3.0},

    # Starfish
	{"Atlas_Origin": Vector2i(12, 9), "Size": Vector2i(1, 1), "Chance": 0.5},

    # Three Seashells
	{"Atlas_Origin": Vector2i(12, 10), "Size": Vector2i(1, 1), "Chance": 0.5},

    # Bush 2x2
	{"Atlas_Origin": Vector2i(13, 9), "Size": Vector2i(2, 2), "Chance": 5.0},

    # Dead Fish
	{"Atlas_Origin": Vector2i(15, 9), "Size": Vector2i(1, 1), "Chance": 0.5},

    # One Seashell
	{"Atlas_Origin": Vector2i(15, 10), "Size": Vector2i(1, 1), "Chance": 0.5},

    # Fossil 3x3
	{"Atlas_Origin": Vector2i(16, 9), "Size": Vector2i(3, 3), "Chance": 2.5},
]

# Directions to check when relating beach tiles to ocean tiles
# Follow priority order so strings are joined properly
const BEACH_CARDINAL_DIRECTIONS = [
	["Up", Vector2i(0, -1)], # 1
	["Down", Vector2i(0, 1)], # 2
	["Left", Vector2i(-1, 0)], # 3
	["Right", Vector2i(1, 0)], # 4
]

const BEACH_DIAGONAL_DIRECTIONS = [
	["UpLeft", Vector2i(-1, -1)], # 1
	["UpRight", Vector2i(1, -1)], # 2
	["DownLeft", Vector2i(-1, 1)], # 3
	["DownRight", Vector2i(1, 1)], # 4
]

# Beach textures for ocean cardinal edges
const BEACH_EDGE_TEXTURES = {
	"Up": Vector2i(7, 9),
	"Down": Vector2i(7, 11),
	"Left": Vector2i(6, 10),
	"Right": Vector2i(8, 10),
	"Up,Left": Vector2i(6, 9),
	"Up,Right": Vector2i(8, 9),
	"Down,Left": Vector2i(6, 11),
	"Down,Right": Vector2i(8, 11),

	# Multi-tile edge cases (2x1 and 1x2 textures)
	"Up,Left,Right": Vector2i(3, 9),
	"Down,Left,Right": Vector2i(3, 14),
	"Up,Down,Left": Vector2i(6, 13),
	"Up,Down,Right": Vector2i(11, 13),
	"Left,Right": Vector2i(3, 10),
	"Up,Down": Vector2i(10, 13),
}

# Beach textures for diagonals when there are *NO* ocean cardinal edges
const BEACH_DIAGONAL_TEXTURES = {
	"UpLeft": Vector2i(10, 10),
	"UpRight": Vector2i(9, 10),
	"DownLeft": Vector2i(10, 9),
	"DownRight": Vector2i(9, 9),

	# Single-tile edge cases (1x1 textures)
	"UpLeft,DownRight": Vector2i(10, 11),
	"UpRight,DownLeft": Vector2i(9, 11),

	# Multi-tile edge cases (2x1 and 1x2 textures)
	"UpLeft,UpRight": Vector2i(3, 11),
	"DownLeft,DownRight": Vector2i(3, 13),
	"UpLeft,DownLeft": Vector2i(7, 13),
	"UpRight,DownRight": Vector2i(9, 13),
}

# Helper function that returns a string containing the neighboring ocean tiles for a given position
# Takes in both cardinal and diagonal directions
static func get_neighbor_pattern(pos: Vector2i, directions: Array, biome_map: Dictionary) -> String:
	var neighbors = []

	for direction in directions:
		var dir_name: String = direction[0]
		var offset: Vector2i = direction[1]
		var check_pos = pos + offset
		if biome_map.get(check_pos) == "Ocean":
			neighbors.append(dir_name)

	if neighbors.is_empty():
		return "None"
	return ",".join(neighbors)

# Helper function to get the cardinal neighboring ocean tiles
static func get_beach_neighbors(pos: Vector2i, biome_map: Dictionary) -> String:
	return get_neighbor_pattern(pos, BEACH_CARDINAL_DIRECTIONS, biome_map)

# Helper function to get the diagonal neighboring ocean tiles
static func get_beach_diagonal_neighbors(pos: Vector2i, biome_map: Dictionary) -> String:
	return get_neighbor_pattern(pos, BEACH_DIAGONAL_DIRECTIONS, biome_map)

# Main function to pick the proper texture for a beach biome tile based on its neighboring ocean tiles
static func pick_tile(pos: Vector2i, biome_map: Dictionary, pick_weighted_tile: Callable) -> Vector2i:
	var cardinal_pattern = get_beach_neighbors(pos, biome_map)
	if cardinal_pattern != "None" and BEACH_EDGE_TEXTURES.has(cardinal_pattern):
		return BEACH_EDGE_TEXTURES[cardinal_pattern]

	# Only check diagonals when no cardinal direction touches ocean
	if cardinal_pattern == "None":
		var diagonal_pattern = get_beach_diagonal_neighbors(pos, biome_map)
		if diagonal_pattern != "None" and BEACH_DIAGONAL_TEXTURES.has(diagonal_pattern):
			return BEACH_DIAGONAL_TEXTURES[diagonal_pattern]

	# Final fallback to random beach variant
	return pick_weighted_tile.call("Beach")
