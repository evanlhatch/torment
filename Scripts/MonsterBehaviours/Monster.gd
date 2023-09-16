extends GameObjectComponent

class_name MonsterInput

@export var SetPlayerAsTargetOnSpawn : bool = true
@export var StopWhenInRange : float = 0.0
@export var KillSelfWhenInStopRange : bool = false
@export_enum("Linear", "Curve", "Offset", "Lane") var MovePattern : int

@export_group("Curved Movement Parameters")
@export var MovementCurvatureAngle : float = 30.0
@export var MovementCurvatureDistance : float = 300.0

@export_group("Offset Movement Parameters")
@export var MinOffsetX : float = -64.0
@export var MaxOffsetX : float = 64.0
@export var MinOffsetY : float = -64.0
@export var MaxOffsetY : float = 64.0

@export_group("Lane Movement Parameters")
@export var LaneDirection : Vector2 = Vector2(84, -63.65)
@export var LaneDivergenceMaxRange : float = 200
@export var LaneDivergenceMinRange : float = 20

@export_group("Loitering Parameters")
@export var MinMotionDuration : float = 1.0
@export var MaxMotionDuration : float = 1.0
@export var MinLoiteringDuration : float = 0.0
@export var MaxLoiteringDuration : float = 0.0

var targetDirectionSetter : Node
var targetFacingSetter : Node
var input_direction : Vector2
var loitering_counter : float

signal input_dir_changed(dir_vector:Vector2)
signal OnEndOfLife

var _targetPosProvider : Node
var targetOffset : Vector2
var _targetOverrideProvider : Node

func _ready():
	initGameObjectComponent()
	targetDirectionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	targetFacingSetter = _gameObject.getChildNodeWithMethod("set_facingDirection")
	_targetOverrideProvider = _gameObject.getChildNodeWithMethod("get_override_target_position")
	if (SetPlayerAsTargetOnSpawn and Global.World.Player != null and
		not Global.World.Player.is_queued_for_deletion()):
		set_target(Global.World.Player)
	if MovePattern == 2:
		targetOffset = Vector2(
			randf_range(MinOffsetX, MaxOffsetY),
			randf_range(MinOffsetY, MinOffsetY))
	else: targetOffset = Vector2.ZERO

func _enter_tree():
	Global.World.MonsterInputSys.RegisterMonsterInput(self)

func _exit_tree():
	Global.World.MonsterInputSys.UnregisterMonsterInput(self)

func set_target(targetNode : Node):
	_targetPosProvider = targetNode.getChildNodeWithMethod("get_worldPosition")

func get_inputWalkDir() -> Vector2:
	return input_direction

func get_aimDirection() -> Vector2:
	# monsters walk to their target and aim to their target...
	return input_direction
