extends Node2D

@export var DistanceFromScreenEdge = 100
@export var SpawnScene : PackedScene
@export var SpawnCount : int = 1

func _ready():
	if not Global.is_world_ready():
		await Global.WorldReady
	Global.World.FinaleReached.connect(_on_finale)

func _on_finale():
	await get_tree().process_frame
	for i in SpawnCount:
		spawn(SpawnScene)
	queue_free()


func spawn(scene:PackedScene):
	var spawnCoords : Vector2 = Vector2.ZERO
	var screenspace2worldspace = get_canvas_transform().affine_inverse()
	var viewportSize = get_viewport().get_visible_rect().size
	# remove borders left and right, so rectangle fits more or less visible area
	viewportSize.x -= 300
	var useEdge = randi_range(0, 3)
	if useEdge == 0:
		# top edge
		spawnCoords.x = randf_range(0, viewportSize.x) + 150
		spawnCoords.y = 0
	elif useEdge == 1:
		# bottom edge
		spawnCoords.x = randf_range(0, viewportSize.x)  + 150
		spawnCoords.y = viewportSize.y
	elif useEdge == 2:
		# left edge
		spawnCoords.x = 150
		spawnCoords.y = randf_range(0, viewportSize.y)
	else:
		# right edge
		spawnCoords.x = viewportSize.x + 150
		spawnCoords.y = randf_range(0, viewportSize.y)
	var spawned = scene.instantiate()

	MusicPlayer.play_boss_music()

	var spawnPos = screenspace2worldspace * spawnCoords
	var middleScreenPos = screenspace2worldspace * (viewportSize / 2.0)
	var spawnOffset = (spawnPos - middleScreenPos).normalized() * DistanceFromScreenEdge
	spawned.global_position = spawnPos + spawnOffset
	Global.attach_toWorld(spawned)
