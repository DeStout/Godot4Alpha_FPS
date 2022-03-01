extends Control


var is_visible := true

var fps_visible := true
var enemy_behavior_visible := false

enum Mute{NONE, MUSIC, SFX, ALL}
var mute_visible := true
var mute_all := false
var mute_sfx := false
@onready var master_bus := AudioServer.get_bus_index("Master")
@onready var sfx_bus := AudioServer.get_bus_index("SFX")
@onready var music_bus := AudioServer.get_bus_index("Music")
var mute_setting := Mute.MUSIC

var player : Player
var player_invincible := false


func _ready() -> void:
	visible = is_visible
	$FPS.visible = fps_visible
	
	$Mute.visible = mute_visible
	_set_mute()
	
	$Behaviors.visible = enemy_behavior_visible


func _process(delta) -> void:
	var fps = Performance.get_monitor(Performance.TIME_FPS)
	$FPS.text = "FPS: " + str(fps)


func _input(event) -> void:
	if event.is_action_pressed("Kill"):
		player.container.remove_player(player)
	if event.is_action_pressed("Mute"):
		mute_setting = (mute_setting + 1) % 4
		_set_mute()


func _set_mute() -> void:
	match mute_setting:
		Mute.NONE:
			AudioServer.set_bus_mute(master_bus, false)
			AudioServer.set_bus_mute(sfx_bus, false)
			AudioServer.set_bus_mute(music_bus, false)
			$Mute.text = "Mute: None"
		Mute.MUSIC:
			AudioServer.set_bus_mute(master_bus, false)
			AudioServer.set_bus_mute(sfx_bus, false)
			AudioServer.set_bus_mute(music_bus, true)
			$Mute.text = "Mute: Music"
		Mute.SFX:
			AudioServer.set_bus_mute(master_bus, false)
			AudioServer.set_bus_mute(sfx_bus, true)
			AudioServer.set_bus_mute(music_bus, false)
			$Mute.text = "Mute: SFX"
		Mute.ALL:
			AudioServer.set_bus_mute(master_bus, true)
			AudioServer.set_bus_mute(sfx_bus, false)
			AudioServer.set_bus_mute(music_bus, false)
			$Mute.text = "Mute: All"


func add_enemy_behavior_label(enemy : Enemy) -> Label:
	var label = Label.new()
	label.name = enemy.name
	$Behaviors.add_child(label)
	return label
