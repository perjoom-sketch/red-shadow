extends CanvasLayer
## PortalModal.gd — 포털 진입 시 목적지 선택 모달.
## 목적지 목록을 표시하고 선택 시 해당 씬으로 이동한다.

signal destination_selected(scene_path: String)
signal cancelled

@onready var panel: PanelContainer = $Panel
@onready var destination_list: VBoxContainer = $Panel/VBox/DestinationList
@onready var cancel_btn: Button = $Panel/VBox/CancelBtn

## 현재 씬에서 이동 가능한 목적지 배열.
## [{name: "루프탑", scene: "res://scenes/Main.tscn"}, ...]
var destinations: Array[Dictionary] = []


func _ready() -> void:
	cancel_btn.pressed.connect(_on_cancel)
	process_mode = Node.PROCESS_MODE_ALWAYS


func show_modal(dests: Array[Dictionary]) -> void:
	destinations = dests
	_build_buttons()
	visible = true
	get_tree().paused = true


func hide_modal() -> void:
	visible = false
	get_tree().paused = false


func _build_buttons() -> void:
	for child in destination_list.get_children():
		child.queue_free()
	for dest in destinations:
		var btn := Button.new()
		btn.text = dest["name"]
		btn.custom_minimum_size = Vector2(200, 40)
		btn.pressed.connect(_on_destination_chosen.bind(dest["scene"]))
		destination_list.add_child(btn)


func _on_destination_chosen(scene_path: String) -> void:
	hide_modal()
	destination_selected.emit(scene_path)
	get_tree().change_scene_to_file(scene_path)


func _on_cancel() -> void:
	hide_modal()
	cancelled.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_on_cancel()
		get_viewport().set_input_as_handled()
