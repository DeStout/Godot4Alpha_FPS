extends Node

var sfxs : Array


func _ready() -> void:
	sfxs = get_children()


func play(find_sfx : String):
	var sfx = get_node(find_sfx)
	if sfx != null:
		sfx.play()
		return sfx
	return sfx


func play_rand():
	if sfxs.size() > 0:
		var sfx = sfxs[randi() % sfxs.size()]
		sfx.play()
		return sfx
	return null


func has_sfx(sfx) -> bool:
	return sfxs.has(sfx)
