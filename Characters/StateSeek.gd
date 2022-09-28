extends EnemyState


func handle_input(_event : InputEvent) -> void:
	if _event.is_action_pressed("Drop"):
		state_machine.transition_to("Idle")


func update(delta : float) -> void:
	pass


func physics_update(delta : float) -> void:
	pass


func enter(_msg := {}) -> void:
	anim_tree.travel("Run")


func exit() -> void:
	pass
