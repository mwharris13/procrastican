class_name Economy
extends RefCounted
## Shop prices, upgrade effects and the coin formula.


static func cost(def: Dictionary, level: int) -> float:
	return floorf(float(def.base_cost) * pow(float(def.cost_growth), level))


static func is_maxed(def: Dictionary, level: int) -> bool:
	return level >= int(def.max_level)


static func level_of(save: Dictionary, id: String) -> int:
	return int(save.levels.get(id, 0))


static func effects_for(def: Dictionary, level: int) -> Array:
	var out: Array = []
	if level <= 0:
		return out
	for e in def.effects:
		var v := float(e.value)
		out.append({"stat": e.stat, "op": e.op, "value": pow(v, level) if e.op == "mul" else v * level})
	return out


static func try_buy(save: Dictionary, def: Dictionary) -> bool:
	var lvl := level_of(save, def.id)
	if is_maxed(def, lvl):
		return false
	var price := cost(def, lvl)
	if save.coins < price:
		return false
	save.coins -= price
	save.levels[def.id] = lvl + 1
	return true


static func try_buy_can(save: Dictionary, can_def: Dictionary) -> bool:
	if save.owned_cans.has(can_def.id):
		return false
	var price := float(can_def.cost)
	if save.coins < price:
		return false
	save.coins -= price
	save.owned_cans.append(can_def.id)
	save.equipped_can = can_def.id
	return true


static func equip_can(save: Dictionary, id: String) -> bool:
	if not save.owned_cans.has(id):
		return false
	save.equipped_can = id
	return true


static func profile_effects(save: Dictionary, data: GameData) -> Array:
	var out: Array = []
	for def in data.upgrades:
		out.append_array(effects_for(def, level_of(save, def.id)))
	var c := data.can(save.equipped_can)
	if not c.is_empty():
		out.append_array(c.effects)
	return out


static func meter_value(zone_value: float, combo: int, combo_step: float) -> float:
	return zone_value * (1.0 + combo * combo_step)


static func run_coins(value_meters: float, coin_per_meter: float, coin_mult: float) -> float:
	return floorf(value_meters * coin_per_meter * coin_mult)
