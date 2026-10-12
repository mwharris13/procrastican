extends GutTest

func test_grade_windows_are_inclusive_and_symmetric():
	assert_eq(TapJudge.grade(0.0, 0.06, 0.13), TapJudge.Grade.PERFECT)
	assert_eq(TapJudge.grade(0.06, 0.06, 0.13), TapJudge.Grade.PERFECT)
	assert_eq(TapJudge.grade(-0.06, 0.06, 0.13), TapJudge.Grade.PERFECT)
	assert_eq(TapJudge.grade(0.0601, 0.06, 0.13), TapJudge.Grade.GOOD)
	assert_eq(TapJudge.grade(-0.13, 0.06, 0.13), TapJudge.Grade.GOOD)
	assert_eq(TapJudge.grade(0.1301, 0.06, 0.13), TapJudge.Grade.MISS)

func test_in_reach_uses_distance():
	assert_true(TapJudge.in_reach(Vector2(2.2, 0), Vector2.ZERO, 2.2))
	assert_false(TapJudge.in_reach(Vector2(2.21, 0), Vector2.ZERO, 2.2))
