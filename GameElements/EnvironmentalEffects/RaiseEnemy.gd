extends Node

@export var RaiseEffectScene : PackedScene
@export var SpawnedObjectScene : PackedScene

signal object_spawned(spawned_object:Node)

func raise(pos:Vector2, dir:Vector2):
	var raise_effect = RaiseEffectScene.instantiate()
	raise_effect.global_position = pos
	Global.attach_toWorld(raise_effect)
	raise_effect.play_effect(dir)
	raise_effect.connect("animation_finished", spawn_object.bind(pos))
	raise_effect.connect("animation_looped", spawn_object.bind(pos))


func spawn_object(pos:Vector2):
	var spawned = SpawnedObjectScene.instantiate()
	spawned.global_position = pos
	Global.attach_toWorld(spawned)
	object_spawned.emit(spawned)
	queue_free()
