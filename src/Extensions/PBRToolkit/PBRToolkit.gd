extends Node

const PREVIEW_SCENE := preload("res://src/Extensions/PBRToolkit/TestPreviewPanel.tscn")
const PREVIEW_PANEL_NAME := "PBR Preview"

var api: Node
var preview_panel: Control


func _enter_tree() -> void:
	api = get_node_or_null("/root/ExtensionsApi")
	add_preview_panel()


func _exit_tree() -> void:
	remove_preview_panel()


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
	
	# Grab the current layout
	var layout = Global.control.find_child("DockableContainer").layout
	
	# Hide panel if Canvas Preview panel is also hidden
	layout.hidden_tabs[PREVIEW_PANEL_NAME] = layout.hidden_tabs.get("Canvas Preview", true)
	
	# Add the panel using the api, this adds the panel next to the tools tab which is unwanted
	await api.panel.add_node_as_tab(preview_panel)
	
	# First we remove it from where the panel api placed it
	var tabs = api.panel._get_tabs_in_root(layout.root)
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
	api.panel.remove_node_from_tab(preview_panel)
