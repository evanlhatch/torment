extends Node2D

signal Collected(collector:GameObject)

var _mover : Node2D
var _collectedByCollector : GameObject

func _ready():
	get_parent().connectToSignal("OnArrived", onArrived)
	_mover = get_parent().getChildNodeWithMethod("start_motion_with_target")
	Global.World.Collectables.RegisterCollectable(get_parent())

func collect(collector : Node2D):
	Global.World.Collectables.UnregisterCollectable(get_parent())
	if _mover:
		_mover.start_motion_with_target(
			collector,
			global_position - collector.global_position)
	_collectedByCollector = Global.get_gameObject_in_parents(collector)

	# remove the locator, so that we won't be bothered again!
	for child in get_children():
		if child is Locator:
			child.queue_free()

func onArrived():
	emit_signal("Collected", _collectedByCollector)
