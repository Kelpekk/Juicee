## Drop-in accessibility settings panel. Instance `accessibility_settings.tscn` in your options
## menu, or put this script on a VBoxContainer of your own. Every control is wired straight to the
## shared JuiceeEffect.accessibility, so a change here reaches every effect at once; save and load
## it with Juicee.accessibility.to_dict() / from_dict().
@tool
class_name JuiceeAccessibilityPanel
extends VBoxContainer

func _ready() -> void:
	_build()

func _build() -> void:
	for c in get_children():
		c.queue_free()
	var acc: JuiceeAccessibility = JuiceeEffect.accessibility
	if not acc:
		var warn := Label.new()
		warn.text = "Juicee is not loaded (Project Settings > Plugins)."
		add_child(warn)
		return

	# One grid, label on the left and control on the right, so every row lines up whatever the
	# control is. A CheckButton carrying its own text sits a few pixels in from a plain Label and
	# in a dimmer font, which is exactly what a settings screen should not look like.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(grid)

	_row(grid, "Reduced motion", _check(acc.reduced_motion, func(v: bool) -> void: acc.reduced_motion = v))
	_row(grid, "No flashing", _check(acc.no_flash, func(v: bool) -> void: acc.no_flash = v))
	_row(grid, "No screen shake", _check(acc.no_screenshake, func(v: bool) -> void: acc.no_screenshake = v))
	_row(grid, "No chromatic or glitch", _check(acc.no_chromatic, func(v: bool) -> void: acc.no_chromatic = v))
	_row(grid, "No vibration", _check(acc.no_haptics, func(v: bool) -> void: acc.no_haptics = v))
	_row(grid, "Effect intensity", _slider(acc.intensity_scale, func(v: float) -> void: acc.intensity_scale = v))
	_row(grid, "Particle quality", _quality(acc))

func _row(grid: GridContainer, text: String, control: Control) -> void:
	var label := Label.new()
	label.text = text
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)

func _check(value: bool, on_toggle: Callable) -> CheckButton:
	var cb := CheckButton.new()
	cb.button_pressed = value
	cb.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cb.toggled.connect(func(v: bool) -> void: on_toggle.call(v))
	return cb

func _slider(value: float, on_change: Callable) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = value
	slider.custom_minimum_size = Vector2(160, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.value_changed.connect(func(v: float) -> void: on_change.call(v))
	return slider

func _quality(acc: JuiceeAccessibility) -> OptionButton:
	var opt := OptionButton.new()
	opt.add_item("Low", JuiceeAccessibility.Quality.LOW)
	opt.add_item("Medium", JuiceeAccessibility.Quality.MEDIUM)
	opt.add_item("High", JuiceeAccessibility.Quality.HIGH)
	opt.select(opt.get_item_index(acc.quality))
	opt.item_selected.connect(func(idx: int) -> void: acc.quality = opt.get_item_id(idx) as JuiceeAccessibility.Quality)
	return opt
