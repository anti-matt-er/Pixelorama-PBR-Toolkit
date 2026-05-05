extends PanelContainer


const ROTATION_SPEED := 0.005
const ZOOM_INCREMENT := 0.1
const MIN_ZOOM_Z := 0.502 # +0.002 to account for camera near-clip of 0.001
const MAX_ZOOM_Z := 10.0

@onready var preview_viewport: SubViewportContainer = %PreviewViewportContainer
@onready var preview_zoom_slider: VSlider = %PreviewZoomSlider
@onready var preview_reset_button: BaseButton = %PreviewResetButton
@onready var pbr_preview_cube: PBRPreviewCube = %PBRPreviewCube
@onready var camera: Camera3D = %Camera
@onready var initial_camera_pos := camera.position
@onready var albedo_option_button: OptionButton = %AlbedoOptionButton
@onready var albedo_layer_button: BaseButton = %AlbedoLayerButton
@onready var albedo_group_button: BaseButton = %AlbedoGroupButton
@onready var metallic_option_button: OptionButton = %MetallicOptionButton
@onready var metallic_layer_button: BaseButton = %MetallicLayerButton
@onready var metallic_group_button: BaseButton = %MetallicGroupButton
@onready var roughness_option_button: OptionButton = %RoughnessOptionButton
@onready var roughness_layer_button: BaseButton = %RoughnessLayerButton
@onready var roughness_group_button: BaseButton = %RoughnessGroupButton
@onready var emission_option_button: OptionButton = %EmissionOptionButton
@onready var emission_layer_button: BaseButton = %EmissionLayerButton
@onready var emission_group_button: BaseButton = %EmissionGroupButton
@onready var normal_option_button: OptionButton = %NormalOptionButton
@onready var normal_layer_button: BaseButton = %NormalLayerButton
@onready var normal_group_button: BaseButton = %NormalGroupButton

var layers: Array[BaseLayer] = []
var rotating_preview := false
var rotating_preview_start_position := Vector2.ZERO
var accumulated_preview_rotation := Vector2.ZERO
var dragging_preview := false
var dragging_preview_start_position := Vector2.ZERO
var accumulated_preview_drag := Vector2.ZERO


func _ready() -> void:
	Global.current_project.layers_updated.connect(_update_layers)
	Global.project_switched.connect(_update_layers)
	Global.project_data_changed.connect(_on_project_data_changed)
	Global.cel_switched.connect(_update_all_textures)
	
	preview_viewport.gui_input.connect(_preview_viewport_gui_input)
	preview_zoom_slider.value_changed.connect(zoom_camera_from_slider)
	preview_reset_button.pressed.connect(reset_camera)
	update_zoom_slider()
	
	albedo_option_button.item_selected.connect(_update_albedo)
	albedo_layer_button.pressed.connect(create_and_assign_layer.bind(albedo_option_button, "Albedo", false))
	albedo_group_button.pressed.connect(create_and_assign_layer.bind(albedo_option_button, "Albedo", true))
	metallic_option_button.item_selected.connect(_update_metallic)
	metallic_layer_button.pressed.connect(create_and_assign_layer.bind(metallic_option_button, "Metallic", false))
	metallic_group_button.pressed.connect(create_and_assign_layer.bind(metallic_option_button, "Metallic", true))
	roughness_option_button.item_selected.connect(_update_roughness)
	roughness_layer_button.pressed.connect(create_and_assign_layer.bind(roughness_option_button, "Roughness", false))
	roughness_group_button.pressed.connect(create_and_assign_layer.bind(roughness_option_button, "Roughness", true))
	emission_option_button.item_selected.connect(_update_emission)
	emission_layer_button.pressed.connect(create_and_assign_layer.bind(emission_option_button, "Emission", false))
	emission_group_button.pressed.connect(create_and_assign_layer.bind(emission_option_button, "Emission", true))
	normal_option_button.item_selected.connect(_update_normal)
	normal_layer_button.pressed.connect(create_and_assign_layer.bind(normal_option_button, "Normal", false))
	normal_group_button.pressed.connect(create_and_assign_layer.bind(normal_option_button, "Normal", true))
	
	_update_all_textures()


func _on_project_data_changed(_project: Project) -> void:
	_update_all_textures()


