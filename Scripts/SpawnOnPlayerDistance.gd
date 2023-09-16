extends Node2D

@export var TriggerOnDistance : float = 50
@export var SpawnScene : PackedScene
@export var SpawnRadius : float = 50

@export_group("Effect Settings")
@export var SpwanEffectScene : PackedScene
@export var SpawnEffectScale : Vector2 = Vector2.ONE
@export var SpawnSoundEffect : AudioFXResource

var _playerPositionProvider : Node

func _ready():
	if not Global.is_world_ready():
		await Global.WorldReady
	_playerPositionProvider = Global.World.Player.getChildNodeWithMethod("get_worldPosition")


func _process(_delta):
	if _playerPositionProvider == null or _playerPositionProvider.is_queued_for_deletion():
		_playerPositionProvider = null
		return
	var playerWorldPos : Vector2 = _playerPositionProvider.get_worldPosition()
	var distSquared : float = playerWorldPos.distance_squared_to(global_position)
	if distSquared < TriggerOnDistance * TriggerOnDistance:
		var spawnedInstance : Node2D = SpawnScene.instantiate()
		spawnedInstance.global_position = global_position + Vector2.from_angle(randf_range(0, 2*PI)) * randf_range(0, SpawnRadius)
		Global.attach_toWorld(spawnedInstance)
		if SpwanEffectScene != null:
			var effect : Node2D = SpwanEffectScene.instantiate()
			effect.global_position = spawnedInstance.global_position
			Global.attach_toWorld(effect)
			effect.scale = SpawnEffectScale
			if SpawnSoundEffect != null:
				FxAudioPlayer.play_sound_2D(SpawnSoundEffect, effect.global_position, false, false, -2.0)
		queue_free()
