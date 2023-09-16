extends GameObjectComponent

class_name EffectBase

# HAS to be overridden by the Effect
func get_effectID() -> String:
	printerr("When extending EffectBase, the get_effectID function has to be overridden!")
	return "BASE"

# should be overridden by the Effect to decide what
# has to be done when an additional effect of the same
# type is applied
func add_additional_effect(_additionalEffectScene:EffectBase) -> void:
	pass
