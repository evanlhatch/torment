extends GameObjectComponent

class_name SummonInput

@export var MaxDistanceToSummoner : float = 200
@export var ComfortDistanceToSummoner : float = 150
@export var AttackTriggerRange : float = 100
@export var AttackTargetsLocatorPool : String = "Enemies"
@export var MinAttackDistance : float = 20
@export var MaxAttackDistance : float = 30
@export var AutoAttackWhenIdle : bool = true
@export var AutoSwitchTargetWhenMinAttackDistanceReached : bool = false
@export var KillAfterTime : float = -1
@export var ModifierCategories : Array[String] = ["Summon"]
@export var TriggerInitialAttackAnimation : int = -1

## NOTE: when this GameObject also has Health, make sure that
##       the Health Node comes before the SummonInput node, so that
##       this "Killed" signal is essentially skipped!
signal Killed(byNode:Node)

enum States {
	Idle,
	WalkingBackToSummoner,
	Attacking,

	# this state can be used in a class extending this to
	# essentially disable the base state handling temporarily
	Custom
}

var _currentState : States = States.Idle
var _summonedBy : GameObject
var _summonedByPosProvider : Node
var _emitter : Node
var _modifiedSummonDuration : ModifiedFloatValue
var _remainingTimeAlive : float

var targetDirectionSetter : Node
var targetFacingSetter : Node
var input_direction : Vector2
var aim_direction : Vector2

func _ready():
	initGameObjectComponent()
	targetDirectionSetter = _gameObject.getChildNodeWithMethod("set_targetDirection")
	targetFacingSetter = _gameObject.getChildNodeWithMethod("set_facingDirection")
	_emitter = _gameObject.getChildNodeWithMethod("set_emitting")


	_remainingTimeAlive = KillAfterTime
	if KillAfterTime > 0:
		_modifiedSummonDuration = createModifiedFloatValue(KillAfterTime, "Force", Callable())
		_remainingTimeAlive = _modifiedSummonDuration.Value()
		_modifiedSummonDuration.ValueUpdated.connect(SummonDurationWasUpdated)
		applyModifierCategories()

	# This is used to trigger custom animations at the beginning of the summon's lifetime
	# e.g. summon animations
	if TriggerInitialAttackAnimation >= 0 and is_instance_valid(_emitter):
		_gameObject.visible = false
		await get_tree().process_frame
		_gameObject.visible = true
		_emitter.AttackTriggered.emit(TriggerInitialAttackAnimation)

func applyModifierCategories():
	_modifiedSummonDuration.setModifierCategories(ModifierCategories)

func SummonDurationWasUpdated(valueBefore:float, valueNow:float):
	if _remainingTimeAlive > 0:
		var change : float = valueNow - valueBefore
		if _remainingTimeAlive + change < 0:
			# this update would kill it, let the next _process do that job:
			_remainingTimeAlive = 0.00001
		else:
			_remainingTimeAlive += change

func set_summonedBy(summoner:GameObject):
	_summonedBy = summoner
	_summonedByPosProvider = summoner.getChildNodeWithMethod("get_worldPosition")

func _process(delta):
	if _remainingTimeAlive > 0:
		_remainingTimeAlive -= delta
		if _remainingTimeAlive <= 0:
			var killedSignaller = _gameObject.getChildNodeWithSignal("Killed")
			killedSignaller.emit_signal("Killed", null)
			_gameObject.queue_free()
			return

	updateWalkingToTargetPosition()
	match _currentState:
		States.Idle:
			idleBehaviour(delta)
		States.WalkingBackToSummoner:
			walkingBackToSummonerBehaviour(delta)
		States.Attacking:
			attackingBehaviour(delta)

func switchState(newState:States):
	match newState:
		States.Idle:
			_idleRemainingTimeToPositionUpdate = 0
			if _emitter != null:
				_emitter.set_emitting(false)
		States.WalkingBackToSummoner:
			if _emitter != null:
				_emitter.set_emitting(false)
		States.Attacking:
			if _emitter != null:
				_emitter.set_emitting(false)
	_currentState = newState


var _idleRemainingTimeToPositionUpdate:float = 0
func idleBehaviour(delta):
	var myPosition:Vector2 = get_gameobjectWorldPosition()
	var currentIdleCenterPosition:Vector2
	if is_summonerPosProvider_valid():
		currentIdleCenterPosition = _summonedByPosProvider.get_worldPosition()
	else:
		currentIdleCenterPosition = myPosition

	if myPosition.distance_squared_to(currentIdleCenterPosition) > MaxDistanceToSummoner*MaxDistanceToSummoner:
		switchState(States.WalkingBackToSummoner)
		return

	if AutoAttackWhenIdle:
		var attackTargetObj:GameObject = findClosestGameObjectToAttack()
		if attackTargetObj != null:
			attackTarget(attackTargetObj)
			return

	_idleRemainingTimeToPositionUpdate -= delta
	if _idleRemainingTimeToPositionUpdate <= 0:
		var idleCurrentTargetPosition:Vector2 = Vector2.ONE * (0.2 + 0.7 * randf())
		idleCurrentTargetPosition = idleCurrentTargetPosition.rotated(randf() * 2.0 * PI)
		idleCurrentTargetPosition *= MaxDistanceToSummoner
		idleCurrentTargetPosition += currentIdleCenterPosition
		walkToTargetPosition(idleCurrentTargetPosition)
		_idleRemainingTimeToPositionUpdate = randf_range(5, 15)


