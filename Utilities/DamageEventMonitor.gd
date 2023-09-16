extends Node

var _damage_events_this_frame : int

func _enter_tree():
	var self_var = self
	Performance.add_custom_monitor("HoT/Damage Events", Callable(self_var, "monitor_call"), [1, 2])
	await Global.WorldReady
	Global.World.DamageEvent.connect(_on_damage_event)

func _exit_tree():
	Performance.remove_custom_monitor("HoT/Damage Events")

func _on_damage_event(_targetObject, _sourceObject, _damageAmount, _totalDamage):
	_damage_events_this_frame += 1

func monitor_call(from, to) -> float:
	var count = _damage_events_this_frame
	_damage_events_this_frame = 0
	return count
