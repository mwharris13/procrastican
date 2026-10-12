class_name LightLayer
extends Node2D
## Additive light pools under lamps; a child of RunView so it composites over the street.

const POOL_ALPHA := 0.35

var view: RunView


func _init() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m


func _draw() -> void:
	if view == null:
		return
	for p in view.lamp_pools(get_viewport_rect().size):
		SpriteBank.draw(self, "fx", "light_pool", p, Color(1, 1, 1, POOL_ALPHA))
