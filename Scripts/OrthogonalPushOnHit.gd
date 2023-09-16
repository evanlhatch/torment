extends GameObjectComponent

@export var PushImpulse : float = 100
@export var TriggerOnHitSignal : bool = true
@export var RotatePushDirection : float = PI * 0.5
@export var UpdateDirectionConstantly : bool = false

signal OnHit(nodeHit:GameObject, hitNumber:int)

@export var is_active : bool
var hit_objects : Array[Node]
var orthogonal_direction : Vector2 = Vector2.INF

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
		set_orthoPushDirection(directionProvider.get_targetDirection())
		await get_tree().process_frame

		
func set_push_active(push_active:bool):
	is_active = push_active
	hit_objects.clear()

func set_orthoPushDirection(direction:Vector2):
	orthogonal_direction = direction.rotated(RotatePushDirection) # 1.5708 == PI * 0.5 --> 90 deg

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
	
	if orthogonal_direction == Vector2.INF:
		var directionProvider : Node = _gameObject.getChildNodeWithMethod("get_targetDirection")
		if directionProvider != null:
			set_orthoPushDirection(directionProvider.get_targetDirection())
	if orthogonal_direction == Vector2.INF:
		printerr("OrthogonalPushOnHit doesn't have any direction to orthogonally push to!")
		return
	var ortho_dir:Vector2 = orthogonal_direction
	if ortho_dir.dot(hit_pos - get_gameobjectWorldPosition()) < 0.0:
		ortho_dir = ortho_dir.rotated(-RotatePushDirection * 2.0)
	
	Forces.PushSingleObject(node, ortho_dir, PushImpulse)
