extends CharacterBody3D
#class_name Enemy

# Debug
var debug_label : Label

# Movement variables
const ACCELERATION := 4.0
const DEACCEL := 0.2
const MAX_VELOCITY := 8.0
const TURN_SPEED := 4.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Navigation variables
enum BEHAVIORS{NORMAL, AGGRESSIVE, SLAPPER, SCARED}
enum GOALS{FINDPLAYER, FINDWEAPON, FINDAMMO, ATTACK, WANDER, FLEE}
var behavior_tree = load("res://Characters/EnemyBehaviorTree.gd")
var behavior : int
var goal : Array
@onready var nav_agent : NavigationAgent3D = $NavAgent
@onready var player_cast : RayCast3D = $PlayerSeen
var pickups : Node3D
var nav_points : Node3D

var player : CharacterBody3D = null
var player_seen := false
@onready var find_timer := $FindTimer
var find_time := 3.0
var slapper_preferred_dist := [1.0, 3.0]
var pistol_preferred_dist := [10.0, 15.0]
var rifle_preferred_dist := [15.0, 22.5]
var preferred_distance : Array = slapper_preferred_dist
var target_location : Node3D

# Weapons
var weapon_transforms = load("res://Characters/WeaponTransforms.gd")
@onready var slapper : Weapon = $Head/ViewHelper/Slapper
@onready var pistol : Weapon = null
@onready var rifle : Weapon = null
var equipped : Node3D

# Shooting variables
var consec_shots_range := [3, 8]
var shoot_wait_time := 1.0
@onready var shoot_cast : RayCast3D = $Head/ShootCast
var container : Node3D
var is_shooting := false
var is_reloading := false
var consectutive_shots := 0


# Misc
@onready var camera : Camera3D = $Head/ViewHelper/Camera3D
var default_color : Color
var health : int = 100

# SFX
@onready var walk_sfx := $WalkSFX
@onready var hurt_sfx := $HurtSFX
@onready var death_sfx := $DeathSFX


func _ready() -> void:
	behavior = BEHAVIORS.NORMAL
	behavior_tree = behavior_tree.new()
	weapon_transforms = weapon_transforms.new()
	
	default_color = $Body.get_active_material(0).albedo_color
	
	player_cast.add_exception($DamageCollision)
	player_cast.add_exception($Head/SlapArea)
	shoot_cast.add_exception($DamageCollision)
	shoot_cast.add_exception($Head/SlapArea)
	
	_switch_weapon(slapper)


