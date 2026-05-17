class_name GrayscalePicker
extends CustomPicker


const SWATCH_STEP := 5

@onready var slider: HSlider = %Slider
@onready var spinbox: SpinBox = %SpinBox
@onready var swatches_container: HBoxContainer = %Swatches
@onready var swatch_template_button: Button = %SwatchButton

var swatches: Dictionary[float, Button]


func _ready() -> void:
	super()
	slider.share(spinbox)
	slider.value_changed.connect(_on_value_changed)
	_set_slider_style()
	_setup_swatches()


func _set_slider_style() -> void:
	var color_picker := ColorPicker.new()
	add_child(color_picker)
	await get_tree().process_frame
	var color_slider: HSlider = color_picker.find_children("*", "HSlider", true, false)[0]
	slider.begin_bulk_theme_override()
	slider.add_theme_icon_override("grabber", color_slider.get_theme_icon("grabber"))
	slider.add_theme_icon_override("grabber_highlight", color_slider.get_theme_icon("grabber_highlight"))
	slider.add_theme_icon_override("grabber_disabled", color_slider.get_theme_icon("grabber_disabled"))
	slider.add_theme_icon_override("tick", color_slider.get_theme_icon("tick"))
	slider.end_bulk_theme_override()
	color_picker.queue_free()


func _setup_swatches() -> void:
	var template_normal_style: StyleBoxFlat = swatch_template_button.get_theme_stylebox("normal")
	var template_pressed_style: StyleBoxFlat = swatch_template_button.get_theme_stylebox("pressed")
	var empty_style := StyleBoxEmpty.new()
	
	for i in range(ceili(slider.max_value / float(SWATCH_STEP)) + 1):
		var gray := float(i * SWATCH_STEP) / slider.max_value 
		var color := Color(gray, gray, gray)
		var swatch: Button = swatch_template_button.duplicate()
		var normal_style := template_normal_style.duplicate()
		var pressed_style := template_pressed_style.duplicate()
		normal_style.bg_color = color
		pressed_style.bg_color = color
		swatch.add_theme_stylebox_override("normal", normal_style)
		swatch.add_theme_stylebox_override("pressed", pressed_style)
		swatch.add_theme_stylebox_override("hover", normal_style)
		swatch.add_theme_stylebox_override("hover_pressed", pressed_style)
		swatch.pressed.connect(_set_color_from_swatch.bind(swatch, color))
		swatches_container.add_child(swatch)
		swatches[gray] = swatch
	
	swatch_template_button.queue_free()


func _set_color_from_swatch(swatch: Button, color: Color) -> void:
	for other_swatch in swatches.values():
		other_swatch.set_pressed_no_signal(swatch == other_swatch)
	
	assign_color(color, false)


func update_inputs_from_color(color: Color) -> void:
	var gray = (color.r + color.b + color.g) / 3.0
	slider.set_value_no_signal(gray * slider.max_value)
	
	for swatch in swatches.values():
		swatch.set_pressed_no_signal(false)
		
	for swatch_gray in swatches.keys():
		if is_equal_approx(gray, swatch_gray):
			var swatch := swatches[swatch_gray]
			swatch.set_pressed_no_signal(true)


func update_color_from_inputs() -> void:
	var gray := slider.value / slider.max_value
	var color := Color(gray, gray, gray)
	assign_color(color, false)


func update_color(color: Color) -> void:
	update_inputs_from_color(color)
	
	
func _on_color_changed(color_info: Dictionary, _button: int) -> void:
	update_color(color_info.color)


func _on_tool_changed(_tool_name: String, button: int) -> void:
	update_color(Tools.get_assigned_color(button))


func _on_value_changed(_value: float) -> void:
	update_color_from_inputs()
