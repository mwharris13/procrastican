class_name ZoneLook
extends RefCounted
## Time-of-day look by distance: blends each zone's palette over the stretch before its start.

const BLEND_M := 40.0
const PALETTE_KEYS := ["sky", "sidewalk", "curb", "road", "lane", "tint", "sheet"]
const SKY_STOPS := 4
const BUILDINGS := {
	"block": ["house_a", "house_b", "house_c", "house_d"],
	"downtown": ["store_cafe", "store_books", "store_plain_a", "store_plain_b"],
	"highway": ["lamp_sodium"],
}


## {from, to, t}: t ramps 0→1 over the BLEND_M meters before a zone starts, else from == to and t == 0.
static func blend_at(zones: Array, x: float) -> Dictionary:
	for i in range(1, zones.size()):
		var s := float(zones[i].start_m)
		if x >= s - BLEND_M and x < s:
			return {"from": i - 1, "to": i, "t": (x - (s - BLEND_M)) / BLEND_M}
	var zi := RunState.zone_index_at(zones, x)
	return {"from": zi, "to": zi, "t": 0.0}


static func color(zones: Array, x: float, key: String) -> Color:
	var b := blend_at(zones, x)
	return Color(zones[b.from].palette[key]).lerp(Color(zones[b.to].palette[key]), b.t)


static func sky_stops(zones: Array, x: float) -> Array[Color]:
	var b := blend_at(zones, x)
	var out: Array[Color] = []
	for i in SKY_STOPS:
		out.append(Color(zones[b.from].palette.sky[i]).lerp(Color(zones[b.to].palette.sky[i]), b.t))
	return out


static func tint(zones: Array, x: float) -> Color:
	return color(zones, x, "tint")


## Building art for a slot; the zone comes from the slot's own x so the street changes over as you pass.
static func building(zones: Array, slot: int, slot_x: float) -> Dictionary:
	var sheet: String = zones[RunState.zone_index_at(zones, slot_x)].palette.sheet
	var names: Array = BUILDINGS.get(sheet, [])
	if names.is_empty():
		return {}
	return {"sheet": sheet, "name": names[absi(hash(slot)) % names.size()]}
