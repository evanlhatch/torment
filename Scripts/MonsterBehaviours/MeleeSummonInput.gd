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
