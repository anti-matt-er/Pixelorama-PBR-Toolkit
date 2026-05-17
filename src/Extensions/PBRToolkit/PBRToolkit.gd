extends Node

const PBR_EXPORTER := preload("res://src/Extensions/PBRToolkit/PBRExport.gd")
const PICKER_INJECTOR := preload("res://src/Extensions/PBRToolkit/ColorPickerInjector.gd")
const NORMAL_PICKER_SCENE := preload("res://src/Extensions/PBRToolkit/NormalPicker.tscn")
const GRAYSCALE_PICKER_SCENE := preload("res://src/Extensions/PBRToolkit/GrayscalePicker.tscn")
const PREVIEW_SCENE := preload("res://src/Extensions/PBRToolkit/PBRPreviewContainer.tscn")
const PREVIEW_PANEL_NAME := "PBR Preview"

var preview_panel: PBRPreviewContainer
var picker_injector: PICKER_INJECTOR
var normal_picker: NormalPicker
var grayscale_picker: GrayscalePicker


func _enter_tree() -> void:
	add_preview_panel()
	load_exporter()
	load_picker_injector()


func _exit_tree() -> void:
	remove_preview_panel()
	unload_global("PBRExport")
	unload_global("ColorPickerInjector")


func load_global(script: Script, global_name: String) -> Object:
	var instance: Object = script.new()
	instance.name = global_name
	get_tree().root.add_child(instance)
	
	return instance


func unload_global(global_name: String) -> void:
	get_node("/root/" + global_name).queue_free()


func load_exporter() -> void:
	var exporter: PBR_EXPORTER = load_global(PBR_EXPORTER, "PBRExport")
	exporter.preview_panel = preview_panel


func load_picker_injector() -> void:
	picker_injector = load_global(PICKER_INJECTOR, "ColorPickerInjector")
	await get_tree().process_frame
	normal_picker = NORMAL_PICKER_SCENE.instantiate()
	grayscale_picker = GRAYSCALE_PICKER_SCENE.instantiate()
	picker_injector.add_picker(normal_picker, "Normal Map")
	picker_injector.add_picker(grayscale_picker, "Grayscale")


func _on_layer_changed(layer_type) -> void:
	match layer_type:
		"Normal":
			picker_injector.switch_picker(normal_picker.id)
		"Metallic", "Roughness", "AO":
			picker_injector.switch_picker(grayscale_picker.id)
		_:
			picker_injector.revert_picker()


func insert_string_array_sibling(array: PackedStringArray, needle: String, new_value: String) -> void:
	var index = array.size()
	if array.has(needle):
		index = array.find(needle) + 1
	
	array.insert(index, new_value)


func insert_panel_sibling(tree_or_leaf: Resource, needle: String, panel: Control) -> bool:
	if tree_or_leaf is DockableLayoutPanel:
		if tree_or_leaf.names.has(needle):
			tree_or_leaf.insert_node(tree_or_leaf.names.find(needle) + 1, panel)
			return true
	elif tree_or_leaf is DockableLayoutSplit:
		if insert_panel_sibling(tree_or_leaf.first, needle, panel):
			return true
		if insert_panel_sibling(tree_or_leaf.second, needle, panel):
			return true
	
	return false
	

func add_preview_panel() -> void:
	# Load the panel scene
	preview_panel = PREVIEW_SCENE.instantiate()
	preview_panel.name = PREVIEW_PANEL_NAME
	preview_panel.layer_selected.connect(_on_layer_changed)
	
	# Grab the current layout
	var layout: DockableLayout = Global.control.find_child("DockableContainer").layout
	
	# Hide panel if Canvas Preview panel is also hidden
	layout.hidden_tabs[PREVIEW_PANEL_NAME] = layout.hidden_tabs.get("Canvas Preview", true)
	
	# Add the panel using the api, this adds the panel next to the tools tab which is unwanted
	await ExtensionsApi.panel.add_node_as_tab(preview_panel)
	
	# First we remove it from where the panel api placed it
	var tabs := ExtensionsApi.panel._get_tabs_in_root(layout.root)
	if tabs.size() != 0:
		tabs[0].remove_node(preview_panel)
	else:
		# Api will have already pushed an error here
		return
	
	# Now add the panel in the correct location, next to the Canvas Preview if found
	if not insert_panel_sibling(layout.root, "Canvas Preview", preview_panel):
		# Or back to the default location otherwise
		tabs[0].insert_node(0, preview_panel)
	
	# Finally, reload the layout
	Global.top_menu_container.set_layout(Global.top_menu_container.selected_layout)


func remove_preview_panel() -> void:
	ExtensionsApi.panel.remove_node_from_tab(preview_panel)
