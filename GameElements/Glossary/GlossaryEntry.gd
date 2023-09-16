@tool
extends Resource
class_name GlossaryEntry

@export var Keyword : String = "keyword"
@export var Name : String = "Attribute Name"
@export_multiline var Description : String = "Description"

func _init():
	Name = "Attribute Name"
	Description = "Description"
