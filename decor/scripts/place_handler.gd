class_name PlaceHandler
extends RefCounted

# https://joeridamme.hashnode.dev/godot-4-detect-body-collision-before-adding-node-to-scene-part-2
static func detect_collision_in_radius(main_scene: Node2D, radius: int, pos: Vector2, group_names: Array) -> bool:
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
	
	# Filter the results to include only objects in the specified groups
	var filtered_array = results.filter(func(collision_object): 
		return group_names.any(func(group_name): return collision_object.collider.is_in_group(group_name))
	)
	
	# Check if there are any objects in the filtered array
	return filtered_array.size() > 0
