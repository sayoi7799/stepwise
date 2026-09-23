///|
test "整数解析：正常、空、非法输入" {
  assert_eq(parse_int("7", 2), 7)
  assert_eq(parse_int("", 2), 2)
  assert_eq(parse_int("3a", 2), 2)
  assert_eq(parse_int("-1", 2), 2)
}

///|
test "取名字参数" {
  let args = ["stepwise", "analyze", "a.txt", "--level", "4"]
  assert_eq(string_flag(args, "--level", "2"), "4")
  assert_eq(string_flag(args, "--missing", "2"), "2")
  assert_eq(int_flag(args, "--level", 2), 4)
}
