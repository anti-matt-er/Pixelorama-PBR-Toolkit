extends Node


const EXPORT_EXTENSION_SCRIPT: Script = preload("res://src/Extensions/PBRToolkit/PBRExportExtension.gd")

var original_export_script: Script
var preview_panel: PBRPreviewContainer
var original_project_layers: Array[BaseLayer]
var original_project_frames: Array[Frame]
var dialog: AcceptDialog
var dialog_layers_option_button: OptionButton
var dialog_layers_container: HBoxContainer
var dialog_options_container: GridContainer
var dialog_split_layers_checkbox: CheckBox
var dialog_pbr_label: Label
var dialog_pbr_container: HBoxContainer
var dialog_pbr_checkbox: CheckBox
var dialog_pbr_orm_checkbox: CheckBox
var previously_split_layers := false
var pbr_enabled := false
var orm_enabled := false


func _init(preview: PBRPreviewContainer) -> void:
	preview_panel = preview


func _enter_tree() -> void:
	Global.export_dialog.about_to_preview.connect(on_preview)
	original_export_script = Export.get_script()
	RuntimeScriptExtender.extend(Export, EXPORT_EXTENSION_SCRIPT)
	setup_dialog_ui()


func _exit_tree() -> void:
	var export_script: Script = Export.get_script()
	RuntimeScriptExtender.extend(Export, original_export_script)
	restore_dialog_ui()


func setup_dialog_ui() -> void:	
	dialog = Global.export_dialog
	
	dialog_layers_option_button = dialog.get_node("%Layers")
	dialog_layers_container = dialog_layers_option_button.get_parent()
	dialog_options_container = dialog_layers_container.get_parent()
	dialog_split_layers_checkbox = dialog_layers_container.get_node("SplitLayers")
	
	previously_split_layers = dialog_split_layers_checkbox.button_pressed
	dialog_pbr_label = Label.new()
	dialog_pbr_label.text = "PBR"
	dialog_layers_container.add_sibling(dialog_pbr_label)
	dialog_pbr_container = HBoxContainer.new()
	dialog_pbr_label.add_sibling(dialog_pbr_container)
	dialog_pbr_checkbox = CheckBox.new()
	dialog_pbr_checkbox.text = "Export PBR layers"
	dialog_pbr_checkbox.toggled.connect(toggle_pbr)
	dialog_pbr_container.add_child(dialog_pbr_checkbox)
	dialog_pbr_orm_checkbox = CheckBox.new()
	dialog_pbr_orm_checkbox.text = "Export ORM texture"
	dialog_pbr_orm_checkbox.toggled.connect(toggle_orm)
	dialog_pbr_orm_checkbox.disabled = true
	dialog_pbr_container.add_child(dialog_pbr_orm_checkbox)


func restore_dialog_ui() -> void:
	dialog_split_layers_checkbox.button_pressed = previously_split_layers
	dialog_pbr_label.queue_free()
	dialog_pbr_checkbox.queue_free()
	dialog_pbr_orm_checkbox.queue_free()
	dialog_pbr_container.queue_free()


func toggle_pbr(value: bool) -> void:
	if pbr_enabled == value:
		return
	
	pbr_enabled = value
	if pbr_enabled:
		previously_split_layers = dialog_split_layers_checkbox.button_pressed
		dialog_split_layers_checkbox.button_pressed = true
		dialog_split_layers_checkbox.disabled = true
		dialog_pbr_orm_checkbox.disabled = false
	else:
		dialog_split_layers_checkbox.button_pressed = previously_split_layers
		dialog_split_layers_checkbox.disabled = false
		dialog_pbr_orm_checkbox.disabled = true
	
	Export.cache_blended_frames()
	Export.process_data()
	dialog.set_preview()


func toggle_orm(value: bool) -> void:
	if orm_enabled == value:
		return
	
	orm_enabled = value

	Export.cache_blended_frames()
	Export.process_data()
	dialog.set_preview()


func prepare_layers() -> void:
	original_project_layers = Global.current_project.layers
	original_project_frames = Global.current_project.frames
	preview_panel.prepare_layers_for_export(orm_enabled)
	Export.split_layers = true
	Export.cache_blended_frames()
	Export.process_data()


func restore_layers() -> void:
	Global.current_project.layers = original_project_layers
	Global.current_project.frames = original_project_frames
	Export.split_layers = previously_split_layers
	Export.cache_blended_frames()
	Export.process_data()


func pre_export(project: Project) -> void:
	if not pbr_enabled:
		return
	
	prepare_layers()


func post_export(project: Project) -> void:
	if not pbr_enabled:
		return
	
	restore_layers()


func on_preview(_dict: Dictionary) -> void:
	if not pbr_enabled:
		return
	
	prepare_layers()
	Global.export_dialog._preview_images = Export.processed_images
	await RenderingServer.frame_post_draw
	restore_layers()
