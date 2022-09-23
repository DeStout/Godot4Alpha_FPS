extends CharacterBody3D
class_name Enemy

# Debug
var debug_label : Label

const ACCELERATION := 35.0
const DEACCEL := 5.0
const MAX_VEL := 7.0
const TURN_SPEED := 4.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var container : Node3D

@onready var nav_agent : NavigationAgent3D = $NavAgent
@onready var player_cast : RayCast3D = $PlayerSeent
var player : Player = null
var player_seent := false
@onready var visual_target : Node3D = $PlayerSeent/Target
var visual_target_default := Vector3.ZERO

var floor_normal := Vector3.UP
var moving_target := Vector3.ZERO
var helper_transform := Transform3D.IDENTITY
var friction := Vector3.ZERO
var velocity_clamp := Vector3.ZERO


func _ready() -> void:
	visual_target_default = visual_target.position


func _physics_process(delta) -> void:
	debug_label.text = str(-basis.z.dot(global_position.direction_to(player_cast.get_collision_point())))
	if player_seent and -basis.z.dot(global_position.direction_to(player_cast.get_collision_point())) > 0:
		visual_target.global_position = player_cast.get_collision_point()
	else:
		visual_target.position = visual_target_default
	
	if is_on_floor():
		floor_normal = get_floor_normal()
	else:
		floor_normal = Vector3.UP
	
	nav_agent.set_target_location(player.global_position)
	moving_target = nav_agent.get_next_location()
	moving_target.y = global_position.y
	
	helper_transform = transform.looking_at(moving_target)
	transform = transform.interpolate_with(helper_transform, TURN_SPEED * delta)
		
	velocity += (moving_target - global_position).slide(floor_normal).normalized() * ACCELERATION * delta
	velocity.y -= gravity * delta
	move_and_slide()
	
	friction = Vector3(-velocity.x, 0, -velocity.z)
	velocity += friction * DEACCEL * delta
	if velocity.length() > MAX_VEL:
		velocity_clamp = Vector3(velocity.x, 0, velocity.z)
		velocity = velocity_clamp.normalized() * MAX_VEL
	
	_player_is_seent()


func _player_is_seent() -> void:
	if player != null:
		player_cast.target_position = player_cast.to_local(player.global_position + Vector3.UP)
		await get_tree().process_frame
		player_seent = player_cast.is_colliding() and \
						player_cast.get_collider().collision_layer == Globals.player_layer
		
		$PlayerSeent/VectorCube.look_at(player_cast.to_global(player_cast.target_position))
		$PlayerSeent/VectorCube.scale.z = player_cast.target_position.length()*5
