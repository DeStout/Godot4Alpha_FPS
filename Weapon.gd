extends Node3D
class_name Weapon

@export var is_automatic := false
@export var max_ammo := 21
@export var mag_size := 7
@export var rps := 1.0
@export var v_recoil := 0.1
@export var h_recoil := 0.1
@export var consec_shots := 4.0
@export var base_damage := 10

@onready var sfx := $SFX
@onready var sfx_3d := $SFX3D

signal slap
var can_shoot := false
var total_ammo : int
var ammo_in_mag : int


func _ready() -> void:
	total_ammo = max_ammo
	ammo_in_mag = mag_size


func play(animation : String, reverse : bool = true) -> void:
	if !reverse:
		$AnimationPlayer.play(animation)
	else:
		$AnimationPlayer.play_backwards(animation)
	await $AnimationPlayer.animation_finished


func shoot(shooter : CharacterBody3D) -> void:
	var playing
	if shooter is Enemy:
		playing = sfx_3d.play_rand()
	else:
		playing = sfx.play_rand()
	if max_ammo > 0:
		ammo_in_mag -= 1
	can_shoot = false
	$CanShoot.start(1.0 / rps)


func _can_shoot() -> void:
	if ammo_in_mag > 0 or max_ammo == 0:
		can_shoot = true


func reload() -> void:
	if total_ammo > mag_size - ammo_in_mag:
		total_ammo -= mag_size-ammo_in_mag
		ammo_in_mag = mag_size
	else:
		ammo_in_mag += total_ammo
		total_ammo = 0
	
	if ammo_in_mag > 0:
		can_shoot = true


func add_ammo(amount : int, pick_up : Callable) -> void:
	if total_ammo < max_ammo:
		pick_up.call()
	total_ammo = clamp(total_ammo + amount, 0, max_ammo)
