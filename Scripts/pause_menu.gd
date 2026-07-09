class_name PauseMenu
extends CanvasLayer

signal resume_requested
signal main_menu_requested
signal restart_requested
signal exit_requested

@onready var _resume_button: Button = $Panel/VBoxContainer/ResumeButton
@onready var _restart_button: Button = $Panel/VBoxContainer/RestartButton
@onready var _main_menu_button: Button = $Panel/VBoxContainer/MainMenuButton
@onready var _exit_button: Button = $Panel/VBoxContainer/ExitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false

	_resume_button.button_up.connect(_on_resume_button_up)
	_restart_button.button_up.connect(_on_restart_button_up)
	_main_menu_button.button_up.connect(_on_main_menu_button_up)
	_exit_button.button_up.connect(_on_exit_button_up)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		# Esc / pause key is the expected shortcut while paused.
		get_viewport().set_input_as_handled()
		_emit_resume_requested()


func open() -> void:
	visible = true
	_resume_button.grab_focus()


func close() -> void:
	visible = false


func _on_resume_button_up() -> void:
	_emit_resume_requested()


func _on_restart_button_up() -> void:
	restart_requested.emit()


func _on_main_menu_button_up() -> void:
	main_menu_requested.emit()


func _on_exit_button_up() -> void:
	exit_requested.emit()


func _emit_resume_requested() -> void:
	if visible:
		resume_requested.emit()
