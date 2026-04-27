class_name TreeHandler
extends RefCounted

# Function to pick one object by chance in the range [0, 100)
static func pick_object_by_chance(biome_name: String, biome_objects: Dictionary, random_number_generator: RandomNumberGenerator) -> Dictionary:
	var objects = biome_objects.get(biome_name)
	if objects.is_empty():
		return {}

	var roll = random_number_generator.randf_range(0.0, 100.0)
	var running = 0.0
	for object in objects:
		running += float(object.get("Chance"))
		if roll < running:
			return object

	# Fallback
	return {}

# Helper function to check if an object can be placed at the given position based on its size and the respective biome
# Note: Anchor tile is bottom left for multi-tile objects
static func can_place_object(anchor_pos: Vector2i, biome_name: String, size: Vector2i, occupied: Dictionary, biome_map: Dictionary) -> bool:
	# Require the target biome for the full area plus a 1-tile border on all sides
	for dx in range(-1, size.x + 1):
		for dy in range(-size.y, 2):
			var check_pos = anchor_pos + Vector2i(dx, dy)
			if biome_map.get(check_pos) != biome_name:
				return false

	# But keep overlap prevention limited to the actual tile area
	for dx in range(size.x):
		for dy in range(size.y):
			var check_pos = anchor_pos + Vector2i(dx, -dy)
			if occupied.has(check_pos):
				return false

	return true

# Helper function to place the object on the ObjectLayer and mark its occupied tiles
static func place_object(objectLayer: TileMapLayer, anchor_pos: Vector2i, object: Dictionary, occupied: Dictionary) -> void:
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
static func scatter_biome_objects(objectLayer: TileMapLayer, map_width: int, map_height: int, origin: Vector2i, biome_map: Dictionary, biome_objects: Dictionary, random_number_generator: RandomNumberGenerator) -> void:
	objectLayer.clear()
	var occupied = {}

	for x in range(map_width):
		for y in range(map_height):
			var pos = Vector2i(x, y) + origin
			if occupied.has(pos):
				continue

			var biome_name = biome_map.get(pos)
			var objects = biome_objects.get(biome_name)
			if objects.is_empty():
				continue

			var object = pick_object_by_chance(biome_name, biome_objects, random_number_generator)
			if object.is_empty():
				continue

			var size: Vector2i = object.get("Size")
			if can_place_object(pos, biome_name, size, occupied, biome_map):
				place_object(objectLayer, pos, object, occupied)
