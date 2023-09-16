extends Resource
class_name CharacterInfoResource

@export var CharacterName : String
@export_multiline var CharacterDescription : String

@export_group("Main Weapon")
@export var HasPrimaryWeapon : bool = true
@export_multiline var WeaponDescription : String
@export var WeaponIcon : Texture2D

@export_group("Secondary Weapon")
@export var HasSecondaryWeapon : bool
@export_multiline var SecondWeaponDescription : String
@export var SecondWeaponIcon : Texture2D
