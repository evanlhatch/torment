extends Node2D

@export var SpawnScenes : Array[PackedScene]
@export var MinSpawnRadius : float = 280
@export var MaxSpawnRadius : float = 350
@export var MinSpawnAngle : float = 0.0
@export var MaxSpawnAngle : float = 6.28319
@export var SpawnDuration : float = 3
@export var SpawnInterval : float = 0.2
@export var SpawnCountPerInterval : int = 3

@export_group("Effect Settings")
@export var SpwanEffectScene : PackedScene
@export var SpawnEffectScale : Vector2 = Vector2.ONE
@export var SpawnSoundEffect : AudioFXResource

var _timer : Timer

func _ready():
	if not Global.is_world_ready():
		await Global.WorldReady
	_timer = Timer.new()
	add_child(_timer)
	spawn_routine()


func spawn_routine():
	var remaining_duration : float = SpawnDuration
	while remaining_duration > 0.0:
		for _i in SpawnCountPerInterval:
			var spawnedInstance : Node2D = SpawnScenes.pick_random().instantiate()
			spawnedInstance.global_position = global_position + (
				Vector2.from_angle(randf_range(MinSpawnAngle, MaxSpawnAngle)) *
					randf_range(MinSpawnRadius, MaxSpawnRadius))
			Global.attach_toWorld(spawnedInstance)
			if SpwanEffectScene != null:
				var effect : Node2D = SpwanEffectScene.instantiate()
				effect.global_position = spawnedInstance.global_position
				Global.attach_toWorld(effect)
				effect.scale = SpawnEffectScale
				if SpawnSoundEffect != null:
					FxAudioPlayer.play_sound_2D(SpawnSoundEffect, effect.global_position, false, false, -2.0)
		remaining_duration -= SpawnInterval
		_timer.start(SpawnInterval); await _timer.timeout
	#queue_free()
