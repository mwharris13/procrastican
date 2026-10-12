class_name KidPose
extends Control
## Draws one kid sprite frame at a fixed point; used for the results reaction.

var pose := "idle#0":
	set(v):
		pose = v
		queue_redraw()
var at := Vector2(40, 410)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	SpriteBank.draw(self, "kid", pose, at)
