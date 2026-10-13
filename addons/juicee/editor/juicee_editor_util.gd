@tool
class_name JuiceeEditorUtil
## The small things every Juicee editor panel needs: the editor's display scale,
## its icons and fonts, and the docstrings written above an effect's @export vars.
##
## These were copied around rather than shared. EDSCALE was declared identically in
## four files, _editor_icon() was implemented twice, and the docstring parser sat
## inside the graph editor even though it only reads GDScript source. One copy each,
## here.

## Editor display scale (HiDPI). Every hardcoded pixel size multiplies by this so
## the UI matches the editor at 150% / 200% display scale. 1.0 outside the editor.
static var EDSCALE: float = (EditorInterface.get_editor_scale() if Engine.is_editor_hint() else 1.0)

## An icon from the editor's own theme, so panels look like the editor rather than
## like a plugin. Null outside the editor and for a name the theme does not have.
static func editor_icon(icon_name: String) -> Texture2D:
	if not Engine.is_editor_hint():
		return null
	var theme := EditorInterface.get_editor_theme()
	if theme and theme.has_icon(icon_name, "EditorIcons"):
		return theme.get_icon(icon_name, "EditorIcons")
	return null

## An icon file, or null while the editor has not imported it yet. The icons ship with their
## .import files, so ResourceLoader.exists() says yes before the import has run, and load() then
## printed three errors an icon, 33 in all, on the first open of a project that already had the
## plugin on, such as a fresh clone with no .godot folder, on Godot 4.3.
static func addon_icon(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var import := ConfigFile.new()
	if import.load(path + ".import") == OK:
		for made in import.get_value("deps", "dest_files", []):
			if not FileAccess.file_exists(str(made)):
				return null
	return load(path) as Texture2D

## The editor's own font (e.g. "bold") so headers read as headers through weight -
## the native way - instead of through custom sizes.
static func editor_font(font_name: String) -> Font:
	if not Engine.is_editor_hint():
		return null
	var theme := EditorInterface.get_editor_theme()
	if theme and theme.has_font(font_name, "EditorFonts"):
		return theme.get_font(font_name, "EditorFonts")
	return null

static func bold_label(label: Label) -> void:
	var f := editor_font("bold")
	if f:
		label.add_theme_font_override("font", f)

# --- @export docstrings ------------------------------------------------------

static var _property_doc_cache: Dictionary = {}

## Maps property name -> the `##` comment written above its @export, read straight
## out of the script's source. That is where an effect's parameters are documented,
## so the panels can show the author's own words rather than a second copy of them
## kept somewhere else and left to drift.
static func property_docs(script: Script) -> Dictionary:
	if not script:
		return {}
	var key: String = script.resource_path
	if _property_doc_cache.has(key):
		return _property_doc_cache[key]

	var docs: Dictionary = {}
	if not script.has_method("get_source_code"):
		_property_doc_cache[key] = docs
		return docs

	var source: String = script.get_source_code()
	if source.is_empty():
		_property_doc_cache[key] = docs
		return docs

	var pending_doc: String = ""
	for raw_line in source.split("\n"):
		var line: String = raw_line.strip_edges()
		if line.begins_with("##"):
			# Strip leading "##" and one optional space.
			var doc_text: String = line.substr(2)
			if doc_text.begins_with(" "):
				doc_text = doc_text.substr(1)
			if pending_doc.is_empty():
				pending_doc = doc_text
			else:
				pending_doc += "\n" + doc_text
		elif line.begins_with("@export"):
			# Try to extract the property name after `var `.
			var var_pos: int = line.find("var ")
			if var_pos >= 0 and not pending_doc.is_empty():
				var after_var: String = line.substr(var_pos + 4)
				# Property name ends at first colon, space, or equals sign.
				var end: int = after_var.length()
				for ch in [":", " ", "="]:
					var p: int = after_var.find(ch)
					if p >= 0 and p < end:
						end = p
				var prop_name: String = after_var.substr(0, end).strip_edges()
				if not prop_name.is_empty():
					docs[prop_name] = pending_doc
			# Always reset after an @export line (even @export_group with no var).
			pending_doc = ""
		elif line.is_empty():
			pending_doc = ""
		else:
			# Any other code line breaks the docstring chain.
			pending_doc = ""

	_property_doc_cache[key] = docs
	return docs

## Effects whose one play is several phases in a row, and the properties to add up.
const LENGTH_PHASES := {
	"camera_rotation_effect": ["tilt_duration", "hold_duration", "return_duration"],
	"cinematic_bars_effect": ["enter_duration", "hold_duration", "exit_duration"],
	"flip_effect": ["flip_duration", "hold_duration"],
	"hit_stop_effect": ["freeze_duration", "recover_time"],
	"music_duck_effect": ["ramp_in", "hold", "ramp_out"],
	"recoil_effect": ["attack", "return_duration"],
	"stretch_effect": ["stretch_time", "return_time"],
	"time_scale_ramp_effect": ["ramp_in", "hold", "ramp_out"],
}

## Effects that repeat a period a number of times. 0 cycles means until stopped, so no length.
const LENGTH_CYCLES := {
	"breathe_effect": ["period", "cycles"],
	"sway_effect": ["period", "cycles"],
	"stutter_effect": ["freeze_time", "count"],
	"pulse_effect": ["pulse_interval", "count"],
}

## How long one play of this effect lasts, in seconds, as the editor shows it on an Inspector row,
## in the Inspector header and under a graph block. 0 when the length is not the effect's own to
## know: a sound runs as long as its stream, a push is a moment, a Wait For Input waits.
static func play_length(effect: JuiceeEffect) -> float:
	if not effect:
		return 0.0
	var script := effect.get_script() as Script
	var basename: String = script.resource_path.get_file().get_basename() if script else ""
	if LENGTH_PHASES.has(basename):
		var sum := 0.0
		for p in LENGTH_PHASES[basename]:
			sum += maxf(0.0, float(effect.get(p)))
		return sum
	if "duration" in effect:
		var set_length: Variant = effect.get("duration")
		if (set_length is float or set_length is int) and float(set_length) > 0.0:
			return float(set_length)
	if LENGTH_CYCLES.has(basename):
		var pair: Array = LENGTH_CYCLES[basename]
		var each := float(effect.get(pair[0]))
		var times := float(effect.get(pair[1]))
		# Stutter's freeze repeats with a gap of its own between each.
		if basename == "stutter_effect":
			each += float(effect.get("gap_time"))
		return each * times if times > 0.0 else 0.0
	if "lifetime" in effect:
		var v: Variant = effect.get("lifetime")
		if (v is float or v is int) and float(v) > 0.0:
			return float(v)
	return 0.0

## play_length() as the editor prints it, "" when there is none.
static func play_length_text(effect: JuiceeEffect) -> String:
	var v := play_length(effect)
	return "%.2fs" % v if v > 0.0 else ""

## A category header in an effect picker, the same in the Inspector and the graph: a fold
## triangle, the category in capitals, and how many entries sit under it.
static func picker_header_text(category: String, open: bool, count: int = -1) -> String:
	var text := ("▾  " if open else "▸  ") + category.to_upper()
	if count >= 0:
		text += "  %d" % count
	return text

## Tooltip on those headers, and the key hint under both pickers.
const PICKER_HEADER_TIP := "Click to expand or collapse this category"

## True when the editor runs a light theme. Colours picked for a dark editor (white text at low
## alpha, a category colour lightened) vanish on a light one.
static func is_light_theme() -> bool:
	if not Engine.is_editor_hint():
		return false
	var theme := EditorInterface.get_editor_theme()
	if theme and theme.has_color("base_color", "Editor"):
		return theme.get_color("base_color", "Editor").get_luminance() > 0.5
	return false

## The editor's own text colour at a given strength, for secondary text that has to read on
## either theme.
static func text_color(alpha: float = 1.0) -> Color:
	var c := Color(0.88, 0.88, 0.9)
	if Engine.is_editor_hint():
		var theme := EditorInterface.get_editor_theme()
		if theme and theme.has_color("font_color", "Label"):
			c = theme.get_color("font_color", "Label")
	c.a = alpha
	return c

## A category colour as a heading on this theme: lifted on a dark editor, deepened on a light one.
static func heading_color(c: Color) -> Color:
	return c.darkened(0.3) if is_light_theme() else c.lightened(0.22)

## Juicee's editor UI is English with no translation of its own, so the editor's catalog is kept
## off it; left on, it translates the odd word it knows. Children inherit.
static func english_only(root: Node) -> void:
	root.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED

## An int enum's hint string as [label, value] pairs. "Trans Sine:1" is a label and a value, not a
## label; an entry without a value takes its position.
static func enum_entries(hint_string: String) -> Array:
	var out: Array = []
	var i := 0
	for entry in hint_string.split(",", false):
		var label := entry.strip_edges()
		var value := i
		var colon := label.rfind(":")
		if colon > 0 and label.substr(colon + 1).is_valid_int():
			value = int(label.substr(colon + 1))
			label = label.substr(0, colon).strip_edges()
		out.append([label.capitalize(), value])
		i += 1
	return out

## What a field the inline editors cannot draw holds, in a few words.
static func field_summary(value: Variant) -> String:
	if value == null:
		return "None"
	if value is Array:
		var n: int = (value as Array).size()
		return "Empty" if n == 0 else ("1 item" if n == 1 else "%d items" % n)
	if value is JuiceeEffect:
		return (value as JuiceeEffect).get_display_name()
	if value is Resource:
		var r := value as Resource
		if not r.resource_path.is_empty() and not r.resource_path.contains("::"):
			return r.resource_path.get_file()
		var s := r.get_script() as Script
		if s and not s.get_global_name().is_empty():
			return String(s.get_global_name())
		return r.get_class()
	return str(value)

## A field the inline editors cannot draw (an array, a curve, a sub-resource, a Variant): what it
## holds, on a button that opens the effect in the Inspector at that field, where Godot's own
## editors handle it.
static func inspector_field_button(effect: Object, prop: String) -> Button:
	var b := Button.new()
	b.text = field_summary(effect.get(prop))
	var icon := editor_icon("Edit")
	if icon:
		b.icon = icon
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = "Edit %s in the Inspector" % prop.capitalize()
	# Deferred: opening an object rebuilds the Inspector, which can free this very button.
	b.pressed.connect(func() -> void: EditorInterface.inspect_object.call_deferred(effect, prop))
	return b
const PICKER_KEY_HINT := "Enter to add, Esc to close"

## "2d" or "3d" for the scene open in the editor, "" when its root does not say (a plain
## Node, no scene, or outside the editor). The dimension markers in the Inspector and on
## graph blocks show only when an effect's dimension is not this one: "2D only" on every
## row of a 2D game said nothing, and the mark is for the effect that cannot work here.
static func scene_dimension() -> String:
	if not Engine.is_editor_hint():
		return ""
	var root := EditorInterface.get_edited_scene_root()
	if root is Node3D:
		return "3d"
	if root is CanvasItem:
		return "2d"
	return ""

## Every effect script the editor should offer: the addon's own, plus whatever folders
## the project points `juicee/effect_folders` at.
##
## One function because there were two, one in the graph editor and one in the
## inspector plugin, and two copies of the same scan is how the Vector3 gap and the
## WorldEnvironment lookup both happened.
##
## Folders outside the addon are searched recursively and filtered by ancestry rather
## than by being in the right directory: a user folder holds whatever the user keeps
## there, and loading a stranger's script to ask what it is would run its _init.
static func effect_scripts(addon_dir: String, base_file: String) -> Array[Script]:
	var out: Array[Script] = []
	var seen: Dictionary = {}
	_collect_effects(addon_dir, base_file, false, out, seen)
	for folder in effect_folders():
		_collect_effects(folder, base_file, true, out, seen)
	return out

## The configured extra folders, normalised to end in a slash and with the ones that do
## not exist dropped, since a stale path in project settings should not be an error
## every time the popup opens.
static func effect_folders() -> Array[String]:
	var out: Array[String] = []
	if not ProjectSettings.has_setting(JuiceeEffect.EFFECT_FOLDERS_SETTING):
		return out
	var raw: Variant = ProjectSettings.get_setting(JuiceeEffect.EFFECT_FOLDERS_SETTING)
	if not (raw is PackedStringArray or raw is Array):
		return out
	for entry in raw:
		var path := String(entry).strip_edges()
		if path.is_empty():
			continue
		if not path.ends_with("/"):
			path += "/"
		if DirAccess.dir_exists_absolute(path):
			out.append(path)
	return out

static func _collect_effects(dir_path: String, base_file: String, recurse: bool,
		out: Array[Script], seen: Dictionary) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		var full := dir_path + f
		if dir.current_is_dir():
			if recurse and not f.begins_with("."):
				_collect_effects(full + "/", base_file, true, out, seen)
		elif f.ends_with(".gd") and f != base_file and not seen.has(full):
			var script := load(full) as Script
			if script and script.can_instantiate() and _is_effect_script(script):
				seen[full] = true
				out.append(script)
			elif script and not recurse:
				# Only worth saying for the addon's own folder. A parse error in there is
				# a bug; a script in a user folder simply might not be an effect.
				push_warning("Juicee: skipping %s (cannot instantiate - parse error?)" % f)
		f = dir.get_next()
	dir.list_dir_end()

## Walks the inheritance chain rather than instantiating. A user folder can hold any
## script at all, and `new()` on a stranger runs its _init just to ask what it is.
static func _is_effect_script(script: Script) -> bool:
	var s: Script = script
	while s:
		if s.resource_path.ends_with("/juicee_effect.gd"):
			return true
		s = s.get_base_script()
	return false
