extends CharacterBody3D
class_name Enemy

# Debug
var debug_label : Label

# Movement variables
const ACCELERATION := 4.0
const DEACCEL := 1.0
const MAX_VELOCITY := 4.5
const TURN_SPEED := 4.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Navigation variables
@export_enum("Normal", "Aggressive", "Slapper", "Scared") var behavior
@onready var nav_agent : NavigationAgent3D = $NavAgent
@onready var player_cast : RayCast3D = $PlayerSeen
var behavior_tree = load("res://EnemyBehaviorTree.gd")
var goal : Array
var pickups : Node3D
var nav_points : Node3D
var player : CharacterBody3D = null
var player_seen := false
@onready var find_timer := $FindTimer
var find_time := 3.0
var slapper_preferred_dist := [1.0, 3.0]
var pistol_preferred_dist := [10.0, 15.0]
var rifle_preferred_dist := [15.0, 22.5]
var preferred_distance : Array

# Weapons
var weapon_transforms = load("res://WeaponTransforms.gd")
@onready var slapper : Weapon = $Head/ViewHelper/Slapper
@onready var pistol : Weapon = null
@onready var rifle : Weapon = null
var equipped : Node3D

# Shooting variables
@onready var shoot_cast : RayCast3D = $Head/ShootCast
var container : Node3D
var is_shooting := false
var is_reloading := false

# Misc
@onready var camera : Camera3D = $Head/ViewHelper/Camera3D
var default_color : Color
var health : int = 100


func _ready():
	behavior = "Normal"
	behavior_tree = behavior_tree.new()
	weapon_transforms = weapon_transforms.new()
	
	default_color = $Body.get_active_material(0).albedo_color
	
	player_cast.add_exception($DamageCollision)
	player_cast.add_exception($Head/SlapArea)
	shoot_cast.add_exception($DamageCollision)
	shoot_cast.add_exception($Head/SlapArea)
	
	_switch_weapon(slapper)


#func _process(delta):
#	if !find_timer.is_stopped():
#		print(find_timer.time_left)


func _physics_process(delta):
	match goal[0]:
		"Wander":
			if player_seen:
				if equipped == slapper and \
			global_transform.origin.distance_to(player.global_transform.origin) < preferred_distance[1]:
					switch_goal()
				elif equipped != slapper:
					switch_goal()
		"FindPlayer":
			nav_agent.set_target_location(player.global_transform.origin)
			if player_seen:
				switch_goal()
		"FindWeapon":
			if player_seen:
				switch_goal()
		"FindAmmo":
			if equipped.total_ammo >= equipped.mag_size:
				switch_goal()
		"Attack":
			var nav_point : Vector3 = global_transform.origin.direction_to(player.global_transform.origin)
			nav_point *= preferred_distance[0]
			nav_agent.set_target_location(to_global(nav_point))
			goal[1][0] = nav_agent.distance_to_target()
			goal[1][1] = Node3D.new()
			goal[1][1].global_transform.origin = nav_point
			
			if !player_seen or nav_agent.distance_to_target() > preferred_distance[1]:
				is_shooting = false
				_reload()
				switch_goal()
			else:
				if equipped.total_ammo == 0 and equipped != slapper:
					is_shooting = false
					if pistol != null and pistol.total_ammo > 0:
						_switch_weapon(pistol)
					elif rifle != null and rifle.total_ammo > 0:
						_switch_weapon(rifle)
					else:
						_switch_weapon(slapper)
					switch_goal()
				elif equipped.ammo_in_mag == 0 and equipped != slapper:
					is_shooting = false
					_reload()
				else:
					is_shooting = true
	
	var target : Vector3 = nav_agent.get_next_location()
	target.y = position.y
	var pos = global_transform.origin
	
	# Turn body towards target
	var new_transform : Transform3D
	if goal[0] == "Attack":
		var player_target : Vector3 = player.global_transform.origin
		player_target.y = position.y
		new_transform = transform.looking_at(player_target)
	else:
		new_transform = transform.looking_at(target)
	transform = transform.sphere_interpolate_with(new_transform, TURN_SPEED * delta)
	
	# Look at Player
	if goal[0] == "FindPlayer" or goal[0] == "Attack":
		var head_trans : Transform3D = $Head.global_transform
		var look_at : Transform3D = head_trans.looking_at \
						(player.global_transform.origin+Vector3(0, 1.4, 0))
		$Head.global_transform = head_trans.sphere_interpolate_with(look_at, 2 * TURN_SPEED * delta)
	else:
		$Head.rotation.lerp(Vector3.ZERO, 2 * TURN_SPEED * delta)
		var look_at : Basis = $Head.basis.looking_at(Vector3.FORWARD)
		$Head.basis = $Head.basis.slerp(look_at, TURN_SPEED * delta)
	$Head.rotation.x = clamp($Head.rotation.x, deg2rad(-45), deg2rad(85))
	$Head.rotation.y = clamp($Head.rotation.y, deg2rad(-80), deg2rad(80))
	$Head.rotation.z = 0
	
	if is_equal_approx(abs(rad2deg($Head.rotation.y)), 80):
		is_shooting = false
	
	# Move torwards goal
	var floor_normal : Vector3
	if is_on_floor():
		floor_normal = get_floor_normal()
	else:
		floor_normal = Vector3.UP
	
	player_is_seen()
	
