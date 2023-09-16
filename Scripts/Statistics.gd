extends Node

const WEAPON_INDEX_NAMES = {
	1: "Swordsman Weapon",
	2: "Archer Weapon",
	3: "Exterminator Weapon",
	4: "Cleric Weapon",
	5: "Warlock Weapon",
	6: "Sorceress Weapon",
	7: "Shieldmaiden Weapon",
	8: "Shieldmaiden Shield",
	99: "Burn Damage",
	98: "Electrify Damage",
	89: "Fragile Effect",
	88: "Affliction Effect",
	87: "Slow Effect"
}

var damage_taken : int = 0
var damage_dealt = {}
var damage_dealt_crit = {}
var damage_sum_10 = {}
var damage_sum_30 = {}
var hits_taken : int = 0
var hits_dealt = {}
var hits_dealt_crit = {}
var hits_sum_10 = {}
var hits_sum_30 = {}


#ifdef USE_STATISTICS
#func _ready():
#	if not ProjectSettings.get_setting("halls_of_torment/development/use_statistics"): return
#	Global.connect("WorldReady", _on_session_started)
#	GameState.connect("StateChanged", _on_game_state_changed)
#endif


func _on_session_started():
	reset()
	Global.World.connect("SecondPassed", _on_second_passed)


func _on_session_end():
	pass


func _on_game_state_changed(newState, _oldState):
	if newState == GameState.States.Overworld:
		_on_session_end()

func _on_second_passed(_current_time):
	if Global.World != null:
		for entry in damage_sum_10:
			damage_sum_10[entry] -= damage_sum_10[entry] / 10.0
			damage_sum_30[entry] -= damage_sum_30[entry] / 30.0
			hits_sum_10[entry] -= hits_sum_10[entry] / 10.0
			hits_sum_30[entry] -= hits_sum_30[entry] / 30.0

func reset():
	damage_taken = 0
	damage_dealt = {}
	damage_dealt_crit = {}
	damage_sum_10 = {}
	damage_sum_30 = {}
	hits_taken = 0
	hits_dealt = {}
	hits_dealt_crit = {}
	hits_sum_10 = {}
	hits_sum_30 = {}


func add_damage_event(
	sourceNode:GameObject,
	targetNode:GameObject,
	damageAmount:int,
	isCritical:bool,
	weapon_index:int):
	#if not ProjectSettings.get_setting("halls_of_torment/development/use_statistics"): return

	var actualSource = sourceNode
	if sourceNode != null:
		var rootSourceProvider = sourceNode.getChildNodeWithMethod("get_rootSourceGameObject")
		if rootSourceProvider != null:
			actualSource = rootSourceProvider.get_rootSourceGameObject()

	if targetNode != null and targetNode.is_in_group("Player"):
		damage_taken += damageAmount
		hits_taken += 1
	elif actualSource != null and actualSource.is_in_group("FromPlayer"):
		add_source(weapon_index)
		if isCritical:
			damage_dealt_crit[weapon_index] += damageAmount
			hits_dealt_crit[weapon_index] += 1
		damage_dealt[weapon_index] += damageAmount
		hits_dealt[weapon_index] += 1
		damage_sum_10[weapon_index] += damageAmount
		damage_sum_30[weapon_index] += damageAmount
		hits_sum_10[weapon_index] += 1
		hits_sum_30[weapon_index] += 1
	else:
		add_source(0)
		if isCritical:
			damage_dealt_crit[0] += damageAmount
			hits_dealt_crit[0] += 1
		damage_dealt[0] += damageAmount
		hits_dealt[0] += 1
		damage_sum_10[0] += damageAmount
		damage_sum_30[0] += damageAmount
		hits_sum_10[0] += 1
		hits_sum_30[0] += 1


func add_source(weapon_index:int):
	if not damage_dealt.has(weapon_index):
		damage_dealt[weapon_index] = 0
		damage_dealt_crit[weapon_index] = 0
		hits_dealt[weapon_index] = 0
		hits_dealt_crit[weapon_index] = 0
		damage_sum_10[weapon_index] = 0
		damage_sum_30[weapon_index] = 0
		hits_sum_10[weapon_index] = 0
		hits_sum_30[weapon_index] = 0
