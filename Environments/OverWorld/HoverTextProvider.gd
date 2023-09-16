extends Node

@export var HoverText : String
@export var MouseInteractionArea : Area2D
@export var ActiveInState : GameState.States = GameState.States.Overworld

signal HoverTextEntered(hoverText)
signal HoverTextExited(hoverText)

func _ready():
	MouseInteractionArea.mouse_entered.connect(_on_mouse_entered)
	MouseInteractionArea.mouse_exited.connect(_on_mouse_exited)
	GameState.StateChanged.connect(_on_state_changed)

func _on_mouse_entered():
	if ActiveInState == GameState.CurrentState:
		emit_signal("HoverTextEntered", HoverText)

func _on_mouse_exited():
	if ActiveInState == GameState.CurrentState:
		emit_signal("HoverTextExited", HoverText)

func _on_state_changed(newState, _oldState):
	if ActiveInState != newState:
		emit_signal("HoverTextExited", HoverText)

func get_hover_text() -> String:
	return HoverText
