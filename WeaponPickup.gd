extends Node3D
class_name WeaponPickup

@export_enum("Pistol", "Rifle") var weapon
var rifle_ := "res://Rifle.tscn"
var pistol_ := "res://Pistol.tscn"
var pickup : Resource

@export var respawn_time := 60
@export var available := true
var rotation_speed := 1.8

var picked_up : Callable = _picked_up


func _ready() -> void:
	match weapon:
		0:
			$Spinner/Pistol.visible = true
			$Area3D/CollisionShape3D.shape.radius = 0.5
			pickup = load(pistol_)
		1:
			$Spinner/Rifle.visible = true
			$Area3D/CollisionShape3D.shape.radius = 1.5
			pickup = load(rifle_)


func _process(delta):
	$Spinner.rotate_y(rotation_speed * delta)


func _body_entered(body) -> void:
	if body is CharacterBody3D:
		if body.has_method("pickup_weapon"):
			body.pickup_weapon(weapon, self, picked_up)


func _picked_up() -> void:
	available = false
	visible = false
#	$Area3D/CollisionShape3D.set_deferred("disabled", true)
	await get_tree().create_timer(respawn_time).timeout
	_spawn()


func _spawn() -> void:
	available = true
	visible = true
#	$Area3D/CollisionShape3D.disabled = false
