class_name SettingsScreen
extends ScreenBase

signal back
signal imported(save: Dictionary)

const CONFIRM_SECONDS := 3.0

var export_box: TextEdit
var import_box: TextEdit
var status: Label
var _confirm_until_ms := 0


func _init() -> void:
	super()
	add_title("Settings", 20)
	add_label("Your save code (copy it somewhere safe):", 11)
	export_box = _text_box(false)
	add_button("Copy code", _copy)
	add_label("Paste a code to restore:", 11)
	import_box = _text_box(true)
	add_button("Import", try_import)
	status = add_label("", 11)
	add_button("Back", func(): back.emit())


func _text_box(editable: bool) -> TextEdit:
	var t := TextEdit.new()
	t.custom_minimum_size = Vector2(0, 60)
	t.editable = editable
	t.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(t)
	return t


func _copy() -> void:
	DisplayServer.clipboard_set(export_box.text)
	status.text = "Copied."


func set_save(save: Dictionary) -> void:
	export_box.text = SaveStore.export_code(save)
	status.text = ""


## The first press arms, a second press within 3 s replaces the save.
func try_import() -> bool:
	var data := SaveStore.import_code(import_box.text)
	if data.is_empty():
		_confirm_until_ms = 0
		status.text = "That isn't a valid save code."
		return false
	var now := Time.get_ticks_msec()
	if now > _confirm_until_ms:
		_confirm_until_ms = now + int(CONFIRM_SECONDS * 1000)
		status.text = "Tap Import again to replace your save."
		return false
	_confirm_until_ms = 0
	status.text = "Save imported."
	imported.emit(data)
	return true
