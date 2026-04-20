class_name Spirot
extends CharacterBody2D

@onready var sprite: Sprite2D = $Character
@onready var shadow: Sprite2D = $Shadow

@export var speed: float = 48.0
@export var sprint_multiplier: float = 1.25
@export var animation_tree: AnimationTree 
@export var animation_player: AnimationPlayer
@export var TileMapLayers: Array[TileMapLayer]

const TILE_SIZE: int = 16
const JUMP_FORCE: float = 60.0
const GRAVITY: float = -180.0

var is_jumping: bool = false
var current_layer: int = 0
var previous_layer: int = 0

var z_height: float = 0.0
var z_height_extra: float = 0.0
var z_velocity: float = 0.0

# The tileset I'm using doesn't have individual wall tile(s), so the array is empty
const tile_atlas_coords_ignore: Array[Vector2i] = []
var y_pos_walltile_for_falling: float = 0.0

var sprite_fall_speed: float = 16.0
var shadow_scale_speed: float = 30.0

var input: Vector2
var playback: AnimationNodeStateMachinePlayback
var move_multiplier: float = 1.0

func _ready():
	# Animation
	playback = animation_tree["parameters/playback"]
	
	# Top-Down jumping
	TileMapLayers[current_layer].collision_enabled = true
	z_index = current_layer
	for i in TileMapLayers.size():
		TileMapLayers[i]._3d_layer = i + 1
		TileMapLayers[i]._ready()

func _physics_process(delta: float) -> void:
	# Respective -x, +x, -y, +y
	input = Input.get_vector("left", "right", "up", "down")
	
	# Check if sprinting (holding down shift) and not standing still to avoid speeding up idle animation 
	var sprinting := Input.is_action_pressed("sprint") and input != Vector2.ZERO
	move_multiplier = sprint_multiplier if sprinting else 1.0
	velocity = input * speed * move_multiplier

	# Jumping and falling logic: https://www.youtube.com/watch?v=evnCIOZp2os

	# Note: Ensure that move_and_slide() and all jump logic is called after the fall logic
	# This is to make sure that Spirot's horizontal position changing from move_and_slide()
	# Isn't fighting against the fall logic repositioning Spirot
	var tile_below: int = _is_tile_below_empty()
	# Zero means can't fall any further down; but if it's 3, then Spirot is stuck inside a wall on a higher layer
	if !is_jumping and tile_below != -1 and (current_layer > 0 or tile_below == 3):
		_fall_logic(tile_below)
		return
	
	# Jump input is pressing space
	if !is_jumping and Input.is_action_just_pressed("jump"):
		if _can_jump():
			current_layer += 1
			z_velocity = JUMP_FORCE
			is_jumping = true
	
	if is_jumping:
		jump_logic(delta)
	else:
		z_height = 0.0
		z_velocity = 0.0
	
	# Update collisions based on the new current TileMapLayer
	if previous_layer != current_layer:
		z_index = current_layer
		if previous_layer < TileMapLayers.size():
			TileMapLayers[previous_layer].collision_enabled = false
			if previous_layer != 0:
				for i in previous_layer:
					TileMapLayers[i].collision_enabled = false
		if current_layer < TileMapLayers.size():
			TileMapLayers[current_layer].collision_enabled = true
		previous_layer = current_layer
	
	move_and_slide()

	# Shadow scaling to emulate 3D feel
	var shadow_scale_factor: float = clamp(1.0 - (z_height * 0.02), 0.1, 1.0)
	var shadow_scale_weight: float = 1.0 - exp(-(shadow_scale_speed) * delta)
	shadow.scale = lerp(shadow.scale, Vector2.ONE * shadow_scale_factor, shadow_scale_weight)

	# Animating size of Spirot sprite
	var z_height_extra_weight: float = 1.0 - exp(-(sprite_fall_speed) * delta)
	z_height_extra = lerp(z_height_extra, 0.0, z_height_extra_weight)
	sprite.position.y = -z_height - z_height_extra
	
	select_animation()
	update_animation_parameters()
	update_animation_speed()

func select_animation():
	if velocity == Vector2.ZERO:
		playback.travel("Idle")
	else:
		playback.travel("Walk")

func update_animation_parameters():
	if input == Vector2.ZERO:
		return
		
	animation_tree["parameters/Idle/blend_position"] = input
	animation_tree["parameters/Walk/blend_position"] = input

func update_animation_speed():
	if animation_player:
		animation_player.speed_scale = move_multiplier

func _can_jump() -> bool:
	var higher_layer_tilemap: TileMapLayer = null
	if current_layer + 1 < TileMapLayers.size():
		higher_layer_tilemap = TileMapLayers[current_layer + 1]
	else:
		return true
	
	var half_width_x: float = $CollisionShape2D.shape.size.x / 2.0
	var half_width_y: float = $CollisionShape2D.shape.size.y / 2.0
	var pos_offset: Array[Vector2] = [
		Vector2(-half_width_x, half_width_y), Vector2(half_width_x, half_width_y),
		Vector2(-half_width_x, -half_width_y), Vector2(half_width_x, -half_width_y)
	]
	
	for i in pos_offset:
		var current_pos: Vector2 = $CollisionShape2D.global_position + i
		var current_tile_pos: Vector2 = higher_layer_tilemap.local_to_map(current_pos)
		var higher_tile_data: TileData = higher_layer_tilemap.get_cell_tile_data(current_tile_pos)
	
		if higher_tile_data:
			return false
	return true

