extends GameObjectComponent

@export var SpawnedExplosion : PackedScene
@export var SpawnPosOffset : Vector2
@export var SpawnWhenMinDistToPlayer : float = -1.0
@export var SpawnWithDelay : float = 0.0
@export var DirectionalOffset : float = 0.0
@export var SetDamageSourceToPlayer : bool = false

var _delay_timer : Timer
var _spawn_pos : Vector2
var _spawn_origin : Node

var _modifiedDamage
var _modifiedArea

func _ready():
	initGameObjectComponent()
	_gameObject.connectToSignal("Killed", _on_killed)
	if SpawnWithDelay > 0.0:
		_delay_timer = Timer.new()
		add_child(_delay_timer)


func _on_killed(killedBy : Node):
	if Global.World.Player != null and SpawnWhenMinDistToPlayer > 0:
		if Global.World.get_player_position().distance_to(get_gameobjectWorldPosition()) < SpawnWhenMinDistToPlayer:
			return
	
	var dir_pos_offset = Vector2.ZERO
	if DirectionalOffset > 0.0 and killedBy != null:
		var position_provider = killedBy.getChildNodeWithMethod("get_worldPosition")
		if position_provider != null:
			dir_pos_offset = (position_provider.get_worldPosition() - get_gameobjectWorldPosition()).normalized() * -DirectionalOffset

	_spawn_pos = get_gameobjectWorldPosition() + SpawnPosOffset + dir_pos_offset
	if _gameObject.has_method("get_spawn_origin"):
		_spawn_origin = _gameObject.get_spawn_origin()
	else:
		_spawn_origin = null

	if SpawnWithDelay > 0.0:
		get_parent().remove_child(self)
		Global.add_child(self)
		_delay_timer.start(SpawnWithDelay)
		await _delay_timer.timeout
	explode()
	queue_free()


func explode():
	var obj = SpawnedExplosion.instantiate()
	if (SetDamageSourceToPlayer and
		Global.World.Player != null and
		not Global.World.Player.is_queued_for_deletion() and
		obj.has_method("set_sourceGameObject")):
		obj.set_sourceGameObject(Global.World.Player)
	obj.global_position = _spawn_pos
	Global.attach_toWorld(obj)
