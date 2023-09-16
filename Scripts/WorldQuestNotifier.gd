extends Node

@export var UpdateCadence : float = 1.0
var _timePassed : float = 0.0
var _stats : Dictionary = {}
var _worldReady : bool = false

func _ready():
	await Global.WorldReady
	_worldReady = true
	_stats = {}
	_timePassed = 0


func _process(delta):
	if not _worldReady:
		return
	_timePassed += delta
	if _timePassed > UpdateCadence:
		_timePassed = 0
		_updateDamageStats()


func _updateDamageStats():
	var allDamagingItems : Array = Stats.GetDamagingWeaponIndices()
	for weapon_index in allDamagingItems:
		if weapon_index <= 0:
			continue
		if not _stats.has(weapon_index):
			Global.QuestPool.notify_damage_from_stats(Stats.GetTotalDamageOfWeapon(weapon_index), weapon_index)
		else:
			Global.QuestPool.notify_damage_from_stats(Stats.GetTotalDamageOfWeapon(weapon_index) - _stats[weapon_index], weapon_index)
		_stats[weapon_index] = Stats.GetTotalDamageOfWeapon(weapon_index)
	
