extends GameObjectComponent

@export var MaxHomingDistance : float = 100.0
@export var HomingRadAngle : float = 0.785398
@export var SampleTargetInterval : float = 0.2
@export var HitLocatorPools : Array[String] = ["Enemies", "Breakables"]

var directionProvider : Node
var currentTarget : Node
var currentTargetPosProvider : Node
var bulletComponent : Node
@onready var passed_targets : Array[Node] = []

var sample_timer : float


func _ready():
	initGameObjectComponent()
	directionProvider = _gameObject.getChildNodeWithMethod("get_targetDirection")
	bulletComponent = _gameObject.getChildNodeWithSignal("OnHit")
	bulletComponent.OnHit.connect(_on_hit)
	sample_timer = SampleTargetInterval


func _process(delta):
	if currentTarget == null:
		if sample_timer <= 0.0:
			select_new_target()
		else:
			sample_timer -= delta
	else:
		# Sometimes the summons get stuck on a single target.
		# This ensures that they continue their flight when they have reached their target.
		var dir_to_target : Vector2 = currentTargetPosProvider.get_worldPosition() - get_gameobjectWorldPosition()
		if dir_to_target.length_squared() < 256.0:
			select_new_target()


func get_facingDirection() -> Vector2:
	if directionProvider != null:
		return directionProvider.get_targetDirection()
	return Vector2.ZERO


var _tempHits : Array[GameObject] = []
func select_new_target():
	sample_timer = SampleTargetInterval
	_tempHits.clear()
	var pos = get_gameobjectWorldPosition()
	for pool in HitLocatorPools:
		_tempHits.append_array(Global.World.Locators.get_gameobjects_in_circle(
			pool, pos, MaxHomingDistance))
	
	var direction = directionProvider.get_targetDirection()
	var min_angle : float = HomingRadAngle
	var homing_candidate : Node = null
	var homing_candidate_pos_provider : Node = null
	for hit in _tempHits:
		if hit == currentTarget or passed_targets.has(hit): continue
		var hit_pos_provider = hit.getChildNodeWithMethod("get_worldPosition")
		if hit_pos_provider == null: continue
		var hit_dir : Vector2 = hit_pos_provider.get_worldPosition() - pos
		var angle = abs(hit_dir.angle_to(direction))
		if angle < min_angle:
			homing_candidate = hit
			homing_candidate_pos_provider = hit_pos_provider
			min_angle = angle
	
	if homing_candidate != null and not homing_candidate.is_queued_for_deletion():
		passed_targets.append(homing_candidate)
		bulletComponent.set_homing_target(homing_candidate_pos_provider)
		currentTarget = homing_candidate
		currentTargetPosProvider = homing_candidate_pos_provider
	else:
		bulletComponent.set_homing_target(null)
		currentTarget = null
		currentTargetPosProvider = null


func _on_hit(nodeHit:GameObject, _hitNumber:int):
	if nodeHit == currentTarget:
		select_new_target()
