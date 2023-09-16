extends GameObjectComponent

@export var PushImpulse : float = 100
@export var TriggerOnHitSignal : bool = true
@export var UpdateDirectionConstantly : bool = false

signal OnHit(nodeHit:GameObject, hitNumber:int)

@export var is_active : bool
var hit_objects : Array[Node]
var push_direction : Vector2 = Vector2.INF

func _ready():
	initGameObjectComponent()
	hit_objects = []
	_gameObject.connectToSignal("CollisionStarted", collisionWithNode)
	
	if UpdateDirectionConstantly:
		directionUpdateRoutine()
		
func directionUpdateRoutine():
	var directionProvider : Node = _gameObject.getChildNodeWithMethod("get_targetDirection")
	if directionProvider == null:
		return
	while _gameObject != null && !_gameObject.is_queued_for_deletion():
		set_fixedPushDirection(directionProvider.get_targetDirection())
		await get_tree().process_frame

		
func set_push_active(push_active:bool):
	is_active = push_active
	hit_objects.clear()

func set_fixedPushDirection(direction:Vector2):
	push_direction = direction

func collisionWithNode(node:Node):
	if not is_active: return
	node = Global.get_gameObject_in_parents(node)
	if node == null or node.is_queued_for_deletion() or hit_objects.has(node):
		# collision doesn't seem relevant!
		return
	
	hit_objects.append(node)
	if TriggerOnHitSignal:
		OnHit.emit(node, 0)
	
	var hit_position_provider = node.getChildNodeWithMethod("get_worldPosition")
	var hit_pos = hit_position_provider.get_worldPosition()
	
	if push_direction == Vector2.INF:
		printerr("FixedPushOnHit doesn't have any direction to push to!")
		return
	
	Forces.PushSingleObject(node, push_direction, PushImpulse)
