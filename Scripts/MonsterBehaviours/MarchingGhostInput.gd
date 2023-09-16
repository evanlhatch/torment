extends GameObjectComponent

@export var MarchingVector : Vector2 = Vector2(84, -64)
@export var AnimatedSprite : AnimatedSprite2D
@export var InitialAnimation : String
@export var DefaultAnimation : String

var targetDirectionSetter : Node
var input_direction : Vector2
var loitering_counter : float

var _movement : Vector2

func _ready():
	initGameObjectComponent()
	if not InitialAnimation.is_empty():
		AnimatedSprite.play(InitialAnimation)
		await AnimatedSprite.animation_finished
		if not DefaultAnimation.is_empty():
			AnimatedSprite.play(DefaultAnimation)
	targetDirectionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	input_direction = MarchingVector.normalized()
	targetDirectionSetter.set_targetDirection(input_direction)

func get_inputWalkDir() -> Vector2:
	return input_direction

func get_aimDirection() -> Vector2:
	return input_direction
