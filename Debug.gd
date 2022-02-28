extends Control


var is_visible := true
var fps_visible := true
var enemy_behavior_visible := false

var player : Player
var enemies : Array
@onready var music_player : AudioStreamPlayer = get_tree().current_scene.get_node("MusicPlayer")


func _ready() -> void:
	visible = is_visible
	$FPS.visible = fps_visible
	$Behaviors.visible = enemy_behavior_visible


func _process(delta):
	var fps = Performance.get_monitor(Performance.TIME_FPS)
	$FPS.text = "FPS: " + str(fps)


func _input(event):
	if event.is_action_pressed("Kill"):
		player.container.remove_player(player)
	if event.is_action_pressed("Mute"):
		music_player.stream_paused = !music_player.stream_paused


func add_enemy_behavior_label(enemy : Enemy) -> Label:
	var label = Label.new()
	label.name = enemy.name
	$Behaviors.add_child(label)
	return label
