extends GutTest

func test_adds_then_muls():
	var out := StatResolver.resolve({"a": 10.0}, [
		{"stat": "a", "op": "mul", "value": 2.0},
		{"stat": "a", "op": "add", "value": 5.0},
		{"stat": "a", "op": "mul", "value": 1.5},
	])
	assert_eq(out.a, (10.0 + 5.0) * 2.0 * 1.5)

func test_order_independent():
	var e1 := {"stat": "a", "op": "add", "value": 3.0}
	var e2 := {"stat": "a", "op": "mul", "value": 2.0}
	assert_eq(StatResolver.resolve({"a": 1.0}, [e1, e2]), StatResolver.resolve({"a": 1.0}, [e2, e1]))

func test_does_not_mutate_base_and_skips_unknown():
	var base := {"a": 1.0}
	var out := StatResolver.resolve(base, [{"stat": "zzz", "op": "add", "value": 1.0}, {"stat": "a", "op": "add", "value": 1.0}])
	assert_eq(base.a, 1.0)
	assert_eq(out.a, 2.0)
	assert_false(out.has("zzz"))
