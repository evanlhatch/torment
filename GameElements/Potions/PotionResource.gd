extends Resource
class_name PotionResource

enum PotionTypeEnum {
	RerollPotion,
	BanishPotion,
	MemoryPotion,
	DoublePotion,
	AbilityRerollPotion,
	ItemChestRerollPotion,
	ItemChestAbsorbEffectsPotion
}

@export var PotionType : PotionTypeEnum
@export var PotionName : String
@export_multiline var Description : String
@export var SpriteAnimation : Resource
@export var AmountProfileFieldName : String
@export var MaxAmount : int
@export var AmountIncreasedByItem : String
@export var Ingredients : Array[Resource]
@export var ItemScene : PackedScene


func get_total_amount_of_acquired_bottles() -> int:
	var unlocked_count : int = 0
	if Global.PlayerProfile.has(AmountProfileFieldName):
		unlocked_count = Global.PlayerProfile[AmountProfileFieldName]
	for itemID in Global.PlayerProfile.ItemsInWell:
		var nonUniqueItemID : String = Item.remove_item_name_uniqueness(itemID)
		if AmountIncreasedByItem == nonUniqueItemID:
			unlocked_count += 1
	return unlocked_count

func are_all_ingredients_unlocked() -> bool:
	for i in Ingredients:
		if not Global.PlayerProfile.Ingredients.has(int(i.IngredientType)):
			return false
	return true
