extends SummonInput

@export var AttackTargetUpdateInterval : float = 1.0

var damageByTimeComponent : Node

var delay_timer : Timer
var target_update_timer : Timer


func _ready():
	super()
	if _gameObject == null:
		return

	damageByTimeComponent = _gameObject.getChildNodeWithMethod("resetTimeDamageModifier")
	delay_timer = Timer.new()
	add_child(delay_timer)

	target_update_timer = Timer.new()
	add_child(target_update_timer)
	target_update_timer.timeout.connect(update_attack_target)
	target_update_timer.start(AttackTargetUpdateInterval)


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


func update_attack_target():
	if AutoAttackWhenIdle:
		var attackTargetObj:GameObject = findClosestGameObjectToAttack()
		if attackTargetObj != null:
			attackTarget(attackTargetObj)


# use the player's position to determine the closes target _to the player_.
func findClosestGameObjectToAttack(tryToIgnoreGameObject:GameObject = null) -> GameObject:
	if AttackTriggerRange <= 0:
		return null

	var pos = get_gameobjectWorldPosition()
	if is_summonerPosProvider_valid():
		pos = _summonedByPosProvider.get_worldPosition()

	var potentialTargets = Global.World.Locators.get_gameobjects_in_circle(
		AttackTargetsLocatorPool, pos, AttackTriggerRange)
	if potentialTargets.size() == 0:
		return null
	if potentialTargets.size() == 1:
		return potentialTargets[0]
	potentialTargets.sort_custom(distance_sort)
	if potentialTargets[0] == tryToIgnoreGameObject:
		return potentialTargets[1]
	return potentialTargets[0]
