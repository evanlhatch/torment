@tool
extends Resource
class_name Glossary

@export var Entries : Array[Resource] = []

func _init():
	Entries = []

func get_entry_for_keyword(keyword:String) -> Resource:
	for e in Entries:
		if e.Keyword == keyword:
			return e
	return null
