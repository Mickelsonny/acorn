extends RefCounted

# Weighted tile variants
const TILE_VARIANTS = [
	# Plain Grass
	{"Atlas_Origin": Vector2i(0, 0), "Weight": 90},

	# Seeded Grass
	{"Atlas_Origin": Vector2i(3, 0), "Weight": 10},
]

# "Atlas_Origin" refers to the tile unit position of the object in the tileset
# "Size" refers to width x height in tile units
# "Chance" is the per-tile % chance for each object to be selected for *POTENTIAL* placement 
# (depends on occupancy, available biome space, etc.)
const OBJECTS = [
	# Shrub
	{"Atlas_Origin": Vector2i(11, 0), "Size": Vector2i(1, 1), "Chance": 3.0},

	# Flower
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
]
