extends GameObjectComponent

@export var CharacterSprite : AnimatedSprite2D
@export var PlayerCharacterScene : PackedScene
@export var PlayerCharacterIdentifier : String
@export var CharacterInfo : CharacterInfoResource
@export var ActiveInState : GameState.States = GameState.States.Overworld

var isInPlayerControl : bool
var inputProvider
var hovered : bool
var clickArea : Area2D

var _velocityProvider : Node
var _lastNonZeroVelocity : Vector2
var _returnBehaviour : Node

signal CharacterSelected(_gameObject)
signal CharacterInfoHovered(character_info)
signal PlayerControlChanged(is_in_player_control)

func _ready():
	initGameObjectComponent()
	if CharacterSprite:
		CharacterSprite.material = CharacterSprite.material.duplicate()
		CharacterSprite.set_sprite_direction(Vector2.DOWN)
		CharacterSprite.set_sprite_animation_state(CharacterSprite.IdleAnimationName, true)
		CharacterSprite.update_animation_state(true)
	inputProvider = _gameObject.getChildNodeWithMethod("get_inputWalkDir")
	clickArea = _gameObject.getChildNodeWithMethod("set_pickable")
	set_isInPlayerControl(inputProvider != null)
	_gameObject.connectToSignal("mouse_entered", _on_mouse_entered)
	_gameObject.connectToSignal("mouse_exited", _on_mouse_exited)
	_velocityProvider = _gameObject.getChildNodeWithMethod("get_targetVelocity")
	_returnBehaviour = _gameObject.getChildNodeWithMethod("return_to_bonfire")
	CharacterInfoHovered.connect(GlobalMenus.hudOverworld.show_character_info)


func set_facingDirection(newFacing : Vector2):
	_lastNonZeroVelocity = newFacing

func get_facingDirection() -> Vector2:
	if _velocityProvider:
		var targetVel : Vector2 = _velocityProvider.get_targetVelocity()
		if targetVel.length() > 0.1:
			_lastNonZeroVelocity = targetVel
			return targetVel
	return _lastNonZeroVelocity

func get_playerCharacterScene() -> PackedScene:
	return PlayerCharacterScene

func set_isInPlayerControl(value:bool):
	isInPlayerControl = value
	CharacterSprite.material.set_shader_parameter("line_thickness", 0.0)
	CharacterSprite.material.set_shader_parameter("line_color", Color(0.0, 0.0, 0.0, 0.0))
	if clickArea:
		clickArea.set_pickable(!value)
	if isInPlayerControl:
		_returnBehaviour.return_to_bonfire(false)
	PlayerControlChanged.emit(value)

func get_isInPlayerControl() -> bool:
	return isInPlayerControl

func _on_mouse_entered():
	hovered = true
	if not isInPlayerControl:
		CharacterSprite.material.set_shader_parameter("line_thickness", 1.0)
		CharacterSprite.material.set_shader_parameter("line_color", Color.RED)
	if CharacterInfo != null:
		CharacterInfoHovered.emit(CharacterInfo)

func _on_mouse_exited():
	hovered = false
	CharacterSprite.material.set_shader_parameter("line_thickness", 0.0)
	CharacterSprite.material.set_shader_parameter("line_color", Color(0.0, 0.0, 0.0, 0.0))

func _input(event: InputEvent) -> void:
	if ActiveInState != GameState.CurrentState: return
	if not isInPlayerControl and hovered:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			emit_signal("CharacterSelected", _gameObject)
			get_viewport().set_input_as_handled()