func _physics_process(delta) -> void:
	match goal[0]:
		GOALS.WANDER:
			is_shooting = false
			if player_seen:
				if equipped == slapper and \
			global_transform.origin.distance_to(player.global_transform.origin) < preferred_distance[1]:
					switch_goal()
				elif equipped != slapper:
					switch_goal()
		GOALS.FINDPLAYER:
			is_shooting = false
			nav_agent.set_target_location(player.global_transform.origin)
			if player_seen:
				switch_goal()
		GOALS.FINDWEAPON:
			is_shooting = false
			if player_seen:
				switch_goal()
		GOALS.FINDAMMO:
			is_shooting = false
			if equipped.total_ammo >= equipped.mag_size:
				switch_goal()
		GOALS.ATTACK:
			var nav_point : Vector3 = global_transform.origin.direction_to(player.global_transform.origin)
			nav_point *= preferred_distance[0]
			nav_agent.set_target_location(to_global(nav_point))
			goal[1][0] = nav_agent.distance_to_target()
			goal[1][1] = target_location
			goal[1][1].global_transform.origin = nav_point
			
			if !player_seen or nav_agent.distance_to_target() > preferred_distance[1]:
				is_shooting = false
				consectutive_shots = 0
				_reload()
				switch_goal()
			else:
				if equipped.total_ammo == 0 and equipped != slapper:
					is_shooting = false
					consectutive_shots = 0
					if pistol != null and pistol.total_ammo > 0:
						_switch_weapon(pistol)
					elif rifle != null and rifle.total_ammo > 0:
						_switch_weapon(rifle)
					else:
						_switch_weapon(slapper)
					switch_goal()
				elif equipped.ammo_in_mag == 0 and equipped != slapper:
					is_shooting = false
					consectutive_shots = 0
					_reload()
				elif !$ShootTimer.is_stopped():
					is_shooting = false
					consectutive_shots = 0
				else:
					is_shooting = true
	
	var target : Vector3 = nav_agent.get_next_location()
	target.y = position.y
	var pos = global_transform.origin
	
	# Turn body towards target
	var new_transform : Transform3D
	if goal[0] == GOALS.ATTACK:
		var player_target : Vector3 = player.global_transform.origin
		player_target.y = position.y
		new_transform = transform.looking_at(player_target)
	elif global_position != target:
		new_transform = transform.looking_at(target)
	transform = transform.interpolate_with(new_transform, TURN_SPEED * delta)
	
	# Look at Player
	if goal[0] == GOALS.FINDPLAYER or goal[0] == GOALS.ATTACK:
		var head_trans : Transform3D = $Head.global_transform
		var look_at : Transform3D = head_trans.looking_at \
						(player.global_transform.origin+Vector3(0, 1.4, 0))
		$Head.global_transform = head_trans.interpolate_with(look_at, 2 * TURN_SPEED * delta)
	else:
		$Head.rotation.lerp(Vector3.ZERO, 2 * TURN_SPEED * delta)
		var look_at : Basis = $Head.basis.looking_at(Vector3.FORWARD)
		$Head.basis = $Head.basis.slerp(look_at, TURN_SPEED * delta)
	$Head.rotation.x = clamp($Head.rotation.x, deg_to_rad(-45), deg_to_rad(85))
	$Head.rotation.y = clamp($Head.rotation.y, deg_to_rad(-80), deg_to_rad(80))
	$Head.rotation.z = 0
	
	if is_equal_approx(abs(rad_to_deg($Head.rotation.y)), 80):
		is_shooting = false
		consectutive_shots = 0
	
	# Move torwards goal
	var floor_normal : Vector3
	if is_on_floor():
		floor_normal = get_floor_normal()
	else:
		floor_normal = Vector3.UP
	
	player_is_seen()
	
#	print(goal[1][1].global_transform.origin, " ", player.global_transform.origin)
	if global_transform.origin.distance_to(goal[1][1].global_transform.origin):
		velocity += (target - pos).slide(floor_normal).normalized() * ACCELERATION * delta
		var velocity2D := Vector2(velocity.x, velocity.z)
		if velocity2D.length() > MAX_VELOCITY:
			var velocity_clamp := MAX_VELOCITY / velocity2D.length()
			velocity.x *= velocity_clamp
			velocity.z *= velocity_clamp
	
	if $WalkTimer.is_stopped():
		var vel_2d := Vector2(velocity.x, velocity.z)
		if vel_2d.length() and is_on_floor():
			walk_sfx.play_rand()
			$WalkTimer.start(0.6)
		
	velocity.y -= gravity * delta
	move_and_slide()
	velocity.x -= velocity.x * DEACCEL * delta
	velocity.z -= velocity.z * DEACCEL * delta
	
	if is_shooting and equipped.can_shoot:
		_shoot()
	
	if position.y < -10:
		container.remove_enemy(self)


func _target_reached() -> void:
#	print(str(name) + ": Target Reached -> " + str(goal[1][1].name))
	if goal[1][1] != WeaponPickup or goal[1][1] != Ammo:
		switch_goal()


