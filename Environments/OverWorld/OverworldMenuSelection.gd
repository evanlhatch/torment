extends Node

@export var OverworldNode : Node2D
@export var ObjectSprite : Sprite2D
@export var ObjectSpriteAnimated : AnimatedSprite2D
@export var TriggerGameState : GameState.States
@export var MouseInteractionArea : Area2D


func _ready():
	MouseInteractionArea.set_pickable(false)

	MouseInteractionArea.mouse_entered.connect(_on_mouse_entered)
	MouseInteractionArea.mouse_exited.connect(_on_mouse_exited)
	MouseInteractionArea.input_event.connect(_on_input_event)

	OverworldNode.PlayerCharacterSelected.connect(_on_player_character_selected)

	await Global.awaitInitialization()
	Global.WorldsPool.connect("HallsEntered", _on_mouse_exited)

func _on_mouse_entered():
	if ObjectSprite != null:
		ObjectSprite.material.set_shader_parameter("line_thickness", 1.0)
		ObjectSprite.material.set_shader_parameter("line_color", Color.RED)
	elif ObjectSpriteAnimated != null:
		ObjectSpriteAnimated.material.set_shader_parameter("line_thickness", 1.0)
		ObjectSpriteAnimated.material.set_shader_parameter("line_color", Color.RED)


func _on_mouse_exited():
	if ObjectSprite != null:
		ObjectSprite.material.set_shader_parameter("line_thickness", 0.0)
		ObjectSprite.material.set_shader_parameter("line_color", Color(0.0, 0.0, 0.0, 0.0))
	elif ObjectSpriteAnimated != null:
		ObjectSpriteAnimated.material.set_shader_parameter("line_thickness", 0.0)
		ObjectSpriteAnimated.material.set_shader_parameter("line_color", Color(0.0, 0.0, 0.0, 0.0))


func _on_input_event(_viewport:Node, event:InputEvent, _shape_index:int):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		select_menu()


func select_menu():
	if GameState.CurrentState == GameState.States.Overworld:
		GameState.SetState(TriggerGameState)

func _on_player_character_selected():
	MouseInteractionArea.set_pickable(true)
