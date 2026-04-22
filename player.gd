class_name Spirot
extends CharacterBody2D

@onready var sprite: Sprite2D = $Character
@onready var shadow: Sprite2D = $Shadow
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

@export var speed: float = 48.0
@export var sprint_multiplier: float = 1.25
@export var animation_tree: AnimationTree 
@export var animation_player: AnimationPlayer
@export var TileMapLayers: Array[TileMapLayer]

const TILE_SIZE: int = 16
const JUMP_FORCE: float = 50.0
const GRAVITY: float = -170.0

var is_jumping: bool = false
var current_layer: int = 0

var z_height: float = 0.0
var z_height_extra: float = 0.0
var z_velocity: float = 0.0

var sprite_fall_speed: float = 15.0
var shadow_scale_speed: float = 30.0

var input: Vector2
var playback: AnimationNodeStateMachinePlayback
var move_multiplier: float = 1.0

func _ready():
	# Set up:
	# (1) Animation playback reference
	playback = animation_tree["parameters/playback"]

	# (2) Keep all elevation layers collidable until a jump occurs
	_set_jump_collisions(false)
	
	# (3) TileMapLayers' z-index based on their order in the TileMapLayers array
	for i in TileMapLayers.size():
		TileMapLayers[i]._3d_layer = i + 1
		TileMapLayers[i]._ready()
	
	# (4) Spirot's z-index (always on top)
	z_index = 100

func _physics_process(delta: float) -> void:
	# Respective -x, +x, -y, +y
	input = Input.get_vector("left", "right", "up", "down")
	
	# Check (1) if holding down shift and (2) not standing still to avoid speeding up idle animation 
	var sprinting := Input.is_action_pressed("sprint") and input != Vector2.ZERO
	move_multiplier = sprint_multiplier if sprinting else 1.0
	velocity = input * speed * move_multiplier
	
	# Top-down jumping (without falling) logic inspired by: https://www.youtube.com/watch?v=evnCIOZp2os
	if !is_jumping and Input.is_action_just_pressed("jump"):
		_set_jump_collisions(true)
		z_velocity = JUMP_FORCE
		is_jumping = true
	
	if is_jumping:
		jump_logic(delta)
	else:
		z_height = 0.0
		z_velocity = 0.0
	
	move_and_slide()

	# Emulating 3D feel:
	# (1) Shadow scaling
	var shadow_scale_factor: float = clamp(1.0 - (z_height * 0.025), 0.1, 1.0)
	var shadow_scale_weight: float = 1.0 - exp(-(shadow_scale_speed) * delta)
	shadow.scale = lerp(shadow.scale, Vector2.ONE * shadow_scale_factor, shadow_scale_weight)

	# (2) Animating Spirot sprite position
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

func _get_collision_circle() -> Array[Vector2]:
	var collision_shape_data: CircleShape2D = collision_shape.shape
	var radius: float = collision_shape_data.radius
	var diagonal_offset: float = radius * cos(PI / 4)

	return [
		Vector2(0.0, radius),
		Vector2(radius, 0.0),
		Vector2(0.0, -radius),
		Vector2(-radius, 0.0),
		Vector2(diagonal_offset, diagonal_offset),
		Vector2(diagonal_offset, -diagonal_offset),
		Vector2(-diagonal_offset, diagonal_offset),
		Vector2(-diagonal_offset, -diagonal_offset)
	]

func _set_jump_collisions(enabled: bool) -> void:
	# During jumps, turn off all lower layer collisions and the one directly above it
	for i in TileMapLayers.size():
		var layer_number: int = i + 1
		var keep_collisions := not enabled
		if enabled:
			keep_collisions = not (layer_number <= current_layer or layer_number == current_layer + 1)
		TileMapLayers[i].collision_enabled = keep_collisions

func _get_highest_layer_under_player() -> int:
	var pos_offset: Array[Vector2] = _get_collision_circle()

	# Check each layer from top to bottom for any tiles under the Spirot's collision circle
	# Returns the highest layer index found (1-based) or 0 if none found
	for layer_index in range(TileMapLayers.size() - 1, -1, -1):
		var tilemap: TileMapLayer = TileMapLayers[layer_index]
		for offset in pos_offset:
			var current_pos: Vector2 = collision_shape.global_position + offset
			var current_tile_pos: Vector2 = tilemap.local_to_map(current_pos)
			var tile_data: TileData = tilemap.get_cell_tile_data(current_tile_pos)
			if tile_data:
				return layer_index + 1

	return 0

func jump_logic(delta: float) -> void:
	z_velocity += GRAVITY * delta
	z_height = max(0.0, z_height + (z_velocity * delta))
	
	if z_height == 0 and z_velocity < 0.0:
		current_layer = _get_highest_layer_under_player()
		_set_jump_collisions(false)
		is_jumping = false
