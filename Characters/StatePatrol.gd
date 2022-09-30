extends EnemyState


@export_node_path(Path3D) var path_path
@export_node_path(PathFollow3D) var follow_path
@onready var path : Path3D = get_node(path_path)
@onready var path_follow : PathFollow3D = get_node(follow_path)


func _ready() -> void:
	super()
	
	owner.connect("player_seent", Callable(self, "_player_seent"))


func handle_input(_event : InputEvent) -> void:
	pass


func update(delta : float) -> void:
	pass


func physics_update(delta : float) -> void:
	pass


func enter(_msg := {}) -> void:
	anim_tree.travel("Idle")


func exit() -> void:
	pass


func _player_seent() -> void:
	if state_machine.state == self:
		print("Player Seent")
		state_machine.transition_to("Seek")
