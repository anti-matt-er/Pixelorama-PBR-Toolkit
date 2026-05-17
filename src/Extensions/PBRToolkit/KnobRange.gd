class_name KnobRange
extends Range


@onready var knob: PanelContainer = %Knob
@onready var knob_anchor: Control = %KnobAnchor
@onready var container: HBoxContainer = %Container
@onready var spinbox: SpinBox = %SpinBox

var dragging_knob := false


func _ready() -> void:
	value_changed.connect(change_value)
	knob_anchor.gui_input.connect(knob_gui_input)
	share(spinbox)


func change_value(new_value: float) -> void:
	set_value_no_signal(new_value)
	update_knob()


func update_knob() -> void:
	var progress := (value - min_value) / (max_value - min_value)
	knob.rotation = progress * TAU


func knob_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("left_mouse"):
		dragging_knob = true


func _input(event: InputEvent) -> void:
	if event.is_action_released("left_mouse"):
		dragging_knob = false
	
	if dragging_knob:
		var angle := (knob_anchor.size * 0.5).angle_to_point(knob_anchor.get_local_mouse_position())
		if angle < 0: angle += TAU
		value = (angle / TAU) * (max_value - min_value) + min_value
