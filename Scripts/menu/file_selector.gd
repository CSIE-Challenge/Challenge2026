extends Control

const MENU_SCENE := "res://Scenes/menu.tscn"
const GAMEPLAY_SCENE := "res://Scenes/gameplay.tscn"
const SETTINGS_FILE_PATH := "user://player_settings.cfg"
const SETTINGS_SECTION := "file_selector"
const SETTINGS_KEY := "last_agent_file"

const DEFAULT_AGENT_DIR := "agent/scripts"

# "" for the repo default.
var selected_agent_file := ""
var _file_dialog: FileDialog

@onready var selected_label: Label = $Panel/VBoxContainer/SelectedFileLabel
@onready var enter_button: Button = $Panel/VBoxContainer/EnterGameButton


func _ready() -> void:
	selected_agent_file = _load_last_selected_file()
	if selected_agent_file != "":
		_mark_chosen()
	_update_selected_label()
	if selected_agent_file == "":
		enter_button.disabled = true


func _on_choose_button_up() -> void:
	_open_file_dialog()


func _on_default_button_up() -> void:
	selected_agent_file = ""
	_save_last_selected_file("")
	_mark_chosen()
	_update_selected_label()


func _mark_chosen() -> void:
	enter_button.disabled = false


func _on_enter_game_button_up() -> void:
	Global.single_player = true
	Global.agent_file = selected_agent_file
	SceneTransition.transition_to(GAMEPLAY_SCENE)


func _on_back_button_up() -> void:
	SceneTransition.transition_to(MENU_SCENE)


func _update_selected_label() -> void:
	if selected_agent_file == "":
		selected_label.text = "Default Agent"
	else:
		selected_label.text = selected_agent_file


func _open_file_dialog() -> void:
	var initial_directory := _resolve_initial_directory()
	if _file_dialog == null:
		_file_dialog = FileDialog.new()
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		# Use non-native dialog for consistent cross-platform behavior.
		_file_dialog.use_native_dialog = true
		_file_dialog.current_dir = initial_directory
		_file_dialog.add_filter("*.py", "Python agent")
		_file_dialog.file_selected.connect(_on_agent_file_selected)
		add_child(_file_dialog)
	if selected_agent_file != "" and FileAccess.file_exists(selected_agent_file):
		_file_dialog.current_dir = selected_agent_file.get_base_dir()
		_file_dialog.current_file = selected_agent_file.get_file()
	else:
		_file_dialog.current_dir = initial_directory
		_file_dialog.current_file = ""
	_file_dialog.popup_centered_ratio(0.6)


func _on_agent_file_selected(path: String) -> void:
	selected_agent_file = path
	_save_last_selected_file(path)
	_mark_chosen()
	_update_selected_label()


func _load_last_selected_file() -> String:
	var cfg: ConfigFile = ConfigFile.new()
	var err: int = cfg.load(SETTINGS_FILE_PATH)
	if err != OK:
		return ""

	var saved: Variant = cfg.get_value(SETTINGS_SECTION, SETTINGS_KEY, "")
	if typeof(saved) != TYPE_STRING:
		return ""

	var path := String(saved).strip_edges()
	if path == "":
		return ""

	if not path.ends_with(".py") or not FileAccess.file_exists(path):
		return ""

	return path


func _save_last_selected_file(path: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_FILE_PATH)
	if path == "":
		if cfg.has_section(SETTINGS_SECTION):
			cfg.erase_section_key(SETTINGS_SECTION, SETTINGS_KEY)
	else:
		cfg.set_value(SETTINGS_SECTION, SETTINGS_KEY, path)
	cfg.save(SETTINGS_FILE_PATH)


func _resolve_initial_directory() -> String:
	if OS.has_feature("editor"):
		var editor_candidate := ProjectSettings.globalize_path("res://").path_join(
			DEFAULT_AGENT_DIR
		)
		if DirAccess.dir_exists_absolute(editor_candidate):
			return editor_candidate
		return ProjectSettings.globalize_path("res://")

	var executable_base_dir := OS.get_executable_path().get_base_dir()
	var runtime_candidate := executable_base_dir.path_join(DEFAULT_AGENT_DIR)
	if DirAccess.dir_exists_absolute(runtime_candidate):
		return runtime_candidate

	return executable_base_dir