func get_layer_image(layer: BaseLayer) -> Image:
	var project := Global.current_project
	var layer_was_visible = layer.visible
	
	var layers_to_rehide = []
	for other_layer in project.layers:
		if other_layer.is_ancestor_of(layer) and not other_layer.visible:
			layers_to_rehide.append(other_layer)
			other_layer.visible = true
	layer.visible = true
	
	var layers_to_unhide = []
	for other_layer in project.layers:
		if other_layer == layer:
			continue
		if layer.is_ancestor_of(other_layer) || other_layer.is_ancestor_of(layer):
			continue
		if other_layer.visible:
			layers_to_unhide.append(other_layer)
			other_layer.visible = false
	
	var current_frame := project.frames[project.current_frame]
	
	var layer_image: Image
	
	if layer is GroupLayer:
		layer_image = layer.blend_children(current_frame)
	else:
		var current_cel = current_frame.cels[project.layers.find(layer)]
		layer_image = current_cel.get_image()
	
	for other_layer in layers_to_rehide:
		other_layer.visible = false
		
	layer.visible = layer_was_visible
	
	for other_layer in layers_to_unhide:
		other_layer.visible = true
	
	for cel in current_frame.cels:
		cel.update_texture()
	
	return layer_image


func create_layer(layer_name: String, group: bool) -> BaseLayer:
	var project := Global.current_project
	var layer: BaseLayer
	if group:
		layer = GroupLayer.new(project, layer_name)
	else:
		layer = PixelLayer.new(project, layer_name)
	
	# We want our new layer to be at the topmost level, but no method exists to
	# support this. The following is taken from the add_layer method of
	# AnimationTimeline.gd but removes the reparenting logic to allow the new
	# layer to be topmost.

	var cels := []
	for f in project.frames:
		cels.append(layer.new_empty_cel())
	
	var new_layer_idx = project.layers.size()
	
	project.undo_redo.create_action("Add Layer")
	project.undo_redo.add_do_method(project.add_layers.bind([layer], [new_layer_idx], [cels]))
	project.undo_redo.add_undo_method(project.remove_layers.bind([new_layer_idx]))
	project.undo_redo.add_do_method(project.change_cel.bind(-1, new_layer_idx))
	project.undo_redo.add_undo_method(project.change_cel.bind(-1, project.current_layer))
	project.undo_redo.add_do_method(Global.undo_or_redo.bind(false))
	project.undo_redo.add_undo_method(Global.undo_or_redo.bind(true))
	project.undo_redo.commit_action()
	
	return layer


func create_and_assign_layer(option_button: OptionButton, layer_name: String, group: bool) -> void:
	var layer = create_layer(layer_name, group)
	var layer_index := layers.find(layer)
	option_button.select(layer_index+1)
	option_button.item_selected.emit(layer_index+1)


func _update_layers() -> void:
	var previous_albedo: BaseLayer
	var previous_metallic: BaseLayer
	var previous_roughness: BaseLayer
	var previous_emission: BaseLayer
	var previous_normal: BaseLayer
	
	if not layers.is_empty():
		if albedo_option_button.selected > 0 and layers.size() >= albedo_option_button.selected:
			previous_albedo = layers[albedo_option_button.selected-1]
		if metallic_option_button.selected > 0 and layers.size() >= metallic_option_button.selected:
			previous_metallic = layers[metallic_option_button.selected-1]
		if roughness_option_button.selected > 0 and layers.size() >= roughness_option_button.selected:
			previous_roughness = layers[roughness_option_button.selected-1]
		if emission_option_button.selected > 0 and layers.size() >= emission_option_button.selected:
			previous_emission = layers[emission_option_button.selected-1]
		if normal_option_button.selected > 0 and layers.size() >= normal_option_button.selected:
			previous_normal = layers[normal_option_button.selected-1]
	
	var project = Global.current_project
	layers = project.layers.duplicate()
	
	for layer in layers:
		if not layer.name_changed.is_connected(_update_layers):
			layer.name_changed.connect(_update_layers)
	
	for option_button: OptionButton in [
		albedo_option_button,
		metallic_option_button,
		roughness_option_button,
		emission_option_button,
		normal_option_button
	]:
		option_button.clear()
		option_button.add_item("")
		
		for i in range(layers.size()):
			option_button.add_item(layers[i].name, i+1)
	
	if not layers.is_empty():
		if previous_albedo and layers.has(previous_albedo):
			albedo_option_button.select(layers.find(previous_albedo)+1)
		if previous_metallic and layers.has(previous_metallic):
			metallic_option_button.select(layers.find(previous_metallic)+1)
		if previous_roughness and layers.has(previous_roughness):
			roughness_option_button.select(layers.find(previous_roughness)+1)
		if previous_emission and layers.has(previous_emission):
			emission_option_button.select(layers.find(previous_emission)+1)
		if previous_normal and layers.has(previous_normal):
			normal_option_button.select(layers.find(previous_normal)+1)


