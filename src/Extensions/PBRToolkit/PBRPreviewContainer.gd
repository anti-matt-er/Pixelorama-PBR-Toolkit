class_name PBRPreviewContainer
extends PanelContainer


const ROTATION_SPEED := 0.005
const ZOOM_INCREMENT := 0.1
const MIN_ZOOM_Z := 0.502 # +0.002 to account for camera near-clip of 0.001
const MAX_ZOOM_Z := 10.0
const TRANSPARENT_CHECKER_SCENE := preload("res://src/UI/Nodes/TransparentChecker.tscn")
const RELOAD_ICON := preload("res://assets/graphics/misc/icon_reload.png")
const NEW_LAYER_ICON := preload("res://assets/graphics/layers/new.png")
const NEW_GROUP_ICON := preload("res://assets/graphics/layers/group_new.png")

class PBRData:
	var layer_name: String
	var option_button: OptionButton
	var layer_button: TextureButton
	var group_button: TextureButton
	var texture: ImageTexture
	var default_image: Image
	
	func _init(container: PBRPreviewContainer, layer_name: String, option_button: OptionButton, layer_button: TextureButton, group_button: TextureButton, texture: ImageTexture, default_image: Image) -> void:
		self.layer_name = layer_name
		self.option_button = option_button
		self.layer_button = layer_button
		self.group_button = group_button
		self.texture = texture
		self.default_image = default_image
		
		option_button.item_selected.connect(container._update_texture.bind(self))
		layer_button.pressed.connect(container.create_and_assign_layer.bind(self, false))
		group_button.pressed.connect(container.create_and_assign_layer.bind(self, true))

@onready var preview_container: Control = %PreviewContainer
@onready var preview_viewport: SubViewportContainer = %PreviewViewportContainer
@onready var preview_zoom_slider: VSlider = %PreviewZoomSlider
@onready var preview_reset_button: TextureButton = %PreviewResetButton
@onready var pbr_preview_cube: PBRPreviewCube = %PBRPreviewCube
@onready var camera: Camera3D = %Camera
@onready var initial_camera_pos := camera.position
@onready var albedo := PBRData.new(
	self,
	"Albedo",
	%AlbedoOptionButton,
	%AlbedoLayerButton,
	%AlbedoGroupButton,
	pbr_preview_cube.albedo,
	pbr_preview_cube.default_albedo
)
@onready var metallic := PBRData.new(
	self,
	"Metallic",
	%MetallicOptionButton,
	%MetallicLayerButton,
	%MetallicGroupButton,
	pbr_preview_cube.metallic,
	pbr_preview_cube.default_metallic
)
@onready var roughness := PBRData.new(
	self,
	"Roughness",
	%RoughnessOptionButton,
	%RoughnessLayerButton,
	%RoughnessGroupButton,
	pbr_preview_cube.roughness,
	pbr_preview_cube.default_roughness
)
@onready var emission := PBRData.new(
	self,
	"Emission",
	%EmissionOptionButton,
	%EmissionLayerButton,
	%EmissionGroupButton,
	pbr_preview_cube.emission,
	pbr_preview_cube.default_emission
)
@onready var ambient_occlusion := PBRData.new(
	self,
	"AO",
	%AmbientOcclusionOptionButton,
	%AmbientOcclusionLayerButton,
	%AmbientOcclusionGroupButton,
	pbr_preview_cube.ambient_occlusion,
	pbr_preview_cube.default_ambient_occlusion
)
@onready var normal := PBRData.new(
	self,
	"Normal",
	%NormalOptionButton,
	%NormalLayerButton,
	%NormalGroupButton,
	pbr_preview_cube.normal,
	pbr_preview_cube.default_normal
)

var layers: Dictionary[int, Array] = {}
var selected_layers: Dictionary[int, Dictionary] = {}
var serialized_layers: Dictionary[int, Dictionary] = {}
var rotating_preview := false
var rotating_preview_start_position := Vector2.ZERO
var accumulated_preview_rotation := Vector2.ZERO
var dragging_preview := false
var dragging_preview_start_position := Vector2.ZERO
var accumulated_preview_drag := Vector2.ZERO


func _ready() -> void:
	_setup_ui()
	
	Global.project_switched.connect(_update_layers)
	Global.project_data_changed.connect(_on_project_data_changed)
	Global.cel_switched.connect(_update_all_textures)
	
	preview_viewport.gui_input.connect(_preview_viewport_gui_input)
	preview_zoom_slider.value_changed.connect(zoom_camera_from_slider)
	preview_reset_button.pressed.connect(reset_camera)
	update_zoom_slider()
	
	_update_layers()
	_update_all_textures()


