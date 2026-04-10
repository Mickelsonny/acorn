class_name Spirot
extends CharacterBody2D

@export var speed: float = 64.0
@export var sprint_multiplier: float = 1.5
@export var animation_tree: AnimationTree 
@export var animation_player: AnimationPlayer

var input: Vector2
var playback: AnimationNodeStateMachinePlayback
var move_multiplier: float = 1.0

func _ready():
	playback = animation_tree["parameters/playback"]

func _physics_process(_delta: float) -> void:
	# Respective -x, +x, -y, +y
	input = Input.get_vector("left", "right", "up", "down")
	
	# Check if sprinting (holding down shift) and avoid speeding up idle animation while standing still
	var sprinting := Input.is_action_pressed("sprint") and input != Vector2.ZERO
	
	move_multiplier = sprint_multiplier if sprinting else 1.0
	
	velocity = input * speed * move_multiplier
	move_and_slide()
	
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
