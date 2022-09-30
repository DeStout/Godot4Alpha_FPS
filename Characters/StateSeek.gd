extends EnemyState


const SEEK_TIME := 3.0


func _ready() -> void:
	super()
	
	owner.connect("player_in_range", Callable(self, "_player_in_range"))
	owner.connect("player_seent", Callable(self, "_player_seent"))
	owner.connect("player_unseent", Callable(self, "_player_seent"))


func handle_input(_event : InputEvent) -> void:
	if _event.is_action_pressed("Drop"):
		state_machine.transition_to("Idle")


func update(delta : float) -> void:
	pass


func physics_update(delta : float) -> void:
	pass


func enter(_msg := {}) -> void:
	anim_tree.travel("Run")
	
	_player_seent()


func exit() -> void:
	$SeekTimer.stop()


func _player_seent() -> void:
	if state_machine.state == self:
		if owner._player_seent:
			if owner._player_in_range:
				state_machine.transition_to("Attack")
			else:
				$SeekTimer.stop()
		else:
			$SeekTimer.start(SEEK_TIME)


func _player_in_range() -> void:
	if state_machine.state == self:
		if owner._player_seent:
			state_machine.transition_to("Attack")


func _patrol() -> void:
	if state_machine.state == self:
		state_machine.transition_to("Patrol")
