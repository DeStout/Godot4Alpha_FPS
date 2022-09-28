extends State
class_name EnemyState


var enemy : Enemy
var anim_tree : AnimationNodeStateMachinePlayback


func _ready() -> void:
	await owner.ready
	enemy = owner as Enemy
	anim_tree = $"%AnimationTree2"["parameters/playback"]
	assert (enemy != null)
