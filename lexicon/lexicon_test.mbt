///|
/// 词表是纯数据，黑盒测试直接喂 TSV 文本。
const SAMPLE : String =
  #|# 注释行应当被忽略
  #|我	1	wǒ
  #|喜欢	2	xǐhuan
  #|中文	1	Zhōngwén
  #|
  #|学习	2	xuéxí
  #|# 末尾注释

///|
test "解析 TSV：跳过空行与注释，字段不足的行被忽略" {
  let lex = @lexicon.Lexicon::from_tsv(SAMPLE)
  assert_eq(lex.size(), 4)
  assert_eq(lex.level_of("我"), 1)
  assert_eq(lex.level_of("喜欢"), 2)
}

///|
test "最长词长度决定分词窗口" {
  let lex = @lexicon.Lexicon::from_tsv(SAMPLE)
  assert_eq(lex.max_word_length(), 2)
}

///|
test "查不到的词返回 None / 等级 0" {
  let lex = @lexicon.Lexicon::from_tsv(SAMPLE)
  assert_eq(lex.lookup("苹果"), None)
  assert_eq(lex.level_of("苹果"), 0)
  assert_eq(lex.contains("苹果"), false)
}

///|
test "拼音可以省略" {
  let lex = @lexicon.Lexicon::from_tsv("你好\t1")
  match lex.lookup("你好") {
    Some(w) => assert_eq(w.pinyin, "")
    None => fail("应当查到「你好」")
  }
}

///|
test "脏数据不会让流水线崩掉" {
  let lex = @lexicon.Lexicon::from_tsv("奇怪\tHSK3\tqíguài")
  assert_eq(lex.level_of("奇怪"), 0)
}

///|
test "空词表" {
  let lex = @lexicon.Lexicon::empty()
  assert_eq(lex.size(), 0)
  assert_eq(lex.max_word_length(), 0)
}
