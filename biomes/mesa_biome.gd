extends RefCounted

const TILE_VARIANTS = [
    # Plain Mesa
	{"Atlas_Origin": Vector2i(0, 6), "Weight": 90},

    # Seeded Mesa
	{"Atlas_Origin": Vector2i(3, 6), "Weight": 10},
]

const OBJECTS = [
    # Mini-Cactus
	{"Atlas_Origin": Vector2i(11, 6), "Size": Vector2i(1, 1), "Chance": 3.0},

    # Flower
	{"Atlas_Origin": Vector2i(11, 7), "Size": Vector2i(1, 1), "Chance": 3.0},

    # Tall Rocks 1x2
	{"Atlas_Origin": Vector2i(12, 6), "Size": Vector2i(1, 2), "Chance": 5.0},

    # Desert Bush 2x2
	{"Atlas_Origin": Vector2i(13, 6), "Size": Vector2i(2, 2), "Chance": 5.0},

    # Copper Ore
	{"Atlas_Origin": Vector2i(15, 6), "Size": Vector2i(1, 1), "Chance": 1.0},

    # Coal Ore
	{"Atlas_Origin": Vector2i(15, 7), "Size": Vector2i(1, 1), "Chance": 1.0},

    # Cactus 3x3
	{"Atlas_Origin": Vector2i(16, 6), "Size": Vector2i(3, 3), "Chance": 2.5},
]
