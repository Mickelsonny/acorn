class_name DetailHandler
extends PlaceHandler

const GRASS_METADATA := {
	"tall_grass": [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), 
		Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0), 
		Vector2i(6, 0), Vector2i(7, 0),
	],
	"grass_patch": [
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
	],
	"flower": [
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), 
		Vector2i(3, 2),
	],
	"growing_plant_light": [
		Vector2i(0, 3), Vector2i(1, 3), Vector2i(2, 3),
		Vector2i(3, 3), Vector2i(4, 3), Vector2i(5, 3),
	],
	"growing_plant_dull": [
		Vector2i(0, 4), Vector2i(1, 4), Vector2i(2, 4),
		Vector2i(3, 4), Vector2i(4, 4), Vector2i(5, 4),
	],
}

const GRASS_DETAIL_WEIGHTS := {
	"tall_grass": 45,
	"grass_patch": 30,
	"flower": 15,
	"growing_plant_light": 5,
	"growing_plant_dull": 5,
}

static func _pick_weighted_detail(RNG: RandomNumberGenerator) -> String:
	var total_weight: int = 0
	for weight in GRASS_DETAIL_WEIGHTS.values():
		total_weight += weight

	var roll: int = RNG.randi_range(0, total_weight - 1)
	var cumulative: int = 0
	for detail_type in GRASS_DETAIL_WEIGHTS:
		cumulative += GRASS_DETAIL_WEIGHTS[detail_type]
		if roll < cumulative:
			return detail_type

	# Random fallback type
	return GRASS_DETAIL_WEIGHTS.keys()[randi() % GRASS_DETAIL_WEIGHTS.size()]

static func get_detail_count(cells: Array) -> int:
	# Base the number of details on the number of cells in the biome
	var rolls: int = 5
	var sum: float = 0
	for i in rolls:
		sum += randi() % int(cells.size() / 3.0)
		
	return int(sum / rolls) + 1

static func place_details(main_scene: Node2D, biome_cells: Dictionary, decor_layer: TileMapLayer, biome_name: String, input_seed: int) -> void:
	var cells: Array = biome_cells.get(biome_name)

	var detail_count: int = get_detail_count(cells)

	var RNG: RandomNumberGenerator = RandomNumberGenerator.new()
	RNG.seed = input_seed + biome_name.hash() # Very odd but it ensures different detail placements for each biome while being deterministic

	for i in range(detail_count):
		var cell: Vector2i = cells[randi() % cells.size()]
		var detail_type: String = _pick_weighted_detail(RNG)

		var check_position: Vector2 = decor_layer.to_global(decor_layer.map_to_local(cell))
		var collision_detected: bool = detect_collision_in_radius(main_scene, 4, check_position, ["elevation"]) # 4 px since it's a 16 x 16 sprite
		
		if !collision_detected:
			var variants_for_type: Array = GRASS_METADATA[detail_type]
			var atlas_coord: Vector2i = variants_for_type[RNG.randi_range(0, variants_for_type.size() - 1)]

			decor_layer.set_cell(cell, 0, atlas_coord)
