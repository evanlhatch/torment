extends GameObjectComponent

@export_enum("OnKilled", "OnEndOfLife", "Touched") var OnEvent : int = 0
@export var InheritIsDisposable : bool
@export var SpawnPickup : bool
@export var SpawnedObjects : Array[PackedScene]
@export var SpawnProbabilities : Array[float]
@export var SpawnAmount : int = 1
@export var SpawnPosOffset : Vector2
@export var InheritSpawnOrigin : bool
@export var SpawnWhenMinDistToPlayer : float = -1.0
@export var SpawnWithDelay : float = 0.0
@export var SpawnWithDirection : bool = true
@export var DirectionalOffset : float = 0.0
@export var SetDamageSourceToPlayer : bool = false

@export_group("Spawn Position Modification")
@export var UseOffscreenPositioner : bool = false
@export var CenterPosOffset : Vector2 = Vector2(176.0, 136.0)
@export var MaxDistanceToCenter : float = 300.0

var _delay_timer : Timer
var _spawn_pos : Vector2
var _spawn_dir : Vector2
var _spawn_origin : Node

func _ready():
	_spawn_dir = Vector2.DOWN
	initGameObjectComponent()
	if _gameObject == null:
		return
	if OnEvent == 0:
		_gameObject.connectToSignal("Killed", _on_killed)
	elif OnEvent == 1:
		_gameObject.connectToSignal("OnEndOfLife", _on_killed.bind(null))
	elif OnEvent == 2:
		_gameObject.connectToSignal("Touched", _on_killed.bind(null))
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
	if UseOffscreenPositioner:
		_spawn_pos = Global.World.OffscreenPositioner.get_nearest_valid_position(_spawn_pos)

	var dirProvider = _gameObject.getChildNodeWithMethod("get_aimDirection")
	if dirProvider:
		_spawn_dir = dirProvider.get_aimDirection()

	if _gameObject.has_method("get_spawn_origin"):
		_spawn_origin = _gameObject.get_spawn_origin()
	else:
		_spawn_origin = null

	if SpawnWithDelay > 0.0:
		get_parent().remove_child(self)
		Global.add_child(self)
		_delay_timer.start(SpawnWithDelay)
		await _delay_timer.timeout

	for _i in range(SpawnAmount):
		if SpawnPickup:
			spawn_pickup()
		else:
			spawn_object()
	queue_free()


func spawn_pickup():
	if Global.is_world_ready():
		var pickup_scene = Global.World.Pickups.pick_item()
		var pickup = pickup_scene.instantiate()
		pickup.global_position = get_gameobjectWorldPosition() + SpawnPosOffset
		Global.attach_toWorld(pickup)


func spawn_object():
	var spawnedObject = null
	for i in len(SpawnedObjects):
		if randf() <= SpawnProbabilities[i]:
			spawnedObject = SpawnedObjects[i]
			break

	if spawnedObject == null:
		return

	var obj = spawnedObject.instantiate()
	if (SetDamageSourceToPlayer and
		Global.World.Player != null and
		not Global.World.Player.is_queued_for_deletion()):

		if obj.has_method("set_sourceGameObject"):
			obj.set_sourceGameObject(Global.World.Player)
		if obj.has_method("setInheritModifierFrom"):
			# if the spawned object is a gameobject, we'll also inherit
			# the modifier (but without keeping them up to date)
			obj.setInheritModifierFrom(Global.World.Player, false)
	obj.global_position = _spawn_pos
	Global.attach_toWorld(obj)

	if InheritIsDisposable && obj.is_in_group("Disposable"):
		obj.add_to_group("Disposable")

	if SpawnWithDirection:
		var dirComponent = obj.getChildNodeWithMethod("set_targetDirection")
		if dirComponent:
			dirComponent.call_deferred("set_targetDirection", _spawn_dir)

	if InheritSpawnOrigin:
		if obj.has_method("set_spawn_origin") and _spawn_origin != null:
			obj.set_spawn_origin(_spawn_origin)
			if _spawn_origin.has_method("add_to_spawned_objects"):
				_spawn_origin.add_to_spawned_objects(obj)

	if obj.has_method("getChildNodesWithMethod"):
		var nodes_with_difficulty : Array
		obj.getChildNodesWithMethod("set_difficulty", nodes_with_difficulty)
		var difficulty : float = Global.World.TormentRank.get_torment_difficulty()
		var xpmod : float = Global.World.TormentRank.get_rank_xp_modifier()
		for nodeWithDifficulty in nodes_with_difficulty:
			nodeWithDifficulty.set_difficulty(difficulty, xpmod)

