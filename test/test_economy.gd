extends GutTest

var d: GameData
var save: Dictionary

func before_each():
	d = GameData.load_all()
	save = SaveStore.defaults()

func test_cost_grows_geometrically():
	var u := {"base_cost": 10.0, "cost_growth": 1.6}
	assert_eq(Economy.cost(u, 0), 10.0)
	assert_eq(Economy.cost(u, 1), 16.0)
	assert_eq(Economy.cost(u, 5), floorf(10.0 * pow(1.6, 5)))

func test_effects_scale_with_level():
	var u := {"effects": [{"stat": "a", "op": "mul", "value": 1.1}, {"stat": "b", "op": "add", "value": 2.0}]}
	assert_eq(Economy.effects_for(u, 0), [])
	var e := Economy.effects_for(u, 3)
	assert_almost_eq(e[0].value, pow(1.1, 3), 1e-9)
	assert_eq(e[1].value, 6.0)

func test_try_buy_deducts_and_levels_up():
	var reach := d.upgrade("reach")
	save.coins = 100.0
	assert_true(Economy.try_buy(save, reach))
	assert_eq(save.coins, 100.0 - Economy.cost(reach, 0))
	assert_eq(Economy.level_of(save, "reach"), 1)

func test_try_buy_fails_without_coins_or_when_maxed():
	var reach := d.upgrade("reach")
	save.coins = 1.0
	assert_false(Economy.try_buy(save, reach))
	assert_eq(save.coins, 1.0)
	save.coins = 1e30
	save.levels["reach"] = int(reach.max_level)
	assert_false(Economy.try_buy(save, reach))

func test_buy_and_equip_cans():
	var paint := d.can("paint")
	save.coins = 499.0
	assert_false(Economy.try_buy_can(save, paint))
	save.coins = 500.0
	assert_true(Economy.try_buy_can(save, paint))
	assert_eq(save.equipped_can, "paint")
	assert_false(Economy.try_buy_can(save, paint))
	assert_true(Economy.equip_can(save, "soda"))
	assert_false(Economy.equip_can(save, "lucky"))

func test_profile_effects_include_upgrades_and_can():
	save.levels = {"kick_power": 2}
	save.owned_cans = ["soda", "lucky"]
	save.equipped_can = "lucky"
	var stats := StatResolver.resolve(d.tuning, Economy.profile_effects(save, d))
	assert_eq(stats.launch_speed_max, d.tuning.launch_speed_max + 2.0 * float(d.upgrades.filter(func(u): return u.id == "kick_power")[0].effects[0].value))
	assert_almost_eq(stats.coin_mult, 1.5, 1e-9)

func test_coin_formula():
	assert_eq(Economy.meter_value(10.0, 0, 0.1), 10.0)
	assert_almost_eq(Economy.meter_value(10.0, 5, 0.1), 15.0, 1e-9)
	assert_eq(Economy.run_coins(1234.0, 0.1, 2.0), 246.0)
