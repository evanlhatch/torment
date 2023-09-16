extends GameObjectComponent

@export_enum("OnKilled", "OnEndOfLife") var OnEvent : int = 0
@export var SpawnedObjects : Array[PackedScene]
@export var SpawnProbabilities : Array[float]
@export var SpawnPosOffset : Vector2

@export_group("Bottle Specific Settings")
@export var CupbearerQuestID : String = "q_Viaduct_Cupbearer_1"
@export var CheckIfBottleAlreadySpawned : bool = true
@export var NoteSpawnInWorld : bool = true

@export_group("Spawn Position Modification")
@export var UseOffscreenPositioner : bool = false
@export var ViaductDirection : Vector2 = Vector2(84, -64)
@export var CenterPosOffset : Vector2 = Vector2(176.0, 136.0)
@export var MaxDistanceToCenter : float = 300.0

var _delay_timer : Timer
var _spawn_pos : Vector2
var _spawn_origin : Node


func _ready():
	initGameObjectComponent()
	if _gameObject == null:
		return

	if not Global.is_world_ready(): await  Global.WorldReady
	# Don't spawn a bottle chest if a bottle chest has been already spawned in this run.
	if CheckIfBottleAlreadySpawned and Global.World.BottleSpawnedInThisWorld: queue_free()
	# Don't spawn a bottle chest if cupbearer hasn't been unlocked, yet.
	if not Global.QuestPool.is_quest_complete(CupbearerQuestID): queue_free()
	# If there aren't any bottles left to spawn abort.
	if not are_bottles_remaining(): queue_free()

	if OnEvent == 0:
		_gameObject.connectToSignal("Killed", _on_killed)
	elif OnEvent == 1:
		_gameObject.connectToSignal("OnEndOfLife", _on_killed.bind(null))


func _on_killed(killedBy : Node):
	var dir_pos_offset = Vector2.ZERO
	_spawn_pos = get_gameobjectWorldPosition() + SpawnPosOffset + dir_pos_offset
	if UseOffscreenPositioner:
		_spawn_pos = Global.World.OffscreenPositioner.get_nearest_valid_position(_spawn_pos)
	spawn_object()
	queue_free()


func spawn_object():
	var spawnedObject = null
	for i in len(SpawnedObjects):
		if randf() <= SpawnProbabilities[i]:
			spawnedObject = SpawnedObjects[i]
			break
	if spawnedObject == null:
		return

	var obj = spawnedObject.instantiate()
	obj.global_position = _spawn_pos
	Global.attach_toWorld(obj)
	if NoteSpawnInWorld:
		Global.World.BottleSpawnedInThisWorld = true


func get_viaduct_clamped_position(pos:Vector2) -> Vector2:
	var center_point = Geometry2D.get_closest_point_to_segment_uncapped(
		pos, CenterPosOffset + ViaductDirection, CenterPosOffset - ViaductDirection)
	if center_point.distance_to(pos) <= MaxDistanceToCenter:
		return pos
	var dir_ortho = ViaductDirection.normalized().rotated(PI * 0.5)
	return Geometry2D.get_closest_point_to_segment(
		pos,
		center_point + dir_ortho * MaxDistanceToCenter,
		center_point - dir_ortho * MaxDistanceToCenter)


func are_bottles_remaining() -> bool:
	for p in Global.PotionsPool.PotionResources:
		if not Global.PlayerProfile.has(p.AmountProfileFieldName): continue
		var unlocked_count : int = p.get_total_amount_of_acquired_bottles()
		var remaining_bottles : int = maxi(p.MaxAmount - unlocked_count, 0)
		if remaining_bottles > 0: return true
	return false
