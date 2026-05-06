class_name TreeHandler
extends RefCounted

const TREE_SHADOW_SPRITE = preload("res://assets/objects/tree_shadow.png")

static var TREE_METADATA := {
	"Grass": {
		"fruit_trees": ["apple", "lemon", "orange", "peach"],
		"regular_trees": {
			"birch_brown": ["small", "medium", "big", "huge"],
			"birch_green": ["small", "medium", "big", "huge"],
			"birch_yellow": ["small", "medium", "big", "huge"],
			"oak_blue_green": ["small", "medium", "big", "huge"],
			"oak_brown": ["small", "medium", "big", "huge"],
			"oak_green": ["small", "medium", "big", "huge"],
		}
	},
	"Tundra": {
		"regular_trees": {
			"pine_blue_green": ["small", "medium", "big", "huge"],
			"pine_blue": ["small", "medium", "big", "huge"],
			"pine_green": ["small", "medium", "big", "huge"],
			"pine_dark_green": ["small", "medium", "big", "huge"],
		}
	},
	"Beach": {
		"fruit_trees": ["banana"],
	}
}

static var biome_trees: Dictionary = _create_tree_dictionary()

static func _create_tree_dictionary() -> Dictionary:
	var final_dict := {}
	for biome: String in TREE_METADATA:
		var scenes := []
		var biome_data: Dictionary = TREE_METADATA[biome]
		
		# Load fruit trees (treat fruit trees as medium size)
		if "fruit_trees" in biome_data:
			for tree_name: String in biome_data["fruit_trees"]:
				var path = "res://tree/scenes/fruit_trees/%s/%s_tree.tscn" % [biome.to_lower(), tree_name]
				scenes.append({"scene": load(path), "size": "medium"})
		
		# Load regular trees
		if "regular_trees" in biome_data:
			for tree_type: String in biome_data["regular_trees"]:
				for size: String in biome_data["regular_trees"][tree_type]:
					var path = "res://tree/scenes/regular_trees/%s/%s_%s_tree.tscn" % [biome.to_lower(), tree_type, size]
					scenes.append({"scene": load(path), "size": size})
		
		final_dict[biome] = scenes
	
	return final_dict

static func get_random_tree(biome_name: String) -> Dictionary:
	# Returns a dictionary with keys: "scene" (PackedScene) and "size" (String)
	if biome_name in biome_trees:
		var trees: Array = biome_trees[biome_name]
		if trees.size() > 0:
			return trees[randi() % trees.size()]
	return {}

# https://joeridamme.hashnode.dev/godot-4-detect-body-collision-before-adding-node-to-scene-part-2
static func detect_collision_in_radius(main_scene: Node2D, radius: int, pos: Vector2) -> bool:
	# Get the 2D physics space state
	var space_state = main_scene.get_world_2d().direct_space_state
	
	# Create a CircleShape2D and set its radius
	var shape = CircleShape2D.new()
	shape.radius = radius
	
	# Create PhysicsShapeQueryParameters2D and set its shape and transform
	var shape_query_params = PhysicsShapeQueryParameters2D.new()
	shape_query_params.shape = shape
	shape_query_params.transform.origin = pos
	
	# Perform a shape intersection query in the physics space
	var results = space_state.intersect_shape(shape_query_params)
	
	# Check if there are any objects in the results
	return results.size() > 0

static func get_tree_count(cells: Array) -> int:
	# Base the number of trees on the number of cells in the biome
	var rolls: int = 3
	var sum: float = 0
	for i in rolls:
		sum += randi() % int(cells.size() / 10.0)
		
	return int(sum / rolls) + 1

static func get_tree_size_scale(size: String) -> float:
	match size:
		"small":
			return randf_range(0.7, 0.8)
		"medium":
			return randf_range(0.95, 1.05)
		"big":
			return randf_range(1.2, 1.3)
		"huge":
			return randf_range(1.45, 1.55)
		_:
			return 1.0

static func place_shadows(tree_node: Node2D, scale: float) -> void:
	var shadow_node: Sprite2D = Sprite2D.new()
	shadow_node.texture = TREE_SHADOW_SPRITE
	shadow_node.scale = Vector2(scale, scale)
	shadow_node.position = Vector2(randf_range(-5, 5), randf_range(-5, 5))
	shadow_node.z_index = -1
	tree_node.add_child(shadow_node)

static func place_trees(main_scene: Node2D, biome_cells: Dictionary) -> void:
	for biome_name in ["Grass", "Tundra", "Beach"]:
		var cells: Array = biome_cells.get(biome_name)

		# Base the number of trees on the number of cells in the biome
		var tree_count: int = get_tree_count(cells)
		
		for i in range(tree_count):
			var cell: Vector2i = cells[randi() % cells.size()]
			var tree_entry: Dictionary = get_random_tree(biome_name)
			
			# Avoid collisions with other trees, elevation layer cliffs, etc.
			var check_position: Vector2 = Vector2(cell.x * 16, cell.y * 16)
			var collision_detected: bool = detect_collision_in_radius(main_scene, 15, check_position) # 15 px is the largest Area2D radius

			if !collision_detected and tree_entry.size() > 0:
				var tree_node: Node2D = tree_entry["scene"].instantiate()
				tree_node.position = check_position
				main_scene.add_child(tree_node)
				place_shadows(tree_node, get_tree_size_scale(tree_entry["size"]))
