extends CharacterBody3D
class_name Player

const MOUSE_HORZ_SENSITIVITY := -0.002
const MOUSE_VERT_SENSITIVITY := -0.002

var weapon_transforms = load("res://WeaponTransforms.gd")
@onready var shoot_cast := $CameraHelper/Recoil/ShootCast
@onready var slapper : Weapon = $CameraHelper/Recoil/Slapper
@onready var pistol : Weapon = null
@onready var rifle : Weapon = null
var equipped : Weapon

var container : Node3D
var is_shooting := false
var is_reloading := false
var reset_recoil := false
var consecutive_shots := 0
var recoil_reset = null
var max_recoil := deg2rad(89)

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
const SPEED := 5.0
const JUMP_VELOCITY := 4.0

var health := 200


func _ready() -> void:
	weapon_transforms = weapon_transforms.new()
	$CameraHelper/Recoil/ShootCast.add_exception($DamageCollision)
	$CameraHelper/Recoil/ShootCast.add_exception($CameraHelper/Recoil/SlapArea)
	
	_switch_weapon(slapper)
	_update_HUD()


func _physics_process(delta) -> void:
	# Movement
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		motion_velocity.y = JUMP_VELOCITY
	var input_dir = Input.get_vector("Strife_L", "Strife_R", "Forward", "Backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		motion_velocity.x = direction.x * SPEED
		motion_velocity.z = direction.z * SPEED
	else:
		motion_velocity.x = move_toward(motion_velocity.x, 0, SPEED)
		motion_velocity.z = move_toward(motion_velocity.z, 0, SPEED)
	motion_velocity.y -= gravity * delta
		
	move_and_slide()
	
	if position.y < -10:
		container.remove_player(self)
	
	if is_shooting and equipped.can_shoot:
		_shoot()
	if reset_recoil:
		_slerp_recoil(delta)


func _input(event) -> void:
	if event is InputEventMouseMotion:
		$CameraHelper.rotate_x(MOUSE_HORZ_SENSITIVITY * event.relative.y)
		$CameraHelper.rotation.x = clamp($CameraHelper.rotation.x, -max_recoil, \
									max_recoil - $CameraHelper/Recoil.rotation.x)
		rotate_y(MOUSE_HORZ_SENSITIVITY * event.relative.x)
		rotation.z = 0
		if reset_recoil:
			$CameraHelper.rotation.x += $CameraHelper/Recoil.rotation.x
			$CameraHelper/Recoil.rotation.x = 0.0
		
	if event is InputEventMouseButton:
		if event.is_action_pressed("Shoot"):
			if recoil_reset == null:
				recoil_reset = $CameraHelper.rotation.x
			is_shooting = true
		elif event.is_action_released("Shoot"):
			is_shooting = false
	
	if event is InputEventKey:
		if event.is_action_pressed("Reload"):
			if equipped.max_ammo > 0:
				_reload()
		
		if event.is_action_pressed("Weapon1"):
			if slapper != null:
				_switch_weapon(slapper)
		elif event.is_action_pressed("Weapon2"):
			if pistol != null:
				_switch_weapon(pistol)
		elif event.is_action_pressed("Weapon3"):
			if rifle != null:
				_switch_weapon(rifle)


func _shoot() -> void:
	is_reloading = false
	reset_recoil = false
	equipped.shoot(self)
	_update_HUD()
	
	equipped.play("Shoot", false)
	
	if equipped.max_ammo > 0:
		# Create bullet trail
		var shoot_from : Vector3 = equipped.get_node("Nozzle").global_transform.origin
		container.create_shot_trail(shoot_from, shoot_cast.get_collision_point())
		_recoil()
		
		# Damage target or add bullet holes
		if $CameraHelper/Recoil/ShootCast.is_colliding():
			var target = $CameraHelper/Recoil/ShootCast.get_collider()
			if target.get_collision_layer_value(3):
				var target_shape_id = $CameraHelper/Recoil/ShootCast.get_collider_shape()
				if target.get_parent().has_method("is_shot"):
					target.get_parent().is_shot(equipped.base_damage, target_shape_id, self)
			else:
				var collision_point : Vector3 = $CameraHelper/Recoil/ShootCast.get_collision_point()
				var collision_normal : Vector3 = $CameraHelper/Recoil/ShootCast.get_collision_normal()
				container.create_bullet_hole(collision_point, collision_normal)
	else:
		await equipped.slap
	
	if !equipped.is_automatic or equipped.ammo_in_mag == 0:
		is_shooting = false


func _recoil() -> void:
	consecutive_shots += 1
	var recoil_damp : float = clamp(1 - (consecutive_shots / equipped.consec_shots), 0.0, 1.0)
	var temp_rot = $CameraHelper/Recoil.duplicate()
	temp_rot.rotate_x(equipped.v_recoil * recoil_damp)
	
	# Restrict recoil from rotating too far up
	if $CameraHelper.rotation.x + temp_rot.rotation.x > max_recoil:
		$CameraHelper/Recoil.rotation.x = max_recoil - $CameraHelper.rotation.x
	else:
		$CameraHelper/Recoil.rotation.x = temp_rot.rotation.x
		
	# Add random horizontal recoil
	rotate_y(randf_range(-equipped.h_recoil, equipped.h_recoil))
	rotation.z = 0
	$CameraHelper/Recoil/RecoilTimer.start(2.0 / equipped.rps)


func _reset_recoil() -> void:
	if !is_shooting:
		consecutive_shots = 0
		$CameraHelper/Recoil.rotation.x -= (recoil_reset - $CameraHelper.rotation.x)
		$CameraHelper.rotation.x = recoil_reset
		reset_recoil = true
		recoil_reset = null


func _slerp_recoil(delta : float):
	$CameraHelper/Recoil.rotation.x = lerp($CameraHelper/Recoil.rotation.x, 0, delta * 3)
	if is_equal_approx($CameraHelper/Recoil.rotation.x, 0.0):
		reset_recoil = false


func _slap() -> void:
	var targets = $CameraHelper/Recoil/SlapArea.get_overlapping_areas()
	for target in targets:
		var parent
		if target is CollisionObject3D:
			if parent == null or parent != target.get_parent():
				if target.get_parent().has_method("is_shot"):
					parent = target.get_parent()
					if parent != self:
						parent.is_shot(equipped.base_damage, 1, self)


func _reload() -> void:
	if equipped.total_ammo > 0 and equipped.ammo_in_mag < equipped.mag_size:
		is_reloading = true
		await equipped.play("Reload")
		if is_reloading:
			equipped.reload()
			_update_HUD()
		is_reloading = false


func _update_HUD() -> void:
	$CameraHelper/Recoil/Camera/HUD/Health.text = str(health)
	$CameraHelper/Recoil/Camera/HUD/Mag.text = str(equipped.ammo_in_mag) + "/" + \
										str(equipped.mag_size)
	$CameraHelper/Recoil/Camera/HUD/TotalAmmo.text = str(equipped.total_ammo)
#	if equipped == slapper:
#		$CameraHelper/Recoil/Camera/HUD.visible = false
#	else:
#		$CameraHelper/Recoil/Camera/HUD.visible = true


func pickup_weapon(weapon : int, pickup : WeaponPickup, picked_up : Callable) -> void:
	if pickup.available:
		var instance = pickup.pickup.instantiate()
		match weapon:
			0:
				if pistol != null:
					add_ammo(instance.mag_size, weapon, picked_up)
					return
				pistol = instance
				pistol.position = weapon_transforms.PISTOL_POSITION
				pistol.rotation = weapon_transforms.PISTOL_ROTATION
				_switch_weapon(pistol)
			1:
				if rifle != null:
					add_ammo(instance.mag_size, weapon, picked_up)
					return
				rifle = instance
				rifle.position = weapon_transforms.RIFLE_POSITION
				rifle.rotation = weapon_transforms.RIFLE_ROTATION
				_switch_weapon(rifle)
		$CameraHelper/Recoil.add_child(instance)
		picked_up.call()


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
		_update_HUD()


func add_ammo(amount : int, ammo_for : int, picked_up : Callable) -> void:
	match ammo_for:
		0:
			if pistol != null:
				pistol.add_ammo(amount, picked_up)
		1:
			if rifle != null:
				rifle.add_ammo(amount, picked_up)
	_update_HUD()


func is_shot(damage : int, shape_id : int, shooter : Enemy) -> void:
	if $DamageCollision.shape_owner_get_owner(shape_id) == $DamageCollision/HeadCollision:
		damage *= 1.5
	health -= damage
	if health <= 0:
		container.remove_player(self, shooter)
	_update_HUD()
