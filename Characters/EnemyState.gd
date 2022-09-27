extends State
class_name EnemyState


var enemy : Enemy


func _ready() -> void:
	await owner.ready
	enemy = owner as Enemy
	assert (enemy != null)
