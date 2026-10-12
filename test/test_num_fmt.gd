extends GutTest

func test_small_numbers_are_plain_integers():
	assert_eq(NumFmt.format(0.0), "0")
	assert_eq(NumFmt.format(12.7), "12")
	assert_eq(NumFmt.format(999.0), "999")

func test_suffix_boundaries_round_up_cleanly():
	assert_eq(NumFmt.format(999.96), "1.0K")
	assert_eq(NumFmt.format(1000.0), "1.0K")
	assert_eq(NumFmt.format(1450.0), "1.4K")
	assert_eq(NumFmt.format(999_949.0), "999.9K")
	assert_eq(NumFmt.format(999_950.0), "1.0M")
	assert_eq(NumFmt.format(3.2e6), "3.2M")
	assert_eq(NumFmt.format(8.1e9), "8.1B")
	assert_eq(NumFmt.format(2.3e12), "2.3T")

func test_huge_and_special_values():
	assert_eq(NumFmt.format(1e30), "1.0No")
	assert_eq(NumFmt.format(1e40), "1.00e40")
	assert_eq(NumFmt.format(INF), "∞")
	assert_eq(NumFmt.format(NAN), "0")
	assert_eq(NumFmt.format(-1500.0), "-1.5K")
