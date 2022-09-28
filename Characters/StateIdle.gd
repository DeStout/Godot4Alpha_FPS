extends EnemyState


func handle_input(_event : InputEvent) -> void:
	pass


func update(delta : float) -> void:
	pass


func physics_update(delta : float) -> void:
	pass


func enter(_msg := {}) -> void:
	$"%AnimationTree".parameters.IdleRun.blend_amount = 0


func exit() -> void:
	pass
