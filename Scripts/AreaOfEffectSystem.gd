extends RefCounted

class_name AreaOfEffectSystem

var _areas : Array[AreaOfEffect]

func RegisterAreaOfEffect(area : AreaOfEffect) -> void:
	_areas.append(area)

func UnregisterAreaOfEffect(area : AreaOfEffect) -> void:
	_areas.erase(area)

func updateAreaOfEffect(delta):
	for area in _areas:
		area._remainingTimeToNextTrigger -= delta
		if area.TriggerEverySeconds <= 0 or area._remainingTimeToNextTrigger < 0:
			if area._is_harmless or area._modifiedAttackSpeed.Value() == 0:
				continue
			area._remainingTimeToNextTrigger += 1.0 / area._modifiedAttackSpeed.Value()
			var position : Vector2 = area._positionProvider.get_worldPosition()
			var hits : Array
			if area.UseModifiedArea:
				hits = Global.World.Locators.get_gameobjects_in_circle(area.LocatorPoolName, position, area.get_modifiedRadius())
			else:
				hits = Global.World.Locators.get_gameobjects_in_circle(area.LocatorPoolName, position, area.Radius)

			for hitObj in hits:
				if area.ProbabilityToApply < 1 and randf() > area.ProbabilityToApply:
					continue
				if area._modifiedDamage.Value() > 0:
					var healthComp = hitObj.getChildNodeWithMethod("applyDamage")
					if healthComp:
						var damageReturn = healthComp.applyDamage(area._modifiedDamage.Value(), area._gameObject, false, area._weapon_index)
						area.DamageApplied.emit(area.DamageCategories, area._modifiedDamage.Value(), damageReturn, hitObj, false)
				if area.ApplyNode:
					var spawnedNode = area.ApplyNode.instantiate()
					hitObj.add_child(spawnedNode)
					if spawnedNode.has_method("set_modifierSource"):
						spawnedNode.set_modifierSource(area._gameObject)
