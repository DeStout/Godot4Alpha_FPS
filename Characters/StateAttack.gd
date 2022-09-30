extends EnemyState


func _ready() -> void:
	super()
	
	owner.connect("player_unseent", Callable(self, "_seek_player"))
	owner.connect("player_out_range", Callable(self, "_seek_player"))


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


func _seek_player() -> void:
	if state_machine.state == self:
		state_machine.transition_to("Seek")
