extends CharacterBody3D
class_name Enemy

# Debug
var debug_label : Label

const FLOOR_ACCEL := 35.0
const FLOOR_DEACCEL := 5.0
const AIR_ACCEL := 5.0
const AIR_DEACCEL := 1.0
const MAX_VEL := 5.0
const TURN_SPEED := 3.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var container : Node3D

const TARGET_SPEED := 5.0
@onready var nav_agent : NavigationAgent3D = $NavAgent
@onready var player_cast : RayCast3D = $PlayerSeent
var player : Player = null
var player_seent := false
@onready var visual_target : Node3D = $PlayerSeent/Target
var visual_target_default := Vector3.ZERO

var floor_normal := Vector3.UP
var moving_target := Vector3.ZERO
var helper_transform := Transform3D.IDENTITY
var accel := FLOOR_ACCEL
var deaccel := FLOOR_DEACCEL
var friction := Vector3.ZERO
var velocity_clamp := Vector3.ZERO

var temp_dot := 0.0


func _ready() -> void:
	visual_target_default = visual_target.position
	
	await owner.ready
	player = owner.get_node("Player")


func _physics_process(delta) -> void:
	temp_dot = -basis.z.dot(global_position.direction_to(player_cast.get_collision_point()))
	if player_seent and -basis.z.dot(global_position.direction_to(player_cast.get_collision_point())) > 0:
		visual_target.global_position = \
			visual_target.global_position.lerp(player_cast.get_collision_point(), delta * TARGET_SPEED)
	else:
		visual_target.position = visual_target.position.lerp(visual_target_default, delta * TARGET_SPEED)
	
	if is_on_floor():
		floor_normal = get_floor_normal()
		accel = FLOOR_ACCEL
		deaccel = FLOOR_DEACCEL
	else:
		floor_normal = Vector3.UP
		accel = AIR_ACCEL
		deaccel = AIR_DEACCEL
	
	nav_agent.set_target_location(player.global_position)
	moving_target = nav_agent.get_next_location()
	moving_target.y = global_position.y
	
	if transform.origin != moving_target:
		helper_transform = transform.looking_at(moving_target)
	transform = transform.interpolate_with(helper_transform, TURN_SPEED * delta)
		
	velocity += (moving_target - global_position).slide(floor_normal).normalized() * accel * delta
	velocity.y -= gravity * delta
	move_and_slide()
	
	friction = Vector3(-velocity.x, 0, -velocity.z)
	velocity += friction * deaccel * delta
	if velocity.length() > MAX_VEL:
		velocity_clamp = Vector3(velocity.x, 0, velocity.z)
		velocity = velocity_clamp.normalized() * MAX_VEL
	
	_player_is_seent()


func _player_is_seent() -> void:
	if player != null:
		player_cast.target_position = player_cast.to_local(player.global_position + Vector3.UP)
		player_seent = player_cast.is_colliding() and \
						player_cast.get_collider().collision_layer == Globals.player_layer
		
		# Show sight to Player
#		$PlayerSeent/VectorCube.look_at(player_cast.to_global(player_cast.target_position))
#		$PlayerSeent/VectorCube.scale.z = player_cast.target_position.length()*5
		# Show sight to visual_target
#		$PlayerSeent/VectorCube.look_at(visual_target.global_position)
#		$PlayerSeent/VectorCube.scale.z = global_position.distance_to(visual_target.global_position)*5

func _state_transitioned(new_state) -> void:
	print(str(new_state.name))
