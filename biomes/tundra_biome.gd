extends RefCounted

const TILE_VARIANTS = [
    # Plain Snow
	{"Atlas_Origin": Vector2i(0, 3), "Weight": 90},

    # Seeded Snow
	{"Atlas_Origin": Vector2i(3, 3), "Weight": 10},
]

const OBJECTS = [
    # Shrub
	{"Atlas_Origin": Vector2i(11, 3), "Size": Vector2i(1, 1), "Chance": 3.0},

    # Flower
	{"Atlas_Origin": Vector2i(11, 4), "Size": Vector2i(1, 1), "Chance": 3.0},

    # Scattered Rocks
	{"Atlas_Origin": Vector2i(12, 3), "Size": Vector2i(1, 1), "Chance": 1.0},

    # Snow Bush
	{"Atlas_Origin": Vector2i(12, 4), "Size": Vector2i(1, 1), "Chance": 1.0},

    # Tree 2x2
	{"Atlas_Origin": Vector2i(13, 3), "Size": Vector2i(2, 2), "Chance": 5.0},

    # Berries
	{"Atlas_Origin": Vector2i(15, 3), "Size": Vector2i(1, 1), "Chance": 1.0},

    # Acorns
	{"Atlas_Origin": Vector2i(15, 4), "Size": Vector2i(1, 1), "Chance": 1.0},

    # Pine Tree 3x3
	{"Atlas_Origin": Vector2i(16, 3), "Size": Vector2i(3, 3), "Chance": 10.0},
]
