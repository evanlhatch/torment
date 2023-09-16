extends GameObjectComponent

@export var SetPlayerAsTargetOnSpawn : bool = true
@export var ClosestDistanceToPlayer : float = 125.0
@export var FarthestDistanceToPlayer : float = 200.0
@export var MaxAttackDistance : float = 180.0
@export var MinAttackStopDuration : float = 2.5
@export var MaxAttackStopDuration : float = 4.0
@export var WaitBeforeAttack : float = 0.75
@export var TeleportDuration : float = 0.2

var targetDirectionSetter : Node
var targetFacingSetter : Node
var input_direction : Vector2
var bullet_emitter : Node

var _stationary_timer : float
var _targetPosProvider : Node
var _teleport_target : Vector2

signal StartTeleport(duration:float)
signal EndTeleport(duration:float)

var stunEffect : Node
var teleport_timer : Timer


func _ready():
	initGameObjectComponent()
	_gameObject.connect("child_entered_tree", _on_child_entered_gameObject)
	targetDirectionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	targetFacingSetter = _gameObject.getChildNodeWithMethod("set_facingDirection")
	if (SetPlayerAsTargetOnSpawn and Global.World.Player != null and
		not Global.World.Player.is_queued_for_deletion()):
		set_target(Global.World.Player)
	bullet_emitter = _gameObject.getChildNodeWithMethod("set_emitting")
	bullet_emitter.connect("AttackTriggered", on_attack_triggered)
	teleport_timer = Timer.new()
	add_child(teleport_timer)

func _on_child_entered_gameObject(node:Node):
	if node.has_method("is_stunned"):
		stunEffect = node

func _process(delta):
	var newInputDir : Vector2 = Vector2.ZERO
	if stunEffect and stunEffect.is_stunned():
		_update_direction(newInputDir)
		return
	
	if is_targetProvider_valid():
		var targetPos = _targetPosProvider.get_worldPosition()
		newInputDir = targetPos - get_gameobjectWorldPosition()
		_update_direction(newInputDir.normalized())
		
	if _stationary_timer > 0.0:
		_stationary_timer -= delta
		return
	_stationary_timer += (2.0 * TeleportDuration +
		randf_range(MinAttackStopDuration, MaxAttackStopDuration))
	start_teleport()


func start_teleport():
	if is_targetProvider_valid():
		var target_pos = _targetPosProvider.get_worldPosition()
		_teleport_target = target_pos + (
			Vector2((randf() - 0.5), (randf() - 0.5)).normalized() * randf_range(
				ClosestDistanceToPlayer, FarthestDistanceToPlayer))
		emit_signal("StartTeleport", TeleportDuration)
		teleport_timer.start(TeleportDuration)
		await teleport_timer.timeout
		end_teleport()


func end_teleport():
	_positionProvider.set_worldPosition(_teleport_target)
	emit_signal("EndTeleport", TeleportDuration)
	teleport_timer.start(WaitBeforeAttack)
	await teleport_timer.timeout
	if (is_targetProvider_valid() and
		MaxAttackDistance > _positionProvider.get_worldPosition().distance_to(_targetPosProvider.get_worldPosition())):
		bullet_emitter.emit_immediate()

func set_target(targetNode : Node):
	_targetPosProvider = targetNode.getChildNodeWithMethod("get_worldPosition")


func get_inputWalkDir() -> Vector2:
	return input_direction


func get_aimDirection() -> Vector2:
	if is_targetProvider_valid():
		var targetPos = _targetPosProvider.get_worldPosition()
		return (targetPos - get_gameobjectWorldPosition()).normalized()
	return input_direction.normalized()

func on_attack_triggered(_attack_index:int):
	pass

func _update_direction(newInputDir:Vector2):
	if newInputDir != input_direction:
		input_direction = newInputDir
		targetFacingSetter.set_facingDirection(get_aimDirection())


func is_targetProvider_valid():
	return _targetPosProvider != null and not _targetPosProvider.is_queued_for_deletion()
