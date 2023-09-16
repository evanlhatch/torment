extends Node

@export_enum("Hit", "Killed", "Blocked", "Collected", "On Ready", "OnEndOfLife") var ReactToSignal : int
@export_enum("2D", "Mono") var PlayerType : int
@export var AudioFX : AudioFXResource
@export var PlayWhenPaused : bool = false
@export var TopPriority : bool = false
@export var VolumeDB : float

var _positionProvider : Node

func _ready():
	var gameObject : GameObject = Global.get_gameObject_in_parents(self)
	if gameObject == null: return
	_positionProvider = gameObject.getChildNodeWithMethod("get_worldPosition")
	if _positionProvider == null: return
	match ReactToSignal:
		0: gameObject.connectToSignal("ReceivedDamage", _on_received_damage)
		1:
			gameObject.connectToSignal("Killed", _on_killed)
			gameObject.connectToSignal("Instakilled", _on_killed)
		2: gameObject.connectToSignal("BlockedDamage", _on_blocked)
		3: gameObject.connectToSignal("Collected", _on_collected)
		4: _play()
		5: gameObject.connectToSignal("OnEndOfLife", _play)


func _play():
	if AudioFX == null:
		var gameObject : GameObject = Global.get_gameObject_in_parents(self)
		printerr("SoundTrigger is missing its AudioFX! (gameobject: %s)"%gameObject)
		return
	if PlayerType == 0:
		FxAudioPlayer.play_sound_2D(
			AudioFX,
			_positionProvider.get_worldPosition(),
			PlayWhenPaused,
			TopPriority,
			VolumeDB)
	elif PlayerType == 1:
		FxAudioPlayer.play_sound_mono(
			AudioFX,
			PlayWhenPaused,
			TopPriority,
			VolumeDB)

func _on_received_damage(_amount:int, _byNode:Node, _weapon_index:int):
	_play()


func _on_killed(_by_node):
	_play()


func _on_blocked(_amount:int):
	_play()


func _on_collected(_by_node):
	_play()
