## In-editor addon updater - fetches the latest GitHub release, compares against
## the version in plugin.cfg, and (on confirmation) downloads + extracts the new
## archive over addons/juicee/.
##
## Wired into the JuiceeGraph toolbar's "Check for Updates" button. Godot has no
## built-in addon updating, so this fills the gap for end-users.
##
## Edit GITHUB_REPO below to match wherever the addon is hosted.
@tool
class_name JuiceeUpdater
extends Node

## "<owner>/<repo>" on GitHub. Change this if you fork.
const GITHUB_REPO := "Kelpekk/Juicee"

const RELEASES_API := "https://api.github.com/repos/%s/releases/latest"
const PLUGIN_CFG_PATH := "res://addons/juicee/plugin.cfg"
const ADDON_DIR := "res://addons/juicee/"

signal check_completed(latest_version: String, current_version: String, release_data: Dictionary)
signal check_failed(message: String)
signal install_completed
signal install_failed(message: String)

var _http: HTTPRequest
var _busy := false

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)

## Reads the current version from plugin.cfg (returns "0.0.0" if unreadable).
static func get_current_version() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(PLUGIN_CFG_PATH) != OK:
		return "0.0.0"
	return str(cfg.get_value("plugin", "version", "0.0.0"))

## Compares "X.Y.Z" strings. Returns 1 if a > b, -1 if a < b, 0 if equal.
## Non-numeric / missing components default to 0.
static func compare_versions(a: String, b: String) -> int:
	var pa := a.split(".")
	var pb := b.split(".")
	var n := maxi(pa.size(), pb.size())
	for i in n:
		var ai := int(pa[i]) if i < pa.size() else 0
		var bi := int(pb[i]) if i < pb.size() else 0
		if ai > bi: return 1
		if ai < bi: return -1
	return 0

## Hits the GitHub releases API. Emits check_completed or check_failed.
func check_for_updates() -> void:
	if _busy:
		check_failed.emit("Update operation already in progress")
		return
	_busy = true
	_http.request_completed.connect(_on_check_response, CONNECT_ONE_SHOT)
	var url := RELEASES_API % GITHUB_REPO
	var headers := PackedStringArray([
		"User-Agent: godot-juicee-updater",
		"Accept: application/vnd.github+json",
	])
	var err := _http.request(url, headers)
	if err != OK:
		_busy = false
		check_failed.emit("HTTPRequest error: %d" % err)

func _on_check_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS:
		check_failed.emit("Network error (offline?)")
		return
	if code == 404:
		check_failed.emit("Repository %s has no releases yet" % GITHUB_REPO)
		return
	if code != 200:
		check_failed.emit("GitHub returned HTTP %d" % code)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		check_failed.emit("Could not parse GitHub response")
		return
	var data: Dictionary = parsed
	var tag: String = str(data.get("tag_name", ""))
	if tag.is_empty():
		check_failed.emit("Release missing tag_name")
		return
	var latest := tag.lstrip("v")
	check_completed.emit(latest, get_current_version(), data)

## Downloads the release archive and extracts it over addons/juicee/.
## Prefers a user-attached .zip release asset; falls back to GitHub's
## auto-generated source archive.
func download_and_install(release_data: Dictionary) -> void:
	if _busy:
		install_failed.emit("Update operation already in progress")
		return
	_busy = true

	var assets: Array = release_data.get("assets", [])
	var zip_url := ""
	for asset in assets:
		var name: String = str(asset.get("name", ""))
		if name.ends_with(".zip"):
			zip_url = str(asset.get("browser_download_url", ""))
			break
	if zip_url.is_empty():
		zip_url = str(release_data.get("zipball_url", ""))
	if zip_url.is_empty():
		_busy = false
		install_failed.emit("Release has no downloadable archive")
		return

	_http.request_completed.connect(_on_download_response, CONNECT_ONE_SHOT)
	var headers := PackedStringArray(["User-Agent: godot-juicee-updater"])
	var err := _http.request(zip_url, headers)
	if err != OK:
		_busy = false
		install_failed.emit("Download request error: %d" % err)

func _on_download_response(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS or code >= 400:
		install_failed.emit("Download failed (HTTP %d)" % code)
		return

	# Write the archive to user:// then extract via ZIPReader.
	var tmp_path := "user://_juicee_update.zip"
	var out := FileAccess.open(tmp_path, FileAccess.WRITE)
	if not out:
		install_failed.emit("Could not write temp archive")
		return
	out.store_buffer(body)
	out.close()

	var ok := _extract_archive(ProjectSettings.globalize_path(tmp_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
	if ok:
		install_completed.emit()
	else:
		install_failed.emit("Could not extract archive into %s" % ADDON_DIR)

## Reads the archive and copies every entry under "<prefix>/addons/juicee/..."
## to "res://addons/juicee/...", overwriting existing files.
func _extract_archive(absolute_zip_path: String) -> bool:
	var zip := ZIPReader.new()
	if zip.open(absolute_zip_path) != OK:
		return false

	var files := zip.get_files()
	# GitHub source archives nest everything under "<repo>-<sha>/". Find that
	# prefix by looking for the first entry containing "addons/juicee/".
	var marker := "addons/juicee/"
	var prefix := ""
	for f in files:
		var idx := f.find(marker)
		if idx >= 0:
			prefix = f.substr(0, idx)
			break
	if prefix.is_empty() and not _has_any_addon_entry(files):
		zip.close()
		return false

	for f in files:
		var rel := ""
		if f.begins_with(prefix + marker):
			rel = f.substr((prefix + marker).length())
		elif prefix.is_empty() and f.begins_with(marker):
			rel = f.substr(marker.length())
		else:
			continue
		if rel.is_empty() or rel.ends_with("/"):
			continue  # skip directory entries
		var target := ADDON_DIR + rel
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var content := zip.read_file(f)
		var w := FileAccess.open(target, FileAccess.WRITE)
		if not w:
			zip.close()
			return false
		w.store_buffer(content)
		w.close()

	zip.close()
	return true

func _has_any_addon_entry(files: PackedStringArray) -> bool:
	for f in files:
		if f.find("addons/juicee/") >= 0:
			return true
	return false
