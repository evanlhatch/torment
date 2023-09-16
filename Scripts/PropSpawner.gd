extends Node2D

## the scene instantiated by this spawner
@export var SpawnedObjectScene : PackedScene
@export var OffscreenTimeToSpawn : float = 120
@export var occupiedCheckRadius : float = 1

var _isOnScreen : bool
var _timer : float
var _spawnedObject : Node

func _ready():
	$VisibleOnScreenNotifier2D.connect("screen_entered", _on_screen_entered)
	$VisibleOnScreenNotifier2D.connect("screen_exited", _on_screen_exited)
	Global.connect("WorldReady", _on_world_ready)


func _on_world_ready():
	var parent = get_parent()
	if parent.has_signal("PatchMoved"):
		parent.connect("PatchMoved", patchMoved)
	spawn()


func _process(delta):
#ifdef PROFILING
#	updatePropSpawner(delta)
#
#func updatePropSpawner(delta):
#endif
	if not _isOnScreen and _timer > 0:
		_timer -= delta
		if _timer <= 0:
			spawn()

func patchMoved():
	# remove the spawned object when it is too far away 
	if is_instance_valid(_spawnedObject) and not _spawnedObject.is_queued_for_deletion():
		var playerPos : Vector2 = Global.World.get_player_position()
		if playerPos.distance_squared_to(_spawnedObject.global_position) > 2000 * 2000:
			_spawnedObject.queue_free()
			_spawnedObject = null
	
	spawn()

func spawn():
	if check_if_occupied():
		return
	if Global.World != null and Global.World.is_game_time_out():
		return
	var spawnedObjectInstance = SpawnedObjectScene.instantiate()
	spawnedObjectInstance.global_position = global_position
	Global.attach_toWorld(spawnedObjectInstance)
	_spawnedObject = spawnedObjectInstance

func _on_screen_entered():
	_isOnScreen = true
	
func _on_screen_exited():
	_isOnScreen = false
	_timer = OffscreenTimeToSpawn
	if _spawnedObject != null and not is_instance_valid(_spawnedObject):
		_spawnedObject = null

func check_if_occupied() -> bool:
	if _spawnedObject != null and is_instance_valid(_spawnedObject):
		return true
	return Global.World.Collectables.check_for_collectable_at_location(global_position, occupiedCheckRadius)
