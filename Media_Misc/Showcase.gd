extends GameObjectComponent

@export var RotationSpeed : float = 1.0
@export var StartDirection : Vector2 = Vector2(0.0, 2.0)

var direction : Vector2
var facingSetter : Node

func _ready():
	initGameObjectComponent()
	direction = StartDirection

func _process(delta):
	direction = direction.rotated(2 * PI * RotationSpeed * delta)

func get_facingDirection() -> Vector2:
	return direction
	
func get_targetVelocity() -> Vector2:
	return direction

func get_velocity() -> Vector2:
	return direction
