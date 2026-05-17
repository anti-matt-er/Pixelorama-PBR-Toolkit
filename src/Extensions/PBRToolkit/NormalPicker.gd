class_name NormalPicker
extends CustomPicker


const DEFAULT_COLOR := Color(0.5, 0.5, 1.0)
const CHECKER_DARK_COLOR := Color(0.5, 0.5, 0.5)

@onready var default_color_hex := DEFAULT_COLOR.to_html(false)
@onready var picker: PanelContainer = %Picker
@onready var picker_texture: TextureRect = %PickerTexture
@onready var picker_image: Image = picker_texture.texture.get_image()
@onready var picker_image_size: Vector2 = Vector2(picker_image.get_size())
@onready var direction_range: KnobRange = %DirectionRange
@onready var slope_slider: HSlider = %SlopeSlider
@onready var slope_spinbox: SpinBox = %SlopeSpinBox


func _ready() -> void:
	super()
	picker.gui_input.connect(picker_input)
	slope_slider.share(slope_spinbox)
	direction_range.value_changed.connect(_on_direction_changed)
	slope_slider.value_changed.connect(_on_slope_changed)
	previous_color = DEFAULT_COLOR


func picker_input(_event: InputEvent) -> void:
	if Input.is_action_pressed("activate_left_tool"):
		pick_color()


func pick_color() -> void:
	var color := DEFAULT_COLOR
	var local_mouse := picker_texture.get_local_mouse_position()
	var texture_container_size := picker_texture.size
	if (
		local_mouse.x > 0 and
		local_mouse.y > 0 and
		local_mouse.x <= texture_container_size.x and
		local_mouse.y <= texture_container_size.y
	):
		var image_coord := (local_mouse / texture_container_size) * picker_image_size
		image_coord = image_coord.clamp(Vector2.ZERO, picker_image_size)
		color = picker_image.get_pixelv(image_coord)
	
	assign_color(color, false)


func update_color_from_inputs() -> void:
	var direction := direction_range.value
	var slope := slope_slider.value
	var dir_theta := TAU - deg_to_rad(direction)
	var slope_theta := deg_to_rad(slope)
	var vector := Vector3(
		sin(slope_theta) * cos(dir_theta),
		sin(slope_theta) * sin(dir_theta),
		cos(slope_theta)
	)
	var color = Color(
		(vector.x + 1.0) * 0.5,
		(vector.y + 1.0) * 0.5,
		(vector.z + 1.0) * 0.5
	)
	
	assign_color(color, true)


func update_inputs_from_color(color: Color) -> void:
	if color.to_html(false) == default_color_hex:
		# Use default color if picked color is close enough
		color = DEFAULT_COLOR
	
	var vector := Vector3(
		color.r * 2.0 - 1.0,
		color.g * 2.0 - 1.0,
		color.b * 2.0 - 1.0
	).normalized()
	var dir_theta := atan2(vector.y, vector.x)
	var slope_theta := acos(vector.z)
	if dir_theta < 0: dir_theta += TAU
	if slope_theta < 0: slope_theta += TAU
	var direction := clampf(rad_to_deg(TAU - dir_theta), direction_range.min_value, direction_range.max_value)
	var slope := clampf(rad_to_deg(slope_theta), slope_slider.min_value, slope_slider.max_value)
	
	if not is_zero_approx(slope):
		# Only change direction if there's any slope, to prevent unnecessarily resetting the knob
		direction_range.set_value_no_signal(direction)
		direction_range.update_knob()
	
	slope_slider.set_value_no_signal(slope)


func _on_direction_changed(_value: float) -> void:
	update_color_from_inputs()


func _on_slope_changed(_value: float) -> void:
	update_color_from_inputs()
