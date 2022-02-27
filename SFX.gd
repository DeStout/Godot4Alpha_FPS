extends Node

var sfxs : Array


func _ready():
	sfxs = get_children()


func play_rand():
	if sfxs.size() > 0:
		var sfx = sfxs[randi() % sfxs.size()]
		sfx.play()
		return sfx
	else:
		return null
