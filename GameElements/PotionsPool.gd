extends Node

@export var PotionResources : Array[PotionResource]

func get_potion_for_item(itemID:String) -> PotionResource:
	for potion in PotionResources:
		if potion.AmountIncreasedByItem == itemID:
			return potion
	return null

func get_potion_by_type_enum(potionType:PotionResource.PotionTypeEnum) -> PotionResource:
	for potion in PotionResources:
		if potion.PotionType == potionType:
			return potion
	return null
