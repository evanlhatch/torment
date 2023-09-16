extends Node

const MAX_SPAWNS_PER_FRAME : int = 5

var DistanceFromScreenEdge = 100
var SpawnScene : PackedScene
var SpawnInterval : float = 0.5
var NumberOfSpawnsPerInterval : int = 10
var SpawnTargetCount : int = 100
var Lifetime : float = -1.0
var MakeSpawnedDisposableOnExit : bool = true
var DestroyWhenTargetCountReached : bool = false
var MinRank : float = 0.0
var MaxRank : float = 5.0
var SpawnFlags = 0b1111

var possible_edges : Array[int]
var _nextSpawnTick : float = 0
var _remainingTimeToNextSpawn : float = 0

@onready var _spawnedObjects : Array[Node] = []


func _enter_tree():
	_update_spawn_settings()

func _exit_tree():
	if MakeSpawnedDisposableOnExit:
		for so in _spawnedObjects:
			so.add_to_group("Disposable")

func set_spawn_flags(spawn_flags:int):
	SpawnFlags = spawn_flags
	_update_spawn_settings()

func _update_spawn_settings():
	possible_edges.clear()
	if SpawnFlags & 0b0001: possible_edges.append(0)
	if SpawnFlags & 0b0010: possible_edges.append(1)
	if SpawnFlags & 0b0100: possible_edges.append(2)
	if SpawnFlags & 0b1000: possible_edges.append(3)

func spawn(scene:PackedScene):
	var spawned = scene.instantiate()
	add_to_spawned_objects(spawned)
	Global.attach_toWorld(spawned, false)
	Global.World.OffscreenPositioner.position_node_offscreen(spawned, possible_edges)

	if spawned.has_method("getChildNodesWithMethod"):
		var nodes_with_difficulty : Array
		spawned.getChildNodesWithMethod("set_difficulty", nodes_with_difficulty)
		var difficulty : float = Global.World.TormentRank.get_torment_difficulty()
		var xpmod : float = Global.World.TormentRank.get_rank_xp_modifier()
		for nodeWithDifficulty in nodes_with_difficulty:
			nodeWithDifficulty.set_difficulty(difficulty, xpmod)

	if Global.is_world_ready():
		Global.World.emit_signal("EnemyAppeared", spawned)


func _process(delta):
#ifdef PROFILING
#	updateWaveSpawner(delta)
#
#func updateWaveSpawner(delta):
#endif
	if GameState.CurrentState == GameState.States.PlayerDied:
		return

	_remainingTimeToNextSpawn -= delta
	var rank = Global.World.get_torment_rank()
	if _remainingTimeToNextSpawn < 0:
		_remainingTimeToNextSpawn = get_spawn_interval()
		if rank >= MinRank && rank <= MaxRank:
			spawn_wave()
	_nextSpawnTick -= delta

	if Lifetime > 0.0:
		Lifetime -= delta
		if Lifetime <= 0.0:
			queue_free()

func spawn_wave():
	var num_spawns_this_frame : int = 0
	for i in range(get_number_of_spawns_per_interval()):
		if len(_spawnedObjects) >= get_spawn_target_count():
			if DestroyWhenTargetCountReached:
				queue_free()
			break
		spawn(SpawnScene)
		num_spawns_this_frame += 1
		if num_spawns_this_frame > MAX_SPAWNS_PER_FRAME:
			await get_tree().process_frame
			num_spawns_this_frame = 0

func on_spawned_object_removed(removedObject:Node):
	_spawnedObjects.erase(removedObject)

func add_to_spawned_objects(node:Node):
	if node.has_signal("Removed"):
		node.connect("Removed", on_spawned_object_removed)
		_spawnedObjects.append(node)
	if node.has_method("set_spawn_origin"):
		node.set_spawn_origin(self)

var SpawnTargetUsesRank : bool
func get_spawn_target_count() -> int:
	if SpawnTargetUsesRank:
		return int(round(float(SpawnTargetCount) * Global.World.TormentRank.get_spawn_count_target_modifier()))
	return SpawnTargetCount

var SpawnIntervalUsesRank : bool
func get_spawn_interval() -> float:
	if SpawnIntervalUsesRank:
		return SpawnInterval / Global.World.TormentRank.get_spawn_spawn_interval_modifier()
	return SpawnInterval

var SpawnNumberPerIntervalUsesRank : bool
func get_number_of_spawns_per_interval() -> int:
	if SpawnNumberPerIntervalUsesRank:
		return int(round(float(NumberOfSpawnsPerInterval) * Global.World.TormentRank.get_spawns_per_interval_modifier()))
	return NumberOfSpawnsPerInterval
