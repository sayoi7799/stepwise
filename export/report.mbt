///|
/// 阅读难度档位的中文说明。
pub fn readability_label(entity : @learner.Readability) -> String {
  match entity {
    Comfortable => "顺畅，适合泛读"
    Stretch => "有点挑战，需要一点支撑"
    TooHard => "偏难，建议先降级改写再读"
  }
}

///|
/// 生成一份 Markdown 阅读报告。
///
/// 这份报告是产品对学习者的「交底」：你读得动吗、卡在哪些词、
/// 哪些句子最值得精读、下一步复习哪些。它也是演示视频里的主角。
pub fn markdown_report(
  title : String,
  text : String,
  lex : @lexicon.Lexicon,
  learner : @learner.Learner,
) -> String {
  let sentences = @segment.split_sentences(text)
  let stats = @learner.analyze(@segment.segment(text, lex), learner)
  let vocab = @learner.collect_vocabulary(text, lex, learner)
  let picked = @learner.pick_learning_sentences(text, lex, learner, 5)
  let mut out = "# \{title}\n\n"
  out = out + "学习者水平：HSK \{learner.level()}\n\n"
  out = out + "## 概览\n\n"
  out = out + "- 句子数：\{sentences.length()}\n"
  out = out + "- 词数：\{stats.tokens()}\n"
  out = out + "- 已知词覆盖率：\{stats.coverage_percent_text()}%\n"
  out = out +
    "- 生词：\{stats.unknown_types_count()} 个（共出现 \{stats.unknown_tokens()} 次）\n"
  out = out + "- 判定：\{readability_label(@learner.readability(stats))}\n\n"
  out = out + "## 生词表\n\n"
  if vocab.length() == 0 {
    out = out + "这一篇没有生词，可以直接读。\n\n"
  } else {
    out = out +
      "| 词 | 拼音 | 等级 | 出现 |\n| --- | --- | --- | --- |\n"
    for entry in vocab {
      out = out +
        "| \{entry.word} | \{entry.pinyin} | \{level_label(entry.level)} | \{entry.count} |\n"
    }
    out = out + "\n"
  }
  out = out + "## 值得精读的句子\n\n"
  if picked.length() == 0 {
    out = out + "还没有可推荐的句子。\n\n"
  } else {
    for report in picked {
      out = out + "- \{report.text}\n"
      let unknown = report.unknown.join("、")
      if unknown != "" {
        out = out + "  生词：\{unknown}\n"
      }
    }
    out = out + "\n"
  }
  out = out + "## 下一步\n\n"
  out = out +
    "1. 把上面的生词导出成卡片（`stepwise anki`），每天复习一批。\n"
  out = out +
    "2. 生词的解释请在语境里读，不要背中英对照。\n"
  out = out +
    "3. 第二天用同一份文本再读一遍，看看覆盖率有没有变化。\n"
  out
}

///|
/// 生成整本书的阅读报告。
///
/// 比单篇报告多一张「逐章体检表」——学习者最想知道的是
/// 「这本书我从第几章开始能读下去」，而不是一个笼统的难度分数。
pub fn markdown_book_report(
  book : @epub.Book,
  lex : @lexicon.Lexicon,
  learner : @learner.Learner,
) -> String {
  let text = book.plain_text()
  let stats = @learner.analyze(@segment.segment(text, lex), learner)
  let vocab = @learner.collect_vocabulary(text, lex, learner)
  let picked = @learner.pick_learning_sentences(text, lex, learner, 5)
  let title = if book.title() == "" { "（无书名）" } else { book.title() }
  let mut out = "# \{title}\n\n"
  out = out + "学习者水平：HSK \{learner.level()}\n\n"
  out = out + "## 全书概览\n\n"
  out = out + "- 章节数：\{book.chapter_count()}\n"
  out = out + "- 词数：\{stats.tokens()}\n"
  out = out + "- 已知词覆盖率：\{stats.coverage_percent_text()}%\n"
  out = out +
    "- 生词：\{stats.unknown_types_count()} 个（共出现 \{stats.unknown_tokens()} 次）\n"
  out = out + "- 判定：\{readability_label(@learner.readability(stats))}\n\n"
  out = out + "## 逐章体检\n\n"
  out = out +
    "| 章节 | 词数 | 覆盖率 | 判定 |\n| --- | --- | --- | --- |\n"
  let mut first_readable = 0
  let mut index = 0
  for chapter in book.chapters() {
    index = index + 1
    let chapter_stats = @learner.analyze(
      @segment.segment(chapter.text, lex),
      learner,
    )
    let readable = @learner.readability(chapter_stats)
    if first_readable == 0 && readable == Comfortable {
      first_readable = index
    }
    out = out +
      "| \{chapter.title} | \{chapter_stats.tokens()} | \{chapter_stats.coverage_percent_text()}% | \{readability_label(readable)} |\n"
  }
  out = out + "\n"
  if first_readable > 0 {
    out = out + "从第 \{first_readable} 章开始可以顺畅阅读。\n\n"
  } else {
    out = out +
      "目前还没有哪一章达到顺畅阅读的覆盖率，建议先降级改写再读。\n\n"
  }
  out = out + "## 全书生词表\n\n"
  if vocab.length() == 0 {
    out = out + "这本书没有生词，可以直接读。\n\n"
  } else {
    out = out +
      "| 词 | 拼音 | 等级 | 出现 |\n| --- | --- | --- | --- |\n"
    for entry in vocab {
      out = out +
        "| \{entry.word} | \{entry.pinyin} | \{level_label(entry.level)} | \{entry.count} |\n"
    }
    out = out + "\n"
  }
  out = out + "## 值得精读的句子\n\n"
  if picked.length() == 0 {
    out = out + "还没有可推荐的句子。\n\n"
  } else {
    for report in picked {
      out = out + "- \{report.text}\n"
      let unknown = report.unknown.join("、")
      if unknown != "" {
        out = out + "  生词：\{unknown}\n"
      }
    }
    out = out + "\n"
  }
  out = out + "## 下一步\n\n"
  out = out +
    "1. 把全书生词导出成卡片（`stepwise anki`），每天复习一批。\n"
  out = out +
    "2. 先读覆盖率最高的章节，把生词读熟再回头看前面的。\n"
  out
}
