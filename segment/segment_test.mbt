///|
/// 分词测试用的词表。
const SEG_LEXICON : String =
  #|我	1	wǒ
  #|喜欢	2	xǐhuan
  #|学习	2	xuéxí
  #|中文	1	Zhōngwén
  #|在	1	zài
  #|看电影	3
  #|电影	2	diànyǐng
  #|研究	3	yánjiū
  #|研究生	4	yánjiūshēng
  #|生命	4	shēngmìng
  #|起源	4	qǐyuán
  #|的	1	de

///|
test "分词：简单句子按词切开" {
  let lex = @lexicon.Lexicon::from_tsv(SEG_LEXICON)
  let tokens = @segment.segment("我喜欢学习中文", lex)
  let words = tokens.map(t => t.text)
  assert_eq(words, ["我", "喜欢", "学习", "中文"])
}

///|
test "分词：每个 token 带上 HSK 等级" {
  let lex = @lexicon.Lexicon::from_tsv(SEG_LEXICON)
  let tokens = @segment.segment("我喜欢中文", lex)
  assert_eq(tokens[0].level, 1)
  assert_eq(tokens[1].level, 2)
  assert_eq(tokens[2].level, 1)
}

///|
test "分词：词表里没有的字算生词（等级 0）" {
  let lex = @lexicon.Lexicon::from_tsv(SEG_LEXICON)
  let tokens = @segment.segment("我喜欢猫", lex)
  let last = tokens[tokens.length() - 1]
  assert_eq(last.text, "猫")
  assert_eq(last.level, 0)
}

///|
test "分词：数字与英文各成一个 token" {
  let lex = @lexicon.Lexicon::from_tsv(SEG_LEXICON)
  let tokens = @segment.segment("我在学 Python 3.14", lex)
  let kinds = tokens.filter(t => t.kind != @segment.TokenKind::Space)
  assert_eq(kinds[3].text, "Python")
  assert_eq(kinds[3].kind, @segment.TokenKind::Latin)
  assert_eq(kinds[4].text, "3.14")
  assert_eq(kinds[4].kind, @segment.TokenKind::Number)
}

///|
test "分词：双向匹配能纠正正向匹配的错切" {
  let lex = @lexicon.Lexicon::from_tsv(SEG_LEXICON)
  // 正向最大匹配会先吃下「研究生」，把句子切成 研究生 / 命 / 起源；
  // 反向最大匹配得到 研究 / 生命 / 起源，词数相同但单字更少，胜出。
  let tokens = @segment.segment("研究生命的起源", lex)
  let words = tokens.map(t => t.text)
  assert_eq(words, ["研究", "生命", "的", "起源"])
}

///|
test "分词：偏移量能在原串上定位" {
  let lex = @lexicon.Lexicon::from_tsv(SEG_LEXICON)
  let text = "我喜欢中文"
  let tokens = @segment.segment(text, lex)
  for token in tokens {
    assert_eq(text[token.begin:token.end].to_owned(), token.text)
  }
}

///|
test "分词：空文本" {
  let lex = @lexicon.Lexicon::from_tsv(SEG_LEXICON)
  assert_eq(@segment.segment("", lex).length(), 0)
}

///|
test "分词：没有词表时退化成逐字切分" {
  let tokens = @segment.segment("中国人", @lexicon.Lexicon::empty())
  let words = tokens.map(t => t.text)
  assert_eq(words, ["中", "国", "人"])
}
