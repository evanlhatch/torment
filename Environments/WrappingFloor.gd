extends Node2D

@export var PatchWidth : int
@export var PatchHeight : int

@onready var NorthPatches : Array[Node2D] = []
@onready var SouthPatches : Array[Node2D] = []
@onready var EastPatches : Array[Node2D] = []
@onready var WestPatches : Array[Node2D] = []

signal WrappingFloorWrapped

func _ready():
	NorthPatches.append($floor_patch_NW)
	NorthPatches.append($floor_patch_NE)

	SouthPatches.append($floor_patch_SE)
	SouthPatches.append($floor_patch_SW)

	EastPatches.append($floor_patch_NE)
	EastPatches.append($floor_patch_SE)

	WestPatches.append($floor_patch_NW)
	WestPatches.append($floor_patch_SW)

	for child in get_children():
		for grandChild in child.get_children():
			if grandChild.has_signal("NorthLimitReached"):
				grandChild.connect("NorthLimitReached", on_north_limit_reached)
			if grandChild.has_signal("SouthLimitReached"):
				grandChild.connect("SouthLimitReached", on_south_limit_reached)
			if grandChild.has_signal("EastLimitReached"):
				grandChild.connect("EastLimitReached", on_east_limit_reached)
			if grandChild.has_signal("WestLimitReached"):
				grandChild.connect("WestLimitReached", on_west_limit_reached)


func on_north_limit_reached(floorPatch:Node2D):
	if is_north_patch(floorPatch):
		move_south_patches_to_north()

func on_south_limit_reached(floorPatch:Node2D):
	if is_south_patch(floorPatch):
		move_north_patches_to_south()

func on_east_limit_reached(floorPatch:Node2D):
	if is_east_patch(floorPatch):
		move_west_patches_to_east()

func on_west_limit_reached(floorPatch:Node2D):
	if is_west_patch(floorPatch):
		move_east_patches_to_west()

func move_south_patches_to_north():
	for p in SouthPatches:
		p.position.y -= (PatchHeight * 2)
		call_deferred("notify_patch_moved", p)
	var temp = SouthPatches
	SouthPatches = NorthPatches
	NorthPatches = temp
	WrappingFloorWrapped.emit()

func move_north_patches_to_south():
	for p in NorthPatches:
		p.position.y += (PatchHeight * 2)
		call_deferred("notify_patch_moved", p)
	var temp = NorthPatches
	NorthPatches = SouthPatches
	SouthPatches = temp
	WrappingFloorWrapped.emit()

func move_east_patches_to_west():
	for p in EastPatches:
		p.position.x -= (PatchWidth * 2)
		call_deferred("notify_patch_moved", p)
	var temp = EastPatches
	EastPatches = WestPatches
	WestPatches = temp
	WrappingFloorWrapped.emit()

func move_west_patches_to_east():
	for p in WestPatches:
		p.position.x += (PatchWidth * 2)
		call_deferred("notify_patch_moved", p)
	var temp = WestPatches
	WestPatches = EastPatches
	EastPatches = temp
	WrappingFloorWrapped.emit()

func is_north_patch(floorPatch:Node2D):
	if NorthPatches:
		return NorthPatches.has(floorPatch)
	return false

func is_south_patch(floorPatch:Node2D):
	if SouthPatches:
		return SouthPatches.has(floorPatch)
	return false

func is_east_patch(floorPatch:Node2D):
	if EastPatches:
		return EastPatches.has(floorPatch)
	return false

func is_west_patch(floorPatch:Node2D):
	if WestPatches:
		return WestPatches.has(floorPatch)
	return false

func notify_patch_moved(patch:Node2D):
	patch.emit_signal("PatchMoved")
