class_name LaunchAim
extends RefCounted
## Slingshot aim: pulling back from the press point sets launch angle and power.


static func from_drag(drag: Vector2, stats: Dictionary) -> Dictionary:
	var length := drag.length()
	if length < stats.drag_min_px:
		return {"valid": false, "angle": 0.0, "power": 0.0}
	# Screen y is down, world y is up, and the launch goes opposite the pull.
	var launch_dir := Vector2(-drag.x, drag.y)
	var deg := clampf(rad_to_deg(atan2(launch_dir.y, launch_dir.x)), stats.angle_min, stats.angle_max)
	return {"valid": true, "angle": deg, "power": clampf(length / stats.drag_max_px, 0.0, 1.0)}


static func preview(angle_deg: float, power01: float, stats: Dictionary, count: int = 18, dt: float = 0.06) -> PackedVector2Array:
	var c := CanPhysics.new(stats)
	c.launch(angle_deg, power01)
	var pts := PackedVector2Array()
	for i in count:
		var ev: Array = []
		c.step(dt, ev)
		pts.append(c.pos)
		if not ev.is_empty():
			break
	return pts
