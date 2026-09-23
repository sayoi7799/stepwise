///|
const EXPORT_LEXICON : String =
  #|我	1	wǒ
  #|喜欢	2	xǐhuan
  #|研究	3	yánjiū
  #|猫	0

///|
test "Anki 导出：带上注释头和四列" {
  let lex = @lexicon.Lexicon::from_tsv(EXPORT_LEXICON)
  let learner = @learner.Learner::new(1)
  let vocab = @learner.collect_vocabulary("我研究猫。", lex, learner)
  let tsv = @export.vocab_to_anki_tsv(vocab)
  assert_eq(tsv.has_prefix("#separator:tab"), true)
  assert_eq(tsv.contains("#tags:stepwise"), true)
  assert_eq(tsv.contains("研究\tyánjiū\tHSK 3\t我研究猫。"), true)
  assert_eq(tsv.contains("猫\t\t未收录\t我研究猫。"), true)
}

///|
test "Anki 导出：制表符与换行会破坏列结构，必须被替换" {
  assert_eq(@export.escape_cell("甲\t乙\n丙"), "甲 乙 丙")
}

///|
test "等级文本" {
  assert_eq(@export.level_label(0), "未收录")
  assert_eq(@export.level_label(5), "HSK 5")
}

///|
test "报告包含概览、生词表和精读建议" {
  let lex = @lexicon.Lexicon::from_tsv(EXPORT_LEXICON)
  let learner = @learner.Learner::new(1)
  let report = @export.markdown_report(
    "第一篇", "我喜欢研究猫。", lex, learner,
  )
  assert_eq(report.has_prefix("# 第一篇"), true)
  // 我 / 喜欢 / 研究 / 猫 四个词，只认识「我」
  assert_eq(report.contains("已知词覆盖率：25.0%"), true)
  assert_eq(report.contains("| 研究 | yánjiū | HSK 3 | 1 |"), true)
  assert_eq(report.contains("## 值得精读的句子"), true)
}
