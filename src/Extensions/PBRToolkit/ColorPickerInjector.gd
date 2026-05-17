extends Node


const ColorPickerPanel := preload("res://src/UI/ColorPickers/ColorPicker.gd")

var panel: ColorPickerPanel
var picker: ColorPicker
var shapes_container: HBoxContainer
var options: Button
var switch: Button
var shape_popup_menu: PopupMenu
var custom_pickers: Dictionary[int, CustomPicker]
var last_picker_default_shape := ColorPicker.SHAPE_HSV_WHEEL


func _ready() -> void:
	await get_tree().process_frame
	
	panel = Global.control.find_child("Color Picker")
	picker = panel.color_picker
	shapes_container = panel.shapes_container
	options = panel.expand_button
	switch = panel.find_child("LeftColorButton", true, false)
	var shape_menu_button: MenuButton = picker.find_children("*", "MenuButton", true, false)[0]
	shape_popup_menu = shape_menu_button.get_popup()
	shape_popup_menu.id_pressed.connect(_switch_picker)
	last_picker_default_shape = picker.picker_shape


func add_picker(custom_picker: CustomPicker, label: String) -> int:
	shapes_container.add_sibling(custom_picker)
	custom_picker.hide()
	switch.toggled.connect(custom_picker.on_swatch_toggled)
	var id := shape_popup_menu.item_count + 1
	custom_picker.id = id
	shape_popup_menu.add_radio_check_item(label, id)
	custom_pickers[id] = custom_picker
	
	return id


func _hide_pickers() -> void:
	for custom_picker in custom_pickers.values():
		custom_picker.hide()


func _select_picker_radio(id: int) -> void:
	for i in range(shape_popup_menu.item_count):
		shape_popup_menu.set_item_checked(i, shape_popup_menu.get_item_id(i) == id)


func revert_picker() -> void:
	_hide_pickers()
	shapes_container.show()
	_select_picker_radio(last_picker_default_shape)
	panel._on_shape_popup_menu_id_pressed(last_picker_default_shape)


func _switch_picker(id: int) -> void:
	_hide_pickers()
	
	if custom_pickers.has(id):
		custom_pickers[id].show()
		shapes_container.hide()
	else:
		last_picker_default_shape = id
		shapes_container.show()
	
	_select_picker_radio(id)


func switch_picker(id: int) -> void:
	panel._on_shape_popup_menu_id_pressed(last_picker_default_shape)
	_switch_picker(id)
