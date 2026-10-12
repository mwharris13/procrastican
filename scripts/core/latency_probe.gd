class_name LatencyProbe
extends RefCounted
## Rolling input→frame and frame-time samples for the tuning overlay.

const SAMPLES := 30

var _pending_usec := -1
var _last_frame_usec := -1
var _input_ms: Array[float] = []
var _frame_ms: Array[float] = []


func mark_input(usec: int) -> void:
	if _pending_usec < 0:
		_pending_usec = usec


func mark_frame(usec: int) -> void:
	if _last_frame_usec >= 0:
		_push(_frame_ms, (usec - _last_frame_usec) / 1000.0)
	_last_frame_usec = usec
	if _pending_usec >= 0:
		_push(_input_ms, (usec - _pending_usec) / 1000.0)
		_pending_usec = -1


func input_avg_ms() -> float:
	return _avg(_input_ms)


func input_max_ms() -> float:
	return _input_ms.max() if not _input_ms.is_empty() else 0.0


func frame_avg_ms() -> float:
	return _avg(_frame_ms)


func frame_max_ms() -> float:
	return _frame_ms.max() if not _frame_ms.is_empty() else 0.0


func _push(arr: Array[float], v: float) -> void:
	arr.append(v)
	if arr.size() > SAMPLES:
		arr.pop_front()


func _avg(arr: Array[float]) -> float:
	if arr.is_empty():
		return 0.0
	var s := 0.0
	for v in arr:
		s += v
	return s / arr.size()
