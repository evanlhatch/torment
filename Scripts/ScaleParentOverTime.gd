extends Node2D

@export var Duration : float = 5
@export_exp_easing var EasingParameter : float = 1
@export var StartFromCurrentScale : bool = false
@export var StartScale : Vector2 = Vector2.ONE
@export var TargetScale : Vector2 = Vector2.ONE * 2
@export var QueueFreeParentOnComplete : bool = false
@export var StartScalingRightAway : bool = true

var _remainingTime : float
var _currentlyScaling : bool

func _enter_tree():
	_remainingTime = Duration
	_currentlyScaling = StartScalingRightAway
	if StartFromCurrentScale:
		StartScale = get_parent().scale

func getCurrentScaleVector() -> Vector2:
	var currentScaleFactor = 1.0 - _remainingTime / Duration
	currentScaleFactor = ease(currentScaleFactor, EasingParameter)
	return StartScale.lerp(TargetScale, currentScaleFactor)

func startScalingNow():
	_currentlyScaling = true
	if StartFromCurrentScale:
		StartScale = get_parent().scale

func _process(delta):
	if !_currentlyScaling:
		return
	var parent = get_parent()
	if parent == null:
		return
	if _remainingTime <= 0:
		if QueueFreeParentOnComplete:
			parent.queue_free()
		return
	_remainingTime -= delta
	if _remainingTime < 0: _remainingTime = 0

	parent.scale = getCurrentScaleVector()
