extends Control

const MENU_SCENE := "res://Scenes/menu.tscn"
const GAMEPLAY_SCENE := "res://Scenes/gameplay.tscn"

# "" for the repo default.
var selected_agent_file := ""
var _file_dialog: FileDialog

@onready var selected_label: Label = $Panel/VBoxContainer/SelectedFileLabel
@onready var enter_button: Button = $Panel/VBoxContainer/EnterGameButton


func _ready() -> void:
	selected_agent_file = ""
	_update_selected_label()
	enter_button.disabled = true


func _on_choose_button_up() -> void:
	_open_file_dialog()


func _on_default_button_up() -> void:
	selected_agent_file = ""
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
	if _file_dialog == null:
		_file_dialog = FileDialog.new()
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_file_dialog.use_native_dialog = true
		_file_dialog.add_filter("*.py", "Python agent")
		_file_dialog.file_selected.connect(_on_agent_file_selected)
		add_child(_file_dialog)
	_file_dialog.popup_centered_ratio(0.6)


func _on_agent_file_selected(path: String) -> void:
	selected_agent_file = path
	_mark_chosen()
	_update_selected_label()
