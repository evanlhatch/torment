@tool
extends Control

func get_select_sheet_btn() -> Button:
	return $Margin/VBox/sheet/BTN_selectSheet

func get_select_data_btn() -> Button:
	return $Margin/VBox/data/BTN_selectJSON

func get_select_out_btn() -> Button:
	return $Margin/VBox/out/BTN_select_out

func get_import_btn() -> Button:
	return $Margin/VBox/BTN_import

func set_sheet_name(sheetName : String):
	$Margin/VBox/sheet/LBL_selectSheet.text = sheetName
	$Margin/VBox/sheet/LBL_selectSheet.hint_tooltip = sheetName

func set_data_name(dataName : String):
	$Margin/VBox/data/LBL_selectJSON.text = dataName
	$Margin/VBox/data/LBL_selectJSON.hint_tooltip = dataName

func set_out_name(outName : String):
	$Margin/VBox/out/LBL_out.text = outName
	$Margin/VBox/out/LBL_out.hint_tooltip = outName

func set_import_button_enabled(enabled : bool):
	$Margin/VBox/BTN_import.disabled = not enabled