#	print(goal[1][1].global_transform.origin, " ", player.global_transform.origin)
	if global_transform.origin.distance_to(goal[1][1].global_transform.origin):
		motion_velocity += (target - pos).slide(floor_normal).normalized() * ACCELERATION * delta
		var velocity2D := Vector2(motion_velocity.x, motion_velocity.z)
		if velocity2D.length() > MAX_VELOCITY:
			var velocity_clamp := MAX_VELOCITY / velocity2D.length()
			motion_velocity.x *= velocity_clamp
			motion_velocity.z *= velocity_clamp
		
	motion_velocity.y -= gravity * delta
	move_and_slide()
	motion_velocity.x -= motion_velocity.x * DEACCEL * delta
	motion_velocity.z -= motion_velocity.z * DEACCEL * delta
	
	if is_shooting and equipped.can_shoot:
		_shoot()
	
	if position.y < -10:
		container.remove_enemy(self)


func _target_reached():
#	print(str(name) + ": Target Reached -> " + str(goal[1][1].name))
	if goal[1][1] != WeaponPickup or goal[1][1] != Ammo:
		switch_goal()


func switch_goal():
	goal = behavior_tree.new_behavior(self)
	debug_label.text = str(name) + ": " + goal[0] + " -> " + str(goal[1][1].name)
	nav_agent.set_target_location(goal[1][1].global_transform.origin)


func player_is_seen() -> void:
	if player != null:
		player_cast.target_position = player_cast.to_local((player.global_transform.origin + Vector3.UP*1))
		
		$PlayerSeen/VectorCube.look_at(player_cast.to_global(player_cast.target_position))
		$PlayerSeen/VectorCube.scale.z = player_cast.target_position.length()*5
		
		player_seen = player_cast.is_colliding() and player_cast.get_collider().get_parent() == player
	else:
		player_cast.target_position = Vector3.FORWARD
		player_seen = false


func _shoot() -> void:
	is_reloading = false
	equipped.shoot(self)
	
	equipped.play("Shoot", false)
	
	# Create bullet trail
	if equipped.max_ammo > 0:
		var shoot_from : Vector3 = equipped.get_node("Nozzle").global_transform.origin
		container.create_shot_trail(shoot_from, shoot_cast.get_collision_point())
		
		# Damage target or add bullet holes
		if $Head/ShootCast.is_colliding():
			var target = $Head/ShootCast.get_collider()
			if target.get_collision_layer_value(3):
				var target_shape_id = $Head/ShootCast.get_collider_shape()
				if target.get_parent().has_method("is_shot"):
					target.get_parent().is_shot(equipped.base_damage, target_shape_id, self)
			else:
				var collision_point : Vector3 = $Head/ShootCast.get_collision_point()
				var collision_normal : Vector3 = $Head/ShootCast.get_collision_normal()
				container.create_bullet_hole(collision_point, collision_normal)
	else:
		await equipped.slap
	
	if !equipped.is_automatic or equipped.ammo_in_mag == 0:
		is_shooting = false


