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

///|
/// 回归测试：曾经 vocab / anki 会把 .epub 当成纯文本读，
/// 于是屏幕上出现 PK、ye 这类 ZIP 二进制的碎片。
test "读正文时 epub 走解析，且默认词表能加载" {
  let loaded = match load_text("samples/sample.epub", []) {
    Some(value) => value
    None => fail("应当能读出样例书")
  }
  let text = loaded.1
  assert_eq(text.contains("他叫小明"), true)
  assert_eq(text.contains("PK"), false)
  // 默认词表是仓库里的 HSK 3.0
  assert_eq(loaded.0.size() > 9000, true)
}

///|
test "读不出来时返回 None，而不是崩掉" {
  match load_text("不存在的文件.txt", []) {
    None => ()
    Some(_) => fail("不存在的文件不该读成功")
  }
}
