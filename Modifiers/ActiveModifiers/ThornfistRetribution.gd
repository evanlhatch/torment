extends GameObjectComponent

@export var DamageCategories : Array[String]
@export var CritMultiplier : float = 1.0

@export_group("internal state")
@export var _weapon_index : int = -1

signal DamageApplied(damageCategories:Array[String], damageAmount:float, applyReturn:Array, targetNode:GameObject, critical:bool)

var _damageDealerComponent

func _enter_tree():
	initGameObjectComponent()
	if _gameObject:
		_gameObject.connectToSignal("ReceivedDamage", _on_damage_received)
		_damageDealerComponent = _gameObject.getChildNodeWithMethod("get_totalDamage")
	else:
		var parent = get_parent()
		if parent and parent is Item:
			_weapon_index = parent.WeaponIndex


func _exit_tree():
	if _gameObject != null && !_gameObject.is_queued_for_deletion():
		_gameObject.disconnectFromSignal("ReceivedDamage", _on_damage_received)
	_gameObject = null


func _on_damage_received(_amount:int, byNode:Node, _attacker_weapon_index:int):
	if byNode == _gameObject:
		return
	if _damageDealerComponent and byNode is GameObject:
		var damageSourceHealth = byNode.getChildNodeWithMethod("applyDamage")
		if damageSourceHealth:
			var damage = _damageDealerComponent.get_totalDamage()
			var crit_bonus = 1.0
			if _damageDealerComponent.get_totalCritBonus != null:
				crit_bonus = _damageDealerComponent.get_totalCritBonus()
			var damageReturn = damageSourceHealth.applyDamage(
				damage + damage * crit_bonus * CritMultiplier,
				_gameObject,
				true,
				_weapon_index)
			DamageApplied.emit(DamageCategories, damage, damageReturn, byNode, true)
