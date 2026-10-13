@tool
class_name JuiceeUpdatePrompt
## The dialogs around JuiceeUpdater: check, report, warn, install.
##
## Godot has no built-in addon updater, so this asks the GitHub releases API and
## downloads the latest tagged archive on confirmation. None of that is about
## editing a graph, which is where it used to live. Add it as a child of any editor
## panel and call check().
extends Node

var _updater: JuiceeUpdater
var _update_dialog: ConfirmationDialog
var _checking_label: Label
var _update_warn_dialog: ConfirmationDialog
var _update_warn_label: RichTextLabel

## Ask GitHub whether there is a newer release, and take it from there.
func check() -> void:
	_ensure_updater()
	_show_update_status("Checking GitHub for updates...")
	_updater.check_for_updates()

func _ensure_updater() -> void:
	if _updater:
		return
	_updater = JuiceeUpdater.new()
	add_child(_updater)
	_updater.check_completed.connect(_on_update_check_completed)
	_updater.check_failed.connect(_on_update_check_failed)
	_updater.install_completed.connect(_on_update_install_completed)
	_updater.install_failed.connect(_on_update_install_failed)

func _show_update_status(message: String) -> void:
	if not _update_dialog:
		_update_dialog = ConfirmationDialog.new()
		_update_dialog.title = "Juicee Updater"
		add_child(_update_dialog)
		_checking_label = Label.new()
		_checking_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_checking_label.custom_minimum_size = Vector2(420, 0) * JuiceeEditorUtil.EDSCALE
		_update_dialog.add_child(_checking_label)
	_checking_label.text = message
	# Reset any previous confirmation handlers - fresh dialog each time.
	for sig_dict in _update_dialog.confirmed.get_connections():
		_update_dialog.confirmed.disconnect(sig_dict.callable)
	_update_dialog.ok_button_text = "OK"
	_update_dialog.get_cancel_button().visible = false
	_update_dialog.popup_centered()

func _on_update_check_completed(latest: String, current: String, release_data: Dictionary) -> void:
	var cmp := JuiceeUpdater.compare_versions(latest, current)
	if cmp == 0:
		_show_update_status("You're up to date.\n\nInstalled: v%s\nLatest:    v%s" % [current, latest])
		return
	if cmp < 0:
		# Installed version is AHEAD of the latest published release (dev build).
		# Don't claim "up to date" - that reads as broken when Latest < Installed.
		_show_update_status("You're ahead of the latest release (development build).\n\nInstalled: v%s\nLatest:    v%s" % [current, latest])
		return
	# Newer version is out - offer to install.
	var notes := _plain_notes(str(release_data.get("body", "")))
	if notes.length() > 600:
		notes = notes.substr(0, 600) + "..."
	var text := "Update available: v%s -> v%s\n\n%s\n\nDownload and install now?\nRestart the editor afterwards." % [current, latest, notes]
	_checking_label.text = text
	for sig_dict in _update_dialog.confirmed.get_connections():
		_update_dialog.confirmed.disconnect(sig_dict.callable)
	_update_dialog.ok_button_text = "Continue"
	_update_dialog.get_cancel_button().visible = true
	_update_dialog.confirmed.connect(_confirm_update.bind(latest, release_data), CONNECT_ONE_SHOT)
	_update_dialog.popup_centered()

## Release notes are Markdown, and the dialog shows plain text: headings lose their #, bold and
## code lose their marks, and links keep their words.
static func _plain_notes(md: String) -> String:
	var out: PackedStringArray = []
	var link := RegEx.create_from_string("\\[([^\\]]*)\\]\\([^)]*\\)")
	for line in md.strip_edges().split("\n"):
		var l := line.strip_edges(false, true)
		while l.begins_with("#"):
			l = l.substr(1)
		l = link.sub(l.strip_edges(true, false) if line.begins_with("#") else l, "$1", true)
		l = l.replace("**", "").replace("`", "")
		out.append(l)
	return "\n".join(out)

## Second gate before an update actually overwrites addons/juicee/. A new version
## can change effect defaults, so a project that looked right on the old version
## can feel different afterwards. Worth one deliberate click.
func _confirm_update(latest: String, release_data: Dictionary) -> void:
	if not _update_warn_dialog:
		_update_warn_dialog = ConfirmationDialog.new()
		_update_warn_dialog.title = "Before you update"
		add_child(_update_warn_dialog)
		_update_warn_label = RichTextLabel.new()
		_update_warn_label.bbcode_enabled = true
		_update_warn_label.fit_content = true
		_update_warn_label.custom_minimum_size = Vector2(440, 0) * JuiceeEditorUtil.EDSCALE
		_update_warn_dialog.add_child(_update_warn_label)

	_update_warn_label.text = (
		"[b]This overwrites [code]addons/juicee/[/code] with v%s.[/b]\n\n"
		+ "A new version can add effect parameters and change their defaults, so effects "
		+ "you already tuned may look or feel different afterwards. Check the release notes "
		+ "for anything marked as a behavior change.\n\n"
		+ "Your saved sequences and graphs ([code].tres[/code]) are left alone, and so is any "
		+ "code that calls Juicee. Only the addon folder is replaced.\n\n"
		+ "[color=#b0b0b0]Commit or back up your project first if you have local edits inside "
		+ "[code]addons/juicee/[/code], they will be lost.[/color]"
	) % latest

	for sig_dict in _update_warn_dialog.confirmed.get_connections():
		_update_warn_dialog.confirmed.disconnect(sig_dict.callable)
	_update_warn_dialog.ok_button_text = "Update Now"
	_update_warn_dialog.get_cancel_button().text = "Cancel"
	_update_warn_dialog.confirmed.connect(
		_updater.download_and_install.bind(release_data), CONNECT_ONE_SHOT)
	_update_warn_dialog.popup_centered()

func _on_update_check_failed(message: String) -> void:
	_show_update_status("Could not check for updates.\n\n%s" % message)

func _on_update_install_completed() -> void:
	_show_update_status("Update installed.\n\nRestart the editor (or disable + re-enable the plugin) for changes to take effect.")

func _on_update_install_failed(message: String) -> void:
	_show_update_status("Update failed.\n\n%s" % message)