func walkingBackToSummonerBehaviour(_delta):
	var summonerPosition:Vector2
	if is_summonerPosProvider_valid():
		summonerPosition = _summonedByPosProvider.get_worldPosition()
	else:
		switchState(States.Idle)
		return # no summoner?

	var myPosition:Vector2 = get_gameobjectWorldPosition()
	if myPosition.distance_squared_to(summonerPosition) < ComfortDistanceToSummoner*ComfortDistanceToSummoner:
		switchState(States.Idle)
		return
	var newDirection = (summonerPosition - myPosition).normalized()
	targetDirectionSetter.set_targetDirection(newDirection)
	aim_direction = newDirection


var _currentAttackTarget:GameObject = null
var _currentAttackTargetPosProvider
func attackingBehaviour(_delta):
	if _currentAttackTarget == null || _currentAttackTarget.is_queued_for_deletion():
		_currentAttackTarget = null
		_currentAttackTargetPosProvider = null
		switchState(States.Idle)
		return

	var myPosition:Vector2 = get_gameobjectWorldPosition()
	var currentIdleCenterPosition:Vector2
	if is_summonerPosProvider_valid():
		currentIdleCenterPosition = _summonedByPosProvider.get_worldPosition()
	else:
		currentIdleCenterPosition = myPosition

	if myPosition.distance_squared_to(currentIdleCenterPosition) > MaxDistanceToSummoner*MaxDistanceToSummoner:
		switchState(States.WalkingBackToSummoner)
		return

	if _currentAttackTargetPosProvider == null:
		_currentAttackTargetPosProvider = _currentAttackTarget.getChildNodeWithMethod("get_worldPosition")
	var currentTargetPosition:Vector2 = _currentAttackTargetPosProvider.get_worldPosition()
	var directionToTarget:Vector2 = currentTargetPosition-myPosition
	var distanceToTarget:float = directionToTarget.length()
	directionToTarget /= distanceToTarget
	aim_direction = directionToTarget
	if distanceToTarget > MaxAttackDistance:
		targetDirectionSetter.set_targetDirection(directionToTarget)
		if _emitter != null: _emitter.set_emitting(false)
		return
	if distanceToTarget <= MinAttackDistance:
		if _emitter != null: _emitter.set_emitting(true)
		if not AutoSwitchTargetWhenMinAttackDistanceReached:
			targetDirectionSetter.set_targetDirection(Vector2.ZERO)
		else:
			var newTarget := findClosestGameObjectToAttack(_currentAttackTarget)
			if newTarget != _currentAttackTarget:
				attackTarget(newTarget)

func get_facingDirection() -> Vector2:
	return aim_direction

func get_aimDirection() -> Vector2:
	return aim_direction

var _targetPositionReached:bool = true
var _currentTargetPosition:Vector2
var _directionToTargetPosition:Vector2
func walkToTargetPosition(targetPos:Vector2) -> void:
	_currentTargetPosition = targetPos
	_directionToTargetPosition = (_currentTargetPosition - get_gameobjectWorldPosition()).normalized()
	targetDirectionSetter.set_targetDirection(_directionToTargetPosition)
	_targetPositionReached = false
	aim_direction = _directionToTargetPosition

func cancelWalkToTargetPosition() -> void:
	_targetPositionReached = true

func updateWalkingToTargetPosition() -> void:
	if _targetPositionReached:
		return
	var myPosition = get_gameobjectWorldPosition()
	var newVectorToTarget = (_currentTargetPosition - myPosition).normalized()
	aim_direction = newVectorToTarget
	if newVectorToTarget.dot(_directionToTargetPosition) < 0:
		_targetPositionReached = true
		targetDirectionSetter.set_targetDirection(Vector2.ZERO)

func attackTarget(target:GameObject) -> void:
	_currentAttackTarget = target
	_currentAttackTargetPosProvider = target.getChildNodeWithMethod("get_worldPosition")
	switchState(States.Attacking)

func findClosestGameObjectToAttack(tryToIgnoreGameObject:GameObject = null) -> GameObject:
	if AttackTriggerRange <= 0:
		return null

	var potentialTargets = Global.World.Locators.get_gameobjects_in_circle(
		AttackTargetsLocatorPool, get_gameobjectWorldPosition(), AttackTriggerRange)
	if potentialTargets.size() == 0:
		return null
	if potentialTargets.size() == 1:
		return potentialTargets[0]
	potentialTargets.sort_custom(distance_sort)
	if potentialTargets[0] == tryToIgnoreGameObject:
		return potentialTargets[1]
	return potentialTargets[0]

func is_summonerPosProvider_valid():
	return _summonedByPosProvider != null and not _summonedByPosProvider.is_queued_for_deletion()
