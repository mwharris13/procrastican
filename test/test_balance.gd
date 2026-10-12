extends GutTest
## Headless bot plays many runs with greedy shopping to catch progression walls (spec §6.2).

const RUNS := 150
const DT := 1.0 / 60.0
const BOT_TAP_LEAD := 0.09

var d: GameData

func before_all():
	d = GameData.load_all()

func _perk_effects(perks: Array) -> Array:
	var out: Array = []
	for p in perks:
		out.append_array(p.effects)
	return out

func _play_run(save: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var modifier := ModifierDeck.draw(d.modifiers, rng)
	var base_effects: Array = Economy.profile_effects(save, d) + modifier.effects
	var stats := StatResolver.resolve(d.tuning, base_effects)
	var state := RunState.new(stats, d.zones)
	var sim := RunSim.new(stats)
	sim.street = StreetGen.new(rng.randi(), d.zones, d.objects, stats.helper_freq)
	sim.launch(40.0, 1.0)
	var perks: Array = []
	var tapped := false
	var reason := ""
	var t := 0.0
	while not sim.ended and t < 900.0:
		if not tapped and sim.can.time_to_touchdown() <= BOT_TAP_LEAD:
			tapped = not sim.tap(sim.can_center()).is_empty()
		for ev in sim.advance(DT):
			match ev.type:
				"touchdown":
					tapped = false
				"graded":
					state.on_grade(ev.grade)
				"helper":
					state.on_helper(ev.combo)
				"run_end":
					reason = ev.reason
		for e in state.on_distance(sim.can.pos.x):
			if e.type == "perk_due":
				var offer := PerkDeck.draw(d.perks, rng, 1, perks.map(func(p): return p.id), stats.rare_mult)
				if not offer.is_empty():
					var old_kicks := int(stats.air_kicks)
					perks.append(offer[0])
					var fresh := StatResolver.resolve(d.tuning, base_effects + _perk_effects(perks))
					for k in fresh:
						stats[k] = fresh[k]
					sim.air_kicks_left += int(stats.air_kicks) - old_kicks
		t += DT
	return {"distance": state.distance, "coins": state.coins(), "zone": state.zone_index, "reason": reason}

func _shop(save: Dictionary) -> int:
	var bought := 0
	while true:
		var best := {}
		var best_cost := INF
		for u in d.upgrades:
			var lvl := Economy.level_of(save, u.id)
			if Economy.is_maxed(u, lvl):
				continue
			var c := Economy.cost(u, lvl)
			if c < best_cost:
				best_cost = c
				best = u
		if best.is_empty() or not Economy.try_buy(save, best):
			return bought
		bought += 1
	return bought

func _first_run_reaching(history: Array, zone: int) -> int:
	for i in history.size():
		if history[i].zone >= zone:
			return i
	return -1

func _mean_coins(rows: Array) -> float:
	var s := 0.0
	for r in rows:
		s += r.coins
	return s / maxf(1.0, rows.size())

func test_always_good_bot_progresses_exponentially():
	var save := SaveStore.defaults()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var history: Array = []
	var dry := 0
	var worst_dry := 0
	for i in RUNS:
		var r := _play_run(save, rng)
		save.coins += r.coins
		history.append(r)
		var bought := _shop(save)
		dry = 0 if bought > 0 else dry + 1
		if i < RUNS - 10:
			worst_dry = maxi(worst_dry, dry)
		if i % 10 == 9:
			gut.p("run %3d  dist %7.0f m  zone %d  coins %8s  bank %8s" % [
				i + 1, r.distance, r.zone, NumFmt.format(r.coins), NumFmt.format(save.coins)])
	assert_false(history.any(func(r): return r.reason == "watchdog"), "no watchdog endings")
	var downtown := _first_run_reaching(history, 1)
	var highway := _first_run_reaching(history, 2)
	gut.p("first Downtown run: %d, first Highway run: %d, worst dry streak: %d" % [downtown, highway, worst_dry])
	assert_between(downtown, 0, 59, "reaches Downtown within ~30 minutes (60 runs)")
	assert_between(highway, 0, RUNS - 1, "reaches Highway within 150 runs")
	# Bar relaxed to 10 by user ruling; per-cost tweaks swing the streak 9-13 chaotically.
	assert_lte(worst_dry, 10, "never more than 10 runs in a row without a purchase")
	assert_gt(_mean_coins(history.slice(RUNS - 10)), _mean_coins(history.slice(0, 10)) * 100.0, "late runs earn 100x early runs")
