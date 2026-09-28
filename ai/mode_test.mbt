///|
test "模式解析：认得的走对应模式，认不出的退回简单中文" {
  assert_eq(@ai.ExplainMode::parse("words"), @ai.ExplainMode::Words)
  assert_eq(@ai.ExplainMode::parse("grammar"), @ai.ExplainMode::Grammar)
  assert_eq(@ai.ExplainMode::parse("check"), @ai.ExplainMode::Check)
  assert_eq(@ai.ExplainMode::parse("translate"), @ai.ExplainMode::Translate)
  assert_eq(@ai.ExplainMode::parse("随便写的"), @ai.ExplainMode::Simplify)
}

///|
test "每个模式都有给按钮用的名字" {
  assert_eq(@ai.ExplainMode::Simplify.label(), "改成简单中文")
  assert_eq(@ai.ExplainMode::Words.label(), "逐词解释")
  assert_eq(@ai.ExplainMode::Grammar.label(), "语法拆解")
  assert_eq(@ai.ExplainMode::Check.label(), "理解检查")
  assert_eq(@ai.ExplainMode::Translate.label(), "英文翻译")
}

///|
/// 只有纯英文翻译不过审计——它的作用是给个意思上的锚。
test "只有纯英文翻译不需要过可读性审计" {
  assert_eq(@ai.ExplainMode::Simplify.needs_audit(), true)
  assert_eq(@ai.ExplainMode::Words.needs_audit(), true)
  assert_eq(@ai.ExplainMode::Grammar.needs_audit(), true)
  assert_eq(@ai.ExplainMode::Check.needs_audit(), true)
  assert_eq(@ai.ExplainMode::Translate.needs_audit(), false)
}

///|
test "每个模式的提示词都带上原句" {
  let sentence = "茶不只是水，还是一种语言。"
  for
    mode in [
      @ai.ExplainMode::Simplify,
      @ai.ExplainMode::Words,
      @ai.ExplainMode::Grammar,
      @ai.ExplainMode::Check,
      @ai.ExplainMode::Translate,
    ] {
    let request = @ai.explain_request(mode, sentence, 2, [])
    assert_eq(request.user.contains("茶不只是水"), true)
  }
}

///|
/// 教中文的那几个模式必须写明学习者水平；纯翻译不用——它不产出学习材料。
test "教学类模式写明学习者水平，纯翻译不写" {
  for
    mode in [
      @ai.ExplainMode::Simplify,
      @ai.ExplainMode::Words,
      @ai.ExplainMode::Grammar,
      @ai.ExplainMode::Check,
    ] {
    assert_eq(
      @ai.explain_request(mode, "句子", 2, []).user.contains("HSK 2"),
      true,
    )
  }
  assert_eq(
    @ai.explain_request(@ai.ExplainMode::Translate, "句子", 2, []).user.contains(
      "HSK 2",
    ),
    false,
  )
}

///|
test "逐词解释和语法拆解要求用中文给答案" {
  let words = @ai.explain_request(@ai.ExplainMode::Words, "句子", 3, [])
  assert_eq(words.user.contains("不要给英文"), true)
  assert_eq(words.user.contains("超出他水平的词"), true)
  let grammar = @ai.explain_request(@ai.ExplainMode::Grammar, "句子", 3, [])
  assert_eq(grammar.user.contains("拆解这句话的语法"), true)
}

///|
test "重试的超纲词会点名列出" {
  let request = @ai.explain_request(@ai.ExplainMode::Words, "句子", 2, [
    "只是", "一种",
  ])
  assert_eq(request.user.contains("请全部换掉：只是、一种"), true)
}

///|
test "英文翻译模式只要英文正文" {
  let (body, en) = @ai.parse_explain(
    @ai.ExplainMode::Translate,
    "Tea is more than water.",
  )
  assert_eq(body, "Tea is more than water.")
  assert_eq(en, "")
}