func _update_albedo(layer_number: int) -> void:
	if layer_number <= 0 || layers.size() < layer_number:
		pbr_preview_cube.albedo.set_image(pbr_preview_cube.default_albedo)
	else:
		pbr_preview_cube.albedo.set_image(get_layer_image(layers[layer_number-1]))


func _update_metallic(layer_number: int) -> void:
	if layer_number <= 0 || layers.size() < layer_number:
		pbr_preview_cube.metallic.set_image(pbr_preview_cube.default_metallic)
	else:
		pbr_preview_cube.metallic.set_image(get_layer_image(layers[layer_number-1]))


func _update_roughness(layer_number: int) -> void:
	if layer_number <= 0 || layers.size() < layer_number:
		pbr_preview_cube.roughness.set_image(pbr_preview_cube.default_roughness)
	else:
		pbr_preview_cube.roughness.set_image(get_layer_image(layers[layer_number-1]))


func _update_emission(layer_number: int) -> void:
	if layer_number <= 0 || layers.size() < layer_number:
		pbr_preview_cube.emission.set_image(pbr_preview_cube.default_emission)
	else:
		pbr_preview_cube.emission.set_image(get_layer_image(layers[layer_number-1]))


func _update_normal(layer_number: int) -> void:
	if layer_number <= 0 || layers.size() < layer_number:
		pbr_preview_cube.normal.set_image(pbr_preview_cube.default_normal)
	else:
		pbr_preview_cube.normal.set_image(get_layer_image(layers[layer_number-1]))


func _update_all_textures() -> void:
	_update_albedo(albedo_option_button.selected)
	_update_metallic(metallic_option_button.selected)
	_update_roughness(roughness_option_button.selected)
	_update_emission(emission_option_button.selected)
	_update_normal(normal_option_button.selected)


func update_zoom_slider() -> void:
	preview_zoom_slider.value = remap(camera.position.z, MIN_ZOOM_Z, MAX_ZOOM_Z, preview_zoom_slider.max_value, preview_zoom_slider.min_value)


func zoom_camera(dir: float) -> void:
	camera.position.z += dir * ZOOM_INCREMENT
	camera.position.z = clampf(camera.position.z, MIN_ZOOM_Z, MAX_ZOOM_Z)
	update_zoom_slider()


func zoom_camera_from_slider(slider_value: float) -> void:
	camera.position.z = remap(slider_value, preview_zoom_slider.max_value, preview_zoom_slider.min_value, MIN_ZOOM_Z, MAX_ZOOM_Z)


func reset_camera() -> void:
	camera.position = initial_camera_pos
	pbr_preview_cube.position = Vector3.ZERO
	pbr_preview_cube.rotation = Vector3.ZERO
	accumulated_preview_drag = Vector2.ZERO
	accumulated_preview_rotation = Vector2.ZERO
	update_zoom_slider()


func _preview_viewport_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_mouse"):
		rotating_preview = true
		rotating_preview_start_position = get_global_mouse_position()
	elif event.is_action_pressed("pan"):
		dragging_preview = true
		dragging_preview_start_position = get_global_mouse_position()
	elif event.is_action_pressed(&"zoom_in", false, true):
		zoom_camera(-1)
	elif event.is_action_pressed(&"zoom_out", false, true):
		zoom_camera(1)


func _input(event: InputEvent) -> void:
	if event.is_action_released("left_mouse"):
		rotating_preview = false
		accumulated_preview_rotation += get_global_mouse_position() - rotating_preview_start_position
	if event.is_action_released("pan"):
		dragging_preview = false
		accumulated_preview_drag += get_global_mouse_position() - dragging_preview_start_position
	if rotating_preview:
		var delta_mouse := get_global_mouse_position() - rotating_preview_start_position + accumulated_preview_rotation
		pbr_preview_cube.rotation.y = delta_mouse.x * ROTATION_SPEED
		pbr_preview_cube.rotation.x = delta_mouse.y * ROTATION_SPEED
	if dragging_preview:
		var delta_mouse := get_global_mouse_position() - dragging_preview_start_position + accumulated_preview_drag
		pbr_preview_cube.position = camera.project_position(delta_mouse + preview_viewport.size * 0.5, camera.position.z)
