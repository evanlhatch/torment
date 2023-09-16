extends Node2D

@export var SpawnScene : PackedScene
@export var SpawnInterval : float = 0.5
@export var NumberOfSpawnsPerInterval : int = 10
@export var SpawnTargetCount : int = 100
@export var Lifetime : float = -1.0
@export var MakeSpawnedDisposableOnExit : bool = true
@export var DestroyWhenTargetCountReached : bool = false
@export var MinRank : float = 1.0
@export var MaxRank : float = 13.0
@export_flags("North", "South", "East", "West")
var SpawnFlags = 0b0011

@export_group("Viaduct-Specific")
@export var FirstTileOffset : Vector2 = Vector2(-84.0, -64.0)
@export var ViaductWidth : float = 690.0

const VIEWPORT_CENTER : Vector2 = Vector2(480, 270)
const UP_TO_DIAGONAL_ANGLE = deg_to_rad(53.0)
const CW_TURN_ANGLE = deg_to_rad(74.0)
const CCW_TURN_ANGLE = deg_to_rad(106)

var DIR_NE : Vector2
var DIR_NW : Vector2
var DIR_SE : Vector2
var DIR_SW : Vector2

var possible_edges
var possible_edges_count
var _nextSpawnTick : float = 0
var _remainingTimeToNextSpawn : float = 0

@onready var _spawnedObjects : Array[Node] = []

func _enter_tree():
	DIR_NE = Vector2.UP.rotated(UP_TO_DIAGONAL_ANGLE)
	DIR_NW = Vector2.UP.rotated(-UP_TO_DIAGONAL_ANGLE)
	DIR_SE = Vector2.DOWN.rotated(-UP_TO_DIAGONAL_ANGLE)
	DIR_SW = Vector2.DOWN.rotated(UP_TO_DIAGONAL_ANGLE)
	_update_spawn_settings()

func _exit_tree():
	if MakeSpawnedDisposableOnExit:
		for so in _spawnedObjects:
			so.add_to_group("Disposable")

func set_spawn_flags(spawn_flags:int):
	SpawnFlags = spawn_flags
	_update_spawn_settings()

func _update_spawn_settings():
	possible_edges = []
	if SpawnFlags & 0b0001: possible_edges.append(0)
	if SpawnFlags & 0b0010: possible_edges.append(1)
	possible_edges_count = len(possible_edges)

func spawn(scene:PackedScene):
	if possible_edges_count == 0: return
	var spawnCoords : Vector2 = Vector2.ZERO
	
	var viewportWorldCenter = get_canvas_transform().affine_inverse() * VIEWPORT_CENTER
	var viaductRefPoint = Geometry2D.line_intersects_line(
		FirstTileOffset, DIR_NE, viewportWorldCenter, DIR_NW) 
	
	var point_north_A = viaductRefPoint + DIR_NE * 500.0
	var point_north_B = point_north_A + DIR_SE * ViaductWidth
	
	var point_south_A = viaductRefPoint - DIR_NE * 500.0
	var point_south_B = point_south_A + DIR_SE * ViaductWidth
	
	var useEdge = possible_edges[randi_range(0, possible_edges_count-1)]
	if useEdge == 0:
		# north-east edge
		spawnCoords = lerp(point_north_A, point_north_B, randf())
	elif useEdge == 1:
		# south-west edge
		spawnCoords = lerp(point_south_A, point_south_B, randf())
	var spawned = scene.instantiate()
	add_to_spawned_objects(spawned)

	spawned.global_position = spawnCoords
	Global.attach_toWorld(spawned)

func _process(delta):
#ifdef PROFILING
#	updateOffscreenSpawner(delta)
#
#func updateOffscreenSpawner(delta):
#endif
	if GameState.CurrentState == GameState.States.PlayerDied:
		return
	_remainingTimeToNextSpawn -= delta
	var rank = Global.World.get_torment_rank()
	if _remainingTimeToNextSpawn < 0:
		_remainingTimeToNextSpawn = get_spawn_interval()
		if rank >= MinRank && rank <= MaxRank:
			for i in range(get_number_of_spawns_per_interval()):
				if len(_spawnedObjects) >= get_spawn_target_count():
					if DestroyWhenTargetCountReached:
						queue_free()
					break
				spawn(SpawnScene)
	_nextSpawnTick -= delta
	
	if Lifetime > 0.0:
		Lifetime -= delta
		if Lifetime <= 0.0:
			queue_free()

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
