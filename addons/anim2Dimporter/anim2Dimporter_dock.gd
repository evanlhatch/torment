@tool
extends Control

func get_select_data_btn() -> Button:
	return $Margin/VBox/data/BTN_selectJSON

func get_clear_data_btn() -> Button:
	return $Margin/VBox/data/BTN_clearJSON	

func get_import_btn() -> Button:
	return $Margin/VBox/BTN_import

func set_data_name(dataName : String):
	$Margin/VBox/data/LBL_selectJSON.text = dataName
	$Margin/VBox/data/LBL_selectJSON.hint_tooltip = dataName

func set_import_button_enabled(enabled : bool):
	$Margin/VBox/BTN_import.disabled = not enabled
