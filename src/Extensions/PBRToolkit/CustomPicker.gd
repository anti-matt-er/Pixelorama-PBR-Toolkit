class_name CustomPicker
extends Control


var id := -1
var previous_color := Color.WHITE


func _ready() -> void:
	Tools.color_changed.connect(_on_color_changed)
	Tools.tool_changed.connect(_on_tool_changed)
	update_color(Tools.get_assigned_color(Tools.picking_color_for))


func assign_color(color: Color, change_alpha := true) -> void:
	if color != previous_color:
		previous_color = color
		Tools.assign_color(color, Tools.picking_color_for, change_alpha)


func update_inputs_from_color(color: Color) -> void:
	pass


func update_color_from_inputs() -> void:
	pass


func update_color(color: Color) -> void:
	update_inputs_from_color(color)
	
	
func _on_color_changed(color_info: Dictionary, _button: int) -> void:
	update_color(color_info.color)


func _on_tool_changed(_tool_name: String, button: int) -> void:
	update_color(Tools.get_assigned_color(button))


func on_swatch_toggled(left: bool) -> void:
	update_color(Tools.get_assigned_color(MOUSE_BUTTON_LEFT if left else MOUSE_BUTTON_RIGHT))
