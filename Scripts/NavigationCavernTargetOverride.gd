extends GameObjectComponent

class_name NavigationCavernTargetOverride

var _has_override : bool = false
var _override_position : Vector2

func _enter_tree():
	if Global.World.NavigationCaverns.world_has_navigation_caverns():
		initGameObjectComponent()
		Global.World.NavigationCaverns.RegisterNavigationAgent(self)
	else:
		queue_free()

func _exit_tree():
	if Global.World.NavigationCaverns.world_has_navigation_caverns():
		Global.World.NavigationCaverns.UnregisterNavigationAgent(self)

func has_override_target_position() -> bool:
	return _has_override

func get_override_target_position() -> Vector2:
	return _override_position
