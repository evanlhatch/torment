extends GameObjectComponent

@export var MaxSeekingDistance : float = 100.0
@export var MaxTurnSpeedRadPerSecond : float = PI
@export var SampleTargetInterval : float = 0.2
@export var HitLocatorPools : Array[String] = ["Enemies", "Breakables"]


var myMover : Node
var currentTarget : GameObject
var currentTargetPosProvider : Node
var currentDirection : Vector2

var sample_timer : float


func _ready():
	initGameObjectComponent()
	if _gameObject == null:
		process_mode = PROCESS_MODE_DISABLED
		return
	process_mode = PROCESS_MODE_INHERIT
	myMover = _gameObject.getChildNodeWithMethod("set_targetDirection")
	currentDirection = myMover.get_targetDirection()
	if currentDirection == Vector2.ZERO:
		currentDirection = Vector2.from_angle(randf_range(0,2*PI))
	sample_timer = 0

func _process(delta):
	sample_timer -= delta
	if sample_timer <= 0.0:
		select_new_target()
		
	if currentTarget != null:
		if currentTarget.is_queued_for_deletion():
			currentTarget = null
			return
		var myPosition := get_gameobjectWorldPosition()
		var targetPos : Vector2 = currentTargetPosProvider.get_worldPosition()
		var dirToTarget : Vector2 = targetPos - myPosition
		var angleToTarget : float = currentDirection.angle_to(dirToTarget)
		#if currentDirection.cross(dirToTarget) > 0:
		#	angleToTarget *= -1.0
		var turnRate : float = clamp(angleToTarget, -MaxTurnSpeedRadPerSecond, MaxTurnSpeedRadPerSecond)
		currentDirection = currentDirection.rotated(turnRate * delta)
		myMover.set_targetDirection(currentDirection)

		
var _tempHits : Array[GameObject] = []
func select_new_target():
	sample_timer = SampleTargetInterval
	_tempHits.clear()
	var pos = get_gameobjectWorldPosition()
	for pool in HitLocatorPools:
		_tempHits.append_array(Global.World.Locators.get_gameobjects_in_circle(
			pool, pos, MaxSeekingDistance))
	if _tempHits.size() == 0:
		currentTarget = null
		return
	
	# we need the hits sorted by distance
	_tempHits.sort_custom(distance_sort)
	# but we'll accept when they are further away, but in front of us.
	# up to a limit...
	var newTarget : GameObject
	var newTargetPosProvider : Node
	var closestDot : float = -1
	for tempHit in _tempHits:
		var posProvider = tempHit.getChildNodeWithMethod("get_worldPosition")
		if posProvider == null:
			continue
		var newTargetPos : Vector2 = posProvider.get_worldPosition()
		var dirToNewTarget : Vector2 = newTargetPos - pos
		var dist : float = dirToNewTarget.length()
		if dist > MaxSeekingDistance * 0.2:
			if newTarget == null: 
				newTarget = tempHit
				newTargetPosProvider = posProvider
			break
		dirToNewTarget /= dist
		var dot : float = dirToNewTarget.dot(currentDirection)
		if dot > closestDot:
			closestDot = dot
			newTarget = tempHit
			newTargetPosProvider = posProvider
	
	if newTarget == currentTarget:
		return
	currentTarget = newTarget
	currentTargetPosProvider = newTargetPosProvider
