@tool
extends Resource
class_name WeightedScenePool

@export var Scenes : Array[PackedScene]
@export var Weights : Array[float]


func pick_random() -> PackedScene:
	var total_weight = 0.0
	for weight in Weights:
		total_weight += weight
	var r = randf() * total_weight
	var i = 0
	while r > Weights[i]:
		r -= Weights[i]
		i += 1
	return Scenes[i]