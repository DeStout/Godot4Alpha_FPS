extends EnemyState


var patrol_follow : PathFollow3D


func _ready() -> void:
	super()
	print(enemy.patrol_path)
	patrol_follow = enemy.get_node(enemy.patrol_path).get_node("PathFollow")


func handle_input(_event : InputEvent) -> void:
	pass


func update(delta : float) -> void:
	pass


func physics_update(delta : float) -> void:
	pass


func enter(_msg := {}) -> void:
	anim_tree.travel("Run")


func exit() -> void:
	pass
