extends Node


var player_layer := 2

# Called when the node enters the scene tree for the first time.
func _ready():
	_set_layer_ints()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _set_layer_ints() -> void:
	for i in range(32):
		if ProjectSettings.get_setting("layer_names/3d_physics/layer_" + str(i+1)) == "Player":
			player_layer = i+1
			break
