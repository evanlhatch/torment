extends GameObjectComponent

@export var OverworldNode : Node2D
@export var CharacterSprite : AnimatedSprite2D
@export var SetStateOnInteraction : GameState.States

@export_group("Dialogue Settings")
## This dictionary defines which dialogues are played when a certain unlock key isn't set, yet.
## The dictionary key contains a unlock key string and the according value points to the dialogue resource.
@export var Dialogues : Dictionary

var _velocityProvider : Node
var _lastNonZeroVelocity : Vector2
var clickArea : Area2D


func _ready():
	initGameObjectComponent()
	_velocityProvider = _gameObject.getChildNodeWithMethod("get_targetVelocity")
	_gameObject.connectToSignal("mouse_entered", _on_mouse_entered)
	_gameObject.connectToSignal("mouse_exited", _on_mouse_exited)
	_gameObject.connectToSignal("input_event", _on_input_event)

	clickArea = _gameObject.getChildNodeWithMethod("set_pickable")
	clickArea.set_pickable(false)

	OverworldNode.connect("PlayerCharacterSelected", _on_player_character_selected)

	await Global.awaitInitialization()
	Global.WorldsPool.connect("HallsEntered", _on_mouse_exited)

func set_facingDirection(newFacing : Vector2):
	_lastNonZeroVelocity = newFacing


func get_facingDirection() -> Vector2:
	if _velocityProvider:
		var targetVel : Vector2 = _velocityProvider.get_targetVelocity()
		if targetVel.length() > 0.1:
			_lastNonZeroVelocity = targetVel
			return targetVel
	return _lastNonZeroVelocity

func _on_mouse_entered():
	CharacterSprite.material.set_shader_parameter("line_thickness", 1.0)
	CharacterSprite.material.set_shader_parameter("line_color", Color.RED)

func _on_mouse_exited():
	CharacterSprite.material.set_shader_parameter("line_thickness", 0.0)
	CharacterSprite.material.set_shader_parameter("line_color", Color.TRANSPARENT)

func _on_input_event(_viewport:Node, event:InputEvent, _shape_index:int):
	if event is InputEventMouseButton and event.pressed:
		select_menu()

func select_menu():
	var dialogue_unlock_keys = Dialogues.keys()
	dialogue_unlock_keys.sort()
	for k in dialogue_unlock_keys:
		if not Global.QuestPool.is_unlock_key_set(k):
			Global.QuestPool.set_unlock_key(k)
			GlobalMenus.storyDialogueUI.set_dialogue(Dialogues[k])
			GameState.SetState(GameState.States.StoryDialogue)
			return
	GameState.SetState(SetStateOnInteraction)


func _on_player_character_selected():
	clickArea.set_pickable(true)