func _setup_ui() -> void:
	var transparent_checker: ColorRect = TRANSPARENT_CHECKER_SCENE.instantiate()
	transparent_checker.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview_container.add_child(transparent_checker)
	preview_container.move_child(transparent_checker, 0)
	
	preview_reset_button.texture_normal = RELOAD_ICON
	albedo.layer_button.texture_normal = NEW_LAYER_ICON
	metallic.layer_button.texture_normal = NEW_LAYER_ICON
	roughness.layer_button.texture_normal = NEW_LAYER_ICON
	emission.layer_button.texture_normal = NEW_LAYER_ICON
	ambient_occlusion.layer_button.texture_normal = NEW_LAYER_ICON
	normal.layer_button.texture_normal = NEW_LAYER_ICON
	albedo.group_button.texture_normal = NEW_GROUP_ICON
	metallic.group_button.texture_normal = NEW_GROUP_ICON
	roughness.group_button.texture_normal = NEW_GROUP_ICON
	emission.group_button.texture_normal = NEW_GROUP_ICON
	ambient_occlusion.group_button.texture_normal = NEW_GROUP_ICON
	normal.group_button.texture_normal = NEW_GROUP_ICON


func _on_project_data_changed(_project: Project) -> void:
	_update_all_textures()


func deserialize_layers(_dict: Dictionary, project: Project) -> void:
	# Wait until deserialization is done. This relies on the fact that OpenSave.open_pxo_file calls
	# Global.canvas.camera_zoom() regardless of whether it's creating a new project or overwriting
	# the current blank one, which happens after deserialization
	await Global.camera.zoom_changed
	
	var project_index := Global.projects.find(project)
	var project_layers = project.get_meta(&"PBRLayers")
	serialized_layers[project_index] = project_layers
	
	if not selected_layers.has(project_index):
		selected_layers[project_index] = {}
	for layer_name in project_layers.keys():
		var layer_index = project_layers[layer_name]
		if layer_index:
			selected_layers[project_index][layer_name] = project.layers[layer_index]
	
	_update_layers()
	_update_all_textures()


func get_layer_image(layer: BaseLayer, frame_index: int = Global.current_project.current_frame) -> Image:
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
	
	var frame := project.frames[frame_index]
	
	var layer_image: Image
	
	if layer is GroupLayer:
		layer_image = layer.blend_children(frame)
	else:
		var current_cel = frame.cels[project.layers.find(layer)]
		layer_image = current_cel.get_image()
	
	for other_layer in layers_to_rehide:
		other_layer.visible = false
		
	layer.visible = layer_was_visible
	
	for other_layer in layers_to_unhide:
		other_layer.visible = true
	
	for cel in frame.cels:
		cel.update_texture()
	
	return layer_image


func get_layer_or_composite_image(layer_or_composite: Variant, frame_index: int) -> Image:
	if layer_or_composite is BaseLayer:
		return get_layer_image(layer_or_composite, frame_index)
	elif layer_or_composite is Dictionary:
		var project := Global.current_project
		var image := ImageExtended.create_custom(
			project.size.x, project.size.y, false, project.get_image_format(), project.is_indexed()
		)
		var r = get_layer_image(layer_or_composite["r"], frame_index) if layer_or_composite.has("r") else image
		var g = get_layer_image(layer_or_composite["g"], frame_index) if layer_or_composite.has("g") else image
		var b = get_layer_image(layer_or_composite["b"], frame_index) if layer_or_composite.has("b") else image
		
		for x in range(project.size.x):
			for y in range(project.size.y):
				image.set_pixel(x, y, Color(
					r.get_pixel(x, y).r,
					g.get_pixel(x, y).g,
					b.get_pixel(x, y).b
				))
		
		return image
	else:
		assert(false, "Must be a layer or composite!")
	
	return


func create_layer(layer_name: String, default_image: Image, group: bool) -> BaseLayer:
	var project := Global.current_project
	
	var unique_name := layer_name
	var name_available := false
	var suffix := 1
	
	while not name_available:
		name_available = true
		for layer in project.layers:
			if layer.name == unique_name:
				name_available = false
				suffix += 1
				unique_name = "{name} {suffix}".format({
					"name": layer_name,
					"suffix": suffix
				})
				break
	
	var layer: BaseLayer
	if group:
		layer = GroupLayer.new(project, unique_name)
	else:
		layer = PixelLayer.new(project, unique_name)
	
	# We want our new layer to be at the topmost level, but no method exists to
	# support this. The following is taken from the add_layer method of
	# AnimationTimeline.gd but removes the reparenting logic to allow the new
	# layer to be topmost.

	var cels := []
	for f in project.frames:
		var cel = layer.new_empty_cel()
		if !group:
			cel.get_image().fill(default_image.get_pixel(0, 0))
		cels.append(cel)
	
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


func create_and_assign_layer(pbr_data: PBRData, group: bool) -> void:
	var layer = create_layer(pbr_data.layer_name, pbr_data.default_image, group)
	var layer_index := layers[Global.current_project_index].find(layer)
	pbr_data.option_button.select(layer_index+1)
	pbr_data.option_button.item_selected.emit(layer_index+1)


