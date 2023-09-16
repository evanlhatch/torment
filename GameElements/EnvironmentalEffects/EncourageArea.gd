extends Node2D

@export var Radius : float = 50
@export var HitLocatorPool : String = "Enemies"
@export var ConfidenceValue : float = 3.0
@export var Lifetime : float = 1.0

func activate():
	$Particles.emitting = true
	await get_tree().create_timer(0.1, false).timeout
	var hits = Global.World.Locators.get_gameobjects_in_circle(
				HitLocatorPool, global_position, Radius)
	for gameObject in hits:
		var confidence_component = gameObject.getChildNodeWithMethod("set_confidence")
		if confidence_component:
			confidence_component.set_confidence(ConfidenceValue)
			
	$Timer.start(Lifetime)
	await $Timer.timeout
	queue_free()
