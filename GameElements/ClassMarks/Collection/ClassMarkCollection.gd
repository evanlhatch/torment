extends Resource
class_name ClassMarkCollection

@export var EmptyMark : ClassMarkResource
@export var ClassMarks : Array[ClassMarkResource]

func get_mark_via_activatedTag(activatedTag:String) -> ClassMarkResource:
	for m in ClassMarks:
		if m.ActivatesTag == activatedTag:
			return m
	return EmptyMark