func _update_layers() -> void:
	var project = Global.current_project
	if not project.layers_updated.is_connected(_update_layers):
		project.layers_updated.connect(_update_layers)
	
	var deserializer := deserialize_layers.bind(project)
	if not project.about_to_deserialize.is_connected(deserializer):
		project.about_to_deserialize.connect(deserializer)
	
	var project_layers: Array[BaseLayer] = project.layers.duplicate()
	layers[Global.current_project_index] = project_layers
	
	for layer in project_layers:
		if not layer.name_changed.is_connected(_update_layers):
			layer.name_changed.connect(_update_layers)
	
	for option_button: OptionButton in [
		albedo.option_button,
		metallic.option_button,
		roughness.option_button,
		emission.option_button,
		ambient_occlusion.option_button,
		normal.option_button
	]:
		option_button.clear()
		option_button.add_item("")
		
		for i in range(project_layers.size()):
			option_button.add_item(project_layers[i].name, i+1)
	
	if not project_layers.is_empty() and selected_layers.has(Global.current_project_index):
		var selected = selected_layers[Global.current_project_index]
		if selected.has("Albedo") and selected.Albedo and project_layers.has(selected.Albedo):
			albedo.option_button.select(project_layers.find(selected.Albedo)+1)
		if selected.has("Metallic") and selected.Metallic and project_layers.has(selected.Metallic):
			metallic.option_button.select(project_layers.find(selected.Metallic)+1)
		if selected.has("Roughness") and selected.Roughness and project_layers.has(selected.Roughness):
			roughness.option_button.select(project_layers.find(selected.Roughness)+1)
		if selected.has("Emission") and selected.Emission and project_layers.has(selected.Emission):
			emission.option_button.select(project_layers.find(selected.Emission)+1)
		if selected.has("AO") and selected.AO and project_layers.has(selected.AO):
			ambient_occlusion.option_button.select(project_layers.find(selected.AO)+1)
		if selected.has("Normal") and selected.Normal and project_layers.has(selected.Normal):
			normal.option_button.select(project_layers.find(selected.Normal)+1)


func _update_texture(layer_number: int, pbr_data: PBRData) -> void:
	var project_layers: Array[BaseLayer] = layers.get(Global.current_project_index, [] as Array[BaseLayer])
	if not selected_layers.has(Global.current_project_index):
		selected_layers[Global.current_project_index] = {}
		serialized_layers[Global.current_project_index] = {}
	if layer_number <= 0 || project_layers.size() < layer_number:
		selected_layers[Global.current_project_index][pbr_data.layer_name] = null
		serialized_layers[Global.current_project_index][pbr_data.layer_name] = null
		pbr_data.texture.set_image(pbr_data.default_image)
	else:
		var layer := project_layers[layer_number-1]
		selected_layers[Global.current_project_index][pbr_data.layer_name] = layer
		serialized_layers[Global.current_project_index][pbr_data.layer_name] = layer_number-1
		pbr_data.texture.set_image(get_layer_image(layer))
	
	Global.current_project.set_meta(&"PBRLayers", serialized_layers[Global.current_project_index])


func _update_all_textures() -> void:
	_update_texture(albedo.option_button.selected, albedo)
	_update_texture(metallic.option_button.selected, metallic)
	_update_texture(roughness.option_button.selected, roughness)
	_update_texture(emission.option_button.selected, emission)
	_update_texture(ambient_occlusion.option_button.selected, ambient_occlusion)
	_update_texture(normal.option_button.selected, normal)


func prepare_layers_for_export(pack_orm: bool) -> void:
	var project := Global.current_project
	var selected := selected_layers[Global.current_project_index]
	var export_layers: Array[BaseLayer] = []
	var export_frames: Array[Frame] = []
	var layers_to_export := {}
	
	if pack_orm:
		var orm := {}
		if selected.has("Albedo") and selected["Albedo"]:
			layers_to_export["Albedo"] = selected["Albedo"]
		if selected.has("Emission") and selected["Emission"]:
			layers_to_export["Emission"] = selected["Emission"]
		if selected.has("Normal") and selected["Normal"]:
			layers_to_export["Normal"] = selected["Normal"]
		if selected.has("AO") and selected["AO"]:
			orm["r"] = selected["AO"]
		if selected.has("Roughness") and selected["Roughness"]:
			orm["g"] = selected["Roughness"]
		if selected.has("Metallic") and selected["Metallic"]:
			orm["b"] = selected["Metallic"]
		if not orm.is_empty():
			layers_to_export["ORM"] = orm
	else:
		for layer_name in selected.keys():
			var layer = selected[layer_name]
			if layer:
				layers_to_export[layer_name] = layer
	
	if layers_to_export.is_empty():
		return
	
	for layer_name in layers_to_export.keys():
		var new_layer := PixelLayer.new(project, layer_name)
		export_layers.append(new_layer)
	
	for frame_index in range(project.frames.size()):
		var original_frame: Frame = project.frames[frame_index]
		var cels: Array[BaseCel] = []
		
		for layer_name in layers_to_export.keys():
			var layer = layers_to_export[layer_name]
			var image := ImageExtended.new()
			image.copy_from_custom(get_layer_or_composite_image(layer, frame_index))
			var cel := PixelCel.new(image)
			cels.append(cel)
		
		export_frames.append(Frame.new(cels, original_frame.duration))
	
	project.layers = export_layers
	project.frames = export_frames


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
