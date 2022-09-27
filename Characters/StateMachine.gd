extends Node
class_name StateMachine

signal transitioned(state_name)

@export_node_path(Node) var initial_state

@onready var state : State = get_node(initial_state)


func _ready():
	await owner.ready
	
	for child in get_children():
		child.state_machine = self
	state.enter()


func _unhandled_input(event) -> void:
	state.handle_input(event)


func _process(delta) -> void:
	state.update(delta)


func _physics_process(delta) -> void:
	state.physics_update(delta)


func transition_to(target_state : String, msg : Dictionary = {}) -> void:
	if !has_node(target_state):
		return
	
	state.exit()
	state = get_node(target_state)
	state.enter()
	emit_signal("transitioned", state.name)