func _reload() -> void:
	if equipped.total_ammo > 0 and equipped.ammo_in_mag < equipped.mag_size:
		is_reloading = true
		await equipped.play("Reload")
		if is_reloading:
			equipped.reload()
		is_reloading = false


# Called by signal from Slapper animation player
func _slap() -> void:
	var targets = $Head/SlapArea.get_overlapping_areas()
	for target in targets:
		var parent
		if target is CollisionObject3D:
			if parent == null or parent != target.get_parent():
				if target.get_parent().has_method("is_shot"):
					parent = target.get_parent()
					if parent != self:
						parent.is_shot(equipped.base_damage, 1, self)


func pickup_weapon(weapon : int, pickup : WeaponPickup, picked_up : Callable) -> void:
	if pickup.available:
		var instance = pickup.pickup.instantiate()
		match weapon:
			0:
				if pistol != null:
					add_ammo(instance.mag_size, weapon, picked_up)
					continue
				pistol = instance
				pistol.position = weapon_transforms.PISTOL_POSITION
				pistol.rotation = weapon_transforms.PISTOL_ROTATION
				$Head/ViewHelper.add_child(instance)
				_switch_weapon(pistol)
				picked_up.call()
			1:
				if rifle != null:
					add_ammo(instance.mag_size, weapon, picked_up)
					continue
				rifle = instance
				rifle.position = weapon_transforms.RIFLE_POSITION
				rifle.rotation = weapon_transforms.RIFLE_ROTATION
				$Head/ViewHelper.add_child(instance)
				_switch_weapon(rifle)
				picked_up.call()
	switch_goal()


func _switch_weapon(weapon) -> void:
	is_reloading = false
	if equipped != weapon:
		if equipped != null:
			equipped.can_shoot = false
			await equipped.play("Switch", false)
			equipped.visible = false
		equipped = weapon
		equipped.visible = true
		await equipped.play("Switch", true)
		if equipped.ammo_in_mag > 0 or equipped.max_ammo == 0:
			equipped.can_shoot = true
			
		if equipped == slapper:
			preferred_distance = slapper_preferred_dist
		elif equipped == pistol:
			preferred_distance = pistol_preferred_dist
		elif equipped == rifle:
			preferred_distance = rifle_preferred_dist


func add_ammo(amount : int, ammo_for : int, picked_up : Callable) -> void:
	match ammo_for:
		0:
			if pistol != null:
				pistol.add_ammo(amount, picked_up)
				if equipped != pistol:
					_switch_weapon(pistol)
		1:
			if rifle != null:
				rifle.add_ammo(amount, picked_up)
				if equipped != rifle:
					_switch_weapon(rifle)


func is_shot(damage : int, shape_id : int, enemy : CharacterBody3D) -> void:
	if $DamageCollision.shape_owner_get_owner(shape_id) == $DamageCollision/HeadCollision:
		damage *= 1.5
	health -= damage
	if health <= 0:
		container.remove_enemy(self)
		return
	
	if $DamageCollision.shape_owner_get_owner(shape_id) == $DamageCollision/BodyCollision:
		$Body.get_active_material(0).albedo_color = Color.RED
		await get_tree().create_timer(0.1).timeout
		$Body.get_active_material(0).albedo_color = default_color
	elif $DamageCollision.shape_owner_get_owner(shape_id) == $DamageCollision/HeadCollision:
		$Head.get_active_material(0).albedo_color = Color.RED
		await get_tree().create_timer(0.1).timeout
		$Head.get_active_material(0).albedo_color = default_color
