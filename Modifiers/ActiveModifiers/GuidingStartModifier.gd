extends GameObjectComponent2D

@export var AddAttackSpeedWhenMoving : float = -0.5
@export var AddAttackSpeedWhenAttacking : float = 0.3
@export var AddMovementSpeedWhenMoving : float = 0.3
@export var AddMovementSpeedWhenAttacking : float = -0.5
@export var AttackInterval : float = 0.5
@export var MovementInterval : float = 0.2
@export var MovementThreshold : float = 8.0

@export var Name : String
func get_modifier_name() -> String:
	return Name

@export_group("Indicators")
@export var MoveIndicatorPath : NodePath
@export var AttackIndicatorPath : NodePath

var _previousPosition : Vector2
var _distanceMoved : float

var _move_indicator : Node
var _attack_indicator : Node

var _movement_state : bool
var _attack_state : bool

var _movement_update_timer : float
var _attack_update_timer : float

var _attackSpeedModifier : Modifier
var _movementSpeedModifier : Modifier

func _enter_tree():
	_movement_update_timer = MovementInterval
	_move_indicator = get_node(MoveIndicatorPath)
	_attack_indicator = get_node(AttackIndicatorPath)
	initGameObjectComponent()
	if _gameObject:
		_gameObject.connectToSignal("AttackTriggered", _on_attack)
		_previousPosition = _positionProvider.get_worldPosition()
		_attackSpeedModifier = Modifier.create("AttackSpeed", _gameObject)
		_attackSpeedModifier.setName(Name)
		_movementSpeedModifier = Modifier.create("MovementSpeed", _gameObject)
		_movementSpeedModifier.setName(Name)
		
		var indicator_slot = _gameObject.getChildNodeInGroup("StatusIndicator")
		if indicator_slot != null:
			remove_child(_move_indicator)
			indicator_slot.add_child(_move_indicator)
			_move_indicator.position = Vector2.ZERO
			remove_child(_attack_indicator)
			indicator_slot.add_child(_attack_indicator)
			_attack_indicator.position = Vector2.ZERO


func _exit_tree():
	if _gameObject != null && !_gameObject.is_queued_for_deletion():
		_gameObject.disconnectFromSignal("AttackTriggered", _on_attack)
		_positionProvider = null
	_gameObject = null
	if _move_indicator.get_parent() != self:
		_move_indicator.queue_free()
	if _attack_indicator.get_parent() != self:
		_attack_indicator.queue_free()


func _process(delta):
#ifdef PROFILING
#	updateGuidingStar(delta)
#
#func updateGuidingStar(delta):
#endif
	if not _gameObject: return
	
	var hasChanged : bool = false

	if _movement_update_timer > 0:
		_movement_update_timer -= delta
		if _movement_state and _movement_update_timer <= 0:
			hasChanged = true
			_movement_state = false
	
	if _attack_update_timer > 0:
		_attack_update_timer -= delta
		if _attack_state and _attack_update_timer <= 0:
			hasChanged = true
			_attack_state = false
	
	if hasChanged:
		_update_states()

	var new_position = _positionProvider.get_worldPosition()
	var frame_dist = _previousPosition.distance_to(new_position)
	_distanceMoved += frame_dist
	_previousPosition = new_position
	if _distanceMoved >= MovementThreshold:
		_on_move()

func _on_attack(_attack_index:int):
	_attack_update_timer = AttackInterval
	if not _attack_state:
		_attack_state = true
		_update_states()

func _on_move():
	_distanceMoved = 0.0
	_movement_update_timer = MovementInterval
	if not _movement_state:
		_movement_state = true
		_update_states()

func _on_stop():
	if _movement_state:
		_movement_state = false
		_update_states()

func _update_states():
	_move_indicator.visible = _movement_state
	_attack_indicator.visible = _attack_state

	var moveSpeedMod = 0.0
	if _movement_state: moveSpeedMod += AddMovementSpeedWhenMoving
	if _attack_state: moveSpeedMod += AddMovementSpeedWhenAttacking
	_movementSpeedModifier.setMultiplierMod(moveSpeedMod)

	var attackSpeedMod = 0.0
	if _movement_state: attackSpeedMod += AddAttackSpeedWhenMoving
	if _attack_state: attackSpeedMod += AddAttackSpeedWhenAttacking
	_attackSpeedModifier.setMultiplierMod(attackSpeedMod)

	_gameObject.triggerModifierUpdated("AttackSpeed")
	_gameObject.triggerModifierUpdated("MovementSpeed")
