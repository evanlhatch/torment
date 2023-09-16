extends GameObjectComponent

@export var SetPlayerAsTargetOnSpawn : bool = true
@export var MaxAttackDistance : float = 120.0
@export var WaitAfterAttack : float = 0.3
@export var AttackInterval : float = 1.5
@export var AimLine : Node

var targetDirectionSetter : Node
var targetFacingSetter : Node
var input_direction : Vector2
var bullet_emitter : Node

signal input_dir_changed(dir_vector:Vector2)

var _aimDirection : Vector2
var _targetPosOffset : Vector2
var _targetPosProvider : Node
var _attackTimer : float

func _ready():
	initGameObjectComponent()
	targetDirectionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	targetFacingSetter = _gameObject.getChildNodeWithMethod("set_facingDirection")
	if (SetPlayerAsTargetOnSpawn and
		Global.World.Player != null and
		not Global.World.Player.is_queued_for_deletion()):
		set_target(Global.World.Player)
	bullet_emitter = _gameObject.getChildNodeWithMethod("set_emitting")
	_targetPosOffset = (Vector2.ONE * randf_range(70.0, 120.0)).rotated(randf_range(-PI, PI))

func _process(delta):
	if bullet_emitter.Emitting: return
	var newInputDir : Vector2 = Vector2.ZERO
	if is_targetProvider_valid():
		var targetPos = _targetPosProvider.get_worldPosition() + _targetPosOffset
		newInputDir = (targetPos - get_gameobjectWorldPosition()).normalized()

	if _attackTimer > 0:
		_attackTimer -= delta
	if _attackTimer <= 0.0 and is_targetProvider_valid():
		var dist_sqr = get_gameobjectWorldPosition().distance_squared_to(
			_targetPosProvider.get_worldPosition())
		if dist_sqr <= MaxAttackDistance * MaxAttackDistance:
			aim_and_shoot()
			return

	if newInputDir != input_direction:
		input_direction = newInputDir
		emit_signal("input_dir_changed", input_direction)
		targetDirectionSetter.set_targetDirection(input_direction)
		if not bullet_emitter.Emitting:
			targetFacingSetter.set_facingDirection(input_direction)

func aim_and_shoot():
	input_direction = Vector2.ZERO
	emit_signal("input_dir_changed", input_direction)
	targetDirectionSetter.set_targetDirection(input_direction)
	if is_targetProvider_valid():
		var targetPos = _targetPosProvider.get_worldPosition()
		_aimDirection = (targetPos - get_gameobjectWorldPosition()).normalized()
	targetFacingSetter.set_facingDirection(get_aimDirection())
	bullet_emitter.set_emitting(true)
	var rotationFromDirection = get_aimDirection().angle()
	AimLine.set_rotation(rotationFromDirection)
	AimLine.visible = true
	if bullet_emitter.has_signal("BulletEmitted"):
		await bullet_emitter.BulletEmitted
	await get_tree().create_timer(WaitAfterAttack).timeout
	bullet_emitter.set_emitting(false)
	AimLine.visible = false
	_attackTimer = AttackInterval

func set_target(targetNode : Node):
	_targetPosProvider = targetNode.getChildNodeWithMethod("get_worldPosition")

func get_inputWalkDir() -> Vector2:
	return input_direction

func get_aimDirection() -> Vector2:
	return _aimDirection

func get_targetDirection() -> Vector2:
	return _aimDirection

func is_targetProvider_valid():
	return _targetPosProvider != null and not _targetPosProvider.is_queued_for_deletion()
