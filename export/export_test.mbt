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

///|
test "难度档位的三种说法" {
  assert_eq(
    @export.readability_label(@learner.Readability::Comfortable),
    "顺畅，适合泛读",
  )
  assert_eq(
    @export.readability_label(@learner.Readability::Stretch),
    "有点挑战，需要一点支撑",
  )
  assert_eq(
    @export.readability_label(@learner.Readability::TooHard),
    "偏难，建议先降级改写再读",
  )
}

///|
test "没有生词时报告会直说" {
  let lex = @lexicon.Lexicon::from_tsv(EXPORT_LEXICON)
  let learner = @learner.Learner::new(9)
  // 猫在词表里是「未收录」，所以这里只用三个收录过的词
  let report = @export.markdown_report(
    "全认识", "我喜欢研究。", lex, learner,
  )
  assert_eq(report.contains("这一篇没有生词"), true)
}

///|
/// 整本书的报告是演示时的主角，结构必须稳。
test "整本书报告：概览、逐章表、生词表、精读句都在" {
  let bytes = @fs.read_file_to_bytes("samples/sample.epub") catch { _ => b"" }
  let book = @epub.open(bytes) catch { error => fail(error.to_string()) }
  let lex = @lexicon.Lexicon::from_tsv(EXPORT_LEXICON)
  let learner = @learner.Learner::new(2)
  let report = @export.markdown_book_report(book, lex, learner)
  assert_eq(report.has_prefix("# 我的中国朋友"), true)
  assert_eq(report.contains("## 全书概览"), true)
  assert_eq(report.contains("- 章节数：2"), true)
  assert_eq(report.contains("## 逐章体检"), true)
  assert_eq(report.contains("| 章节 | 词数 | 覆盖率 | 判定 |"), true)
  assert_eq(report.contains("第一章 我有一个中国朋友"), true)
  assert_eq(report.contains("## 全书生词表"), true)
  assert_eq(report.contains("## 值得精读的句子"), true)
  assert_eq(report.contains("## 下一步"), true)
}

///|
test "没有顺畅章节时报告会说实话" {
  let bytes = @fs.read_file_to_bytes("samples/sample.epub") catch { _ => b"" }
  let book = @epub.open(bytes) catch { error => fail(error.to_string()) }
  // 词表只有一个词，覆盖率一定不达标
  let lex = @lexicon.Lexicon::from_tsv("我\t1\twǒ")
  let report = @export.markdown_book_report(book, lex, @learner.Learner::new(2))
  assert_eq(
    report.contains("目前还没有哪一章达到顺畅阅读的覆盖率"),
    true,
  )
}
