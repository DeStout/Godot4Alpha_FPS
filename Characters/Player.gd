extends CharacterBody3D
class_name Player

const MOUSE_HORZ_SENSITIVITY := -0.002
const MOUSE_VERT_SENSITIVITY := -0.002

var weapon_transforms = load("res://Characters/WeaponTransforms.gd")
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
var max_recoil := deg_to_rad(89)

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
const SPEED := 9.0
const JUMP_VELOCITY := 5.0

# SFX
@onready var walk_sfx := $WalkSFX
@onready var health_sfx := $HealthSFX
@onready var hurt_sfx := $HurtSFX
@onready var death_sfx := $DeathSFX

const MAX_HEALTH := 200
const MAX_ARMOR := 50
var health := 100
var armor := 0
var damage_tween : Tween


func _ready() -> void:
	weapon_transforms = weapon_transforms.new()
	$CameraHelper/Recoil/ShootCast.add_exception($DamageCollision)
	$CameraHelper/Recoil/ShootCast.add_exception($CameraHelper/Recoil/SlapArea)
	
	_switch_weapon(slapper)
	_update_HUD()


func _physics_process(delta) -> void:
	# Movement
	if Input.is_action_just_pressed("Jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var input_dir = Input.get_vector("Strife_L", "Strife_R", "Forward", "Backward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	velocity.y -= gravity * delta
	
	if $WalkTimer.is_stopped():
		var vel_2d := Vector2(velocity.x, velocity.z)
		if vel_2d.length() and is_on_floor():
			walk_sfx.play_rand()
			$WalkTimer.start(0.6)
	
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
			if slapper != null and !is_shooting:
				_switch_weapon(slapper)
		elif event.is_action_pressed("Weapon2"):
			if pistol != null and !is_shooting:
				_switch_weapon(pistol)
		elif event.is_action_pressed("Weapon3"):
			if rifle != null and !is_shooting:
				_switch_weapon(rifle)
		
		if event.is_action_pressed("Drop"):
			_drop_weapon(true)


func _shoot() -> void:
	if !is_reloading:
		equipped.stop_sfx()
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
	
	$CameraHelper/Recoil.rotate_x(equipped.v_recoil * recoil_damp)

	# Restrict recoil from rotating too far up
	if $CameraHelper.rotation.x + $CameraHelper/Recoil.rotation.x > max_recoil:
		$CameraHelper/Recoil.rotation.x = max_recoil - $CameraHelper.rotation.x
#	else:
#		$CameraHelper/Recoil.rotation.x = save_rot.rotation.x
	
	
#	var temp_rot = $CameraHelper/Recoil.duplicate()
#	temp_rot.rotate_x(equipped.v_recoil * recoil_damp)
#
#	# Restrict recoil from rotating too far up
#	if $CameraHelper.rotation.x + temp_rot.rotation.x > max_recoil:
#		$CameraHelper/Recoil.rotation.x = max_recoil - $CameraHelper.rotation.x
#	else:
#		$CameraHelper/Recoil.rotation.x = temp_rot.rotation.x
		
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
	$CameraHelper/Recoil.rotation.x = lerpf($CameraHelper/Recoil.rotation.x, 0, delta * 3)
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
						$Slap.play()
						parent.is_shot(equipped.base_damage, 1, self)


func _reload() -> void:
	if equipped.total_ammo > 0 and equipped.ammo_in_mag < equipped.mag_size:
		is_reloading = true
		equipped.play_sfx("Reload", false)
		await equipped.play("Reload")
		if is_reloading:
			equipped.reload(self)
			_update_HUD()
		is_reloading = false


func _update_HUD() -> void:
	$CameraHelper/Recoil/Camera/HUD/Health.text = str(health)
	if armor > 0:
		$CameraHelper/Recoil/Camera/HUD/Armor.show()
		$CameraHelper/Recoil/Camera/HUD/Armor.text = str(armor)
	else:
		$CameraHelper/Recoil/Camera/HUD/Armor.hide()
		
	$CameraHelper/Recoil/Camera/HUD/Mag.text = str(equipped.ammo_in_mag) + "/" + \
										str(equipped.mag_size)
	$CameraHelper/Recoil/Camera/HUD/TotalAmmo.text = str(equipped.total_ammo)
#	if equipped == slapper:
#		$CameraHelper/Recoil/Camera/HUD.visible = false
#	else:
#		$CameraHelper/Recoil/Camera/HUD.visible = true


func _show_damage() -> void:
	$CameraHelper/Recoil/Camera/HUD/Damage.modulate.a = 1.5
	damage_tween = self.create_tween()
	damage_tween.tween_property($CameraHelper/Recoil/Camera/HUD/Damage, \
							"modulate", Color.TRANSPARENT, 0.5).set_delay(0.5)


func pickup_weapon(weapon : int, pickup : WeaponPickup, kill_pickup : Callable) -> bool:
	if pickup.available:
		var instance = pickup.pickup.instantiate()
		match weapon:
			0:
				if pistol != null:
					return add_ammo(instance.mag_size, weapon, kill_pickup)
				pistol = instance
				pistol.position = weapon_transforms.PISTOL_POSITION
				pistol.rotation = weapon_transforms.PISTOL_ROTATION
				$CameraHelper/Recoil.add_child(instance)
				pistol.play_sfx("Pickup", false)
				_switch_weapon(pistol)
			1:
				if rifle != null:
					return add_ammo(instance.mag_size, weapon, kill_pickup)
				rifle = instance
				rifle.position = weapon_transforms.RIFLE_POSITION
				rifle.rotation = weapon_transforms.RIFLE_ROTATION
				$CameraHelper/Recoil.add_child(instance)
				rifle.play_sfx("Pickup", false)
				_switch_weapon(rifle)
		kill_pickup.call()
		return true
	return false


func _switch_weapon(weapon) -> void:
	is_reloading = false
	if equipped != weapon:
		if equipped != null:
			equipped.stop_sfx()
			equipped.can_shoot = false
#			_reset_recoil()
			await equipped.play("Switch", false)
			equipped.visible = false
		equipped = weapon
		equipped.visible = true
		await equipped.play("Switch", true)
		if equipped.ammo_in_mag > 0 or equipped.max_ammo == 0:
			equipped.can_shoot = true
		_update_HUD()


func _drop_weapon(player_drop : bool) -> void:
		if rifle != null:
			if (player_drop and equipped == rifle) or (!player_drop and equipped.total_ammo > 0):
				container.drop_weapon(rifle)
				rifle.queue_free()
				rifle = null
		elif pistol != null:
			pass # Drop pistol if ammo > max_ammo
		elif slapper != null:
			pass # Drop slapper lol


func add_ammo(amount : int, ammo_for : int, kill_pickup : Callable) -> bool:
	var picked_up : bool
	match ammo_for:
		0:
			if pistol != null:
				picked_up = pistol.add_ammo(amount, kill_pickup, self)
		1:
			if rifle != null:
				picked_up = rifle.add_ammo(amount, kill_pickup, self)
	_update_HUD()
	return picked_up


func add_health(amount : int, picked_up : Callable) -> void:
	if health < MAX_HEALTH:
		health += amount
		health_sfx.play("Health")
		health = min(MAX_HEALTH, health)
		picked_up.call()
		_update_HUD()


func add_armor(amount : int, picked_up : Callable) -> void:
	if armor < MAX_ARMOR:
		armor += amount
		health_sfx.play("Armor")
		armor = min(MAX_ARMOR, armor)
		picked_up.call()
		_update_HUD()


func is_shot(damage : int, shape_id : int, shooter : Enemy) -> void:
	if $HurtTimer.is_stopped():
		hurt_sfx.play_rand()
		$HurtTimer.start(0.5)
	if $DamageCollision.shape_owner_get_owner(shape_id) == $DamageCollision/HeadCollision:
		damage *= 1.5
	
	if !Debug.player_invincible:
		if armor > 0:
			if armor > damage / 2:
				damage /= 2
				armor -= damage
			else:
				damage -= armor
				armor = 0
		health -= damage
	health = max(health, 0)
	_show_damage()
	_update_HUD()
	
	if health <= 0:
		_vanish()
		var death_rattle = death_sfx.play_rand()
		await death_rattle.finished
		container.remove_player(self, shooter)


func _vanish() -> void:
	set_physics_process(false)
	visible = false
	$CharacterCollision.disabled = true
	$DamageCollision/HeadCollision.disabled = true
	$DamageCollision/BodyCollision.disabled = true