func jump_logic(delta: float) -> void:
	z_velocity += GRAVITY * delta
	z_height = max(0.0, z_height + (z_velocity * delta))
	
	if z_height == 0 and z_velocity < 0.0:
		var landed_on_floor: bool = false
		var landed_on_wall: bool = false
		for i in range(current_layer - 1, -1, -1):
			var tilemap: TileMapLayer = TileMapLayers[i]
			
			var half_width_x: float = $CollisionShape2D.shape.size.x / 2.0
			var half_width_y: float = $CollisionShape2D.shape.size.y / 2.0
			var pos_offset: Array[Vector2] = [
				Vector2(-half_width_x, half_width_y), Vector2(half_width_x, half_width_y),
				Vector2(-half_width_x, -half_width_y), Vector2(half_width_x, -half_width_y)
			]
		
			for j in pos_offset:
				var current_pos: Vector2 = $CollisionShape2D.global_position + j
				var current_tile_pos: Vector2 = tilemap.local_to_map(current_pos)
				var tile_data: TileData = tilemap.get_cell_tile_data(current_tile_pos)
				
				if tile_data:
					var atlas_coords: Vector2i = tilemap.get_cell_atlas_coords(current_tile_pos)
					if tile_atlas_coords_ignore.has(atlas_coords):
						landed_on_wall = true
						y_pos_walltile_for_falling = current_tile_pos.y + 1
					else:
						current_layer = i + 1
						landed_on_floor = true
						break
			if landed_on_floor:
				break
		if landed_on_wall and !landed_on_floor:
			# Landing on a wall on the current layer
			_fall_logic(2)
		is_jumping = false

func _is_tile_below_empty() -> int:
	var current_tilemap: TileMapLayer = TileMapLayers[current_layer - 1]
	var higher_layer_tilemap: TileMapLayer = null
	if current_layer < TileMapLayers.size():
		higher_layer_tilemap = TileMapLayers[current_layer]
	
	var half_width_x: float = $CollisionShape2D.shape.size.x / 2.0
	var half_width_y: float = $CollisionShape2D.shape.size.y / 2.0
	var pos_offset: Array[Vector2] = [
		Vector2(-half_width_x, half_width_y), Vector2(half_width_x, half_width_y),
	]
	
	var should_fall_and_change_y_pos: bool = false
	
	for i in pos_offset:
		var current_pos: Vector2 = $CollisionShape2D.global_position + i
		var current_tile_pos: Vector2 = current_tilemap.local_to_map(current_pos)
		var tile_data: TileData = current_tilemap.get_cell_tile_data(current_tile_pos)
	
		if tile_data:
			var atlas_coords: Vector2i = current_tilemap.get_cell_atlas_coords(current_tile_pos)
			var higher_layer_atlas_coords: Vector2i = Vector2i.ZERO
			if higher_layer_tilemap:
				higher_layer_atlas_coords = higher_layer_tilemap.get_cell_atlas_coords(current_tile_pos)
			
			if tile_atlas_coords_ignore.has(atlas_coords):
				y_pos_walltile_for_falling = current_tile_pos.y + 1

				# Standing on a wall tile
				should_fall_and_change_y_pos = true
			else:
				if higher_layer_tilemap and tile_atlas_coords_ignore.has(higher_layer_atlas_coords):
					y_pos_walltile_for_falling = current_tile_pos.y + 1

					# Stuck in a wall on a higher layer
					return 3
				# Solid floor
				return -1
		else:
			var higher_layer_atlas_coords: Vector2i = Vector2i.ZERO
			if higher_layer_tilemap:
				higher_layer_atlas_coords = higher_layer_tilemap.get_cell_atlas_coords(current_tile_pos)

			if higher_layer_tilemap and tile_atlas_coords_ignore.has(higher_layer_atlas_coords):
				y_pos_walltile_for_falling = current_tile_pos.y + 1

				# Same thing as above
				return 3
	if should_fall_and_change_y_pos:
		# On a wall on the current layer
		return 2
	
	# Standing on an empty tile!
	return 1


func _fall_logic(tile_below: int) -> void:
	if tile_below != 3:
		TileMapLayers[current_layer].collision_enabled = false
		current_layer -= 1
		TileMapLayers[current_layer].collision_enabled = true
	
	is_jumping = false
	z_index = current_layer

	if tile_below == 2 or tile_below == 3:
		var goal_y_pos: float = (y_pos_walltile_for_falling * TILE_SIZE) + abs($CollisionShape2D.position.y - $CollisionShape2D.shape.size.y * 0.5) + 0.1
		z_height_extra = Vector2(0, goal_y_pos).distance_to(Vector2(0, global_position.y))

		# Sprite offsets itself making global position look like it hasn't changed
		sprite.position.y = -z_height - z_height_extra
		global_position.y = goal_y_pos