func switch_goal() -> void:
	goal = behavior_tree.new_behavior(self)
	debug_label.text = str(name) + ": " + str(goal[0]) + " -> " + str(goal[1][1].name)
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
	_recoil()
	
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
		
	consectutive_shots += 1
	if consectutive_shots >= randi_range(consec_shots_range[0], consec_shots_range[1]):
		$ShootTimer.start(shoot_wait_time)
	if !equipped.is_automatic or equipped.ammo_in_mag == 0:
		is_shooting = false


func _recoil() -> void:
	var recoil_scale : float = 0
	if equipped == pistol:
		recoil_scale = 50.0
	elif equipped == rifle:
		recoil_scale = 10.0
	var recoil : float = recoil_scale * (0.75 + ((0.25 * consectutive_shots) / equipped.consec_shots))
	var v_recoil := randf_range(-equipped.v_recoil, equipped.v_recoil) * recoil_scale
	var h_recoil := randf_range(-equipped.h_recoil, equipped.h_recoil) * recoil_scale
	$Head.rotate_x(v_recoil)
	$Head.rotate_y(h_recoil)
	$Head.rotation.z = 0


func _reload() -> void:
	if equipped.total_ammo > 0 and equipped.ammo_in_mag < equipped.mag_size:
		is_reloading = true
		equipped.play_sfx("Reload", true)
		await equipped.play("Reload")
		if is_reloading:
			equipped.reload(self)
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
						$Slap.play()
						parent.is_shot(equipped.base_damage, 1, self)


func pickup_weapon(weapon : int, pickup : WeaponPickup, kill_pickup : Callable) -> bool:
	var picked_up := false
	if pickup.available:
		var instance = pickup.pickup.instantiate()
		match weapon:
			0:
				if pistol != null:
					picked_up = add_ammo(instance.mag_size, weapon, kill_pickup)
					continue
				pistol = instance
				pistol.position = weapon_transforms.PISTOL_POSITION
				pistol.rotation = weapon_transforms.PISTOL_ROTATION
				$Head/ViewHelper.add_child(instance)
				pistol.play_sfx("Pickup", true)
				_switch_weapon(pistol)
				kill_pickup.call()
				picked_up = true
			1:
				if rifle != null:
					picked_up = add_ammo(instance.mag_size, weapon, kill_pickup)
					continue
				rifle = instance
				rifle.position = weapon_transforms.RIFLE_POSITION
				rifle.rotation = weapon_transforms.RIFLE_ROTATION
				$Head/ViewHelper.add_child(instance)
				rifle.play_sfx("Pickup", true)
				_switch_weapon(rifle)
				kill_pickup.call()
				picked_up = true
	switch_goal()
	return picked_up


func _switch_weapon(weapon) -> void:
	is_reloading = false
	if equipped != weapon:
		if equipped != null:
			equipped.stop_sfx()
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


func add_ammo(amount : int, ammo_for : int, kill_pickup : Callable) -> bool:
	var picked_up := false
	match ammo_for:
		0:
			if pistol != null:
				picked_up = pistol.add_ammo(amount, kill_pickup, self)
				if equipped != pistol:
					_switch_weapon(pistol)
		1:
			if rifle != null:
				picked_up = rifle.add_ammo(amount, kill_pickup, self)
				if equipped != rifle:
					_switch_weapon(rifle)
	return picked_up


func is_shot(damage : int, shape_id : int, enemy : CharacterBody3D) -> void:
	if $HurtTimer.is_stopped():
		hurt_sfx.play_rand()
		$HurtTimer.start(0.5)
	if $DamageCollision.shape_owner_get_owner(shape_id) == $DamageCollision/HeadCollision:
		damage *= 1.5
	health -= damage
	if health <= 0:
		debug_label.text = "Dead"
		_vanish()
		var death_rattle = death_sfx.play_rand()
		await death_rattle.finished
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


func _vanish() -> void:
	set_physics_process(false)
	visible = false
	$CharacterCollision.disabled = true
	$DamageCollision/HeadCollision.disabled = true
	$DamageCollision/BodyCollision.disabled = true
