///|
/// 生词表的等级文本。
pub fn level_label(level : Int) -> String {
  if level == 0 {
    "未收录"
  } else {
    "HSK \{level}"
  }
}

///|
/// 把生词表导出成 Anki 可以直接导入的文本。
///
/// 前四行是 Anki 的注释头：声明用 Tab 分隔、不解析 HTML、打上标签，
/// 导入时不用手动设置。字段里的制表符和换行会被替换成空格——
/// 否则一句话就能把列结构撑破。
pub fn vocab_to_anki_tsv(entries : Array[@learner.VocabEntry]) -> String {
  let mut out = "#separator:tab\n#html:false\n#tags:stepwise\n#columns:Word\tPinyin\tLevel\tContext\n"
  for entry in entries {
    out = out +
      escape_cell(entry.word) +
      "\t" +
      escape_cell(entry.pinyin) +
      "\t" +
      level_label(entry.level) +
      "\t" +
      escape_cell(entry.first_sentence) +
      "\n"
  }
  out
}

///|
/// 清掉会破坏 TSV 列结构的字符。
pub fn escape_cell(text : String) -> String {
  text
  .replace_all(old="\t", new=" ")
  .replace_all(old="\n", new=" ")
  .replace_all(old="\r", new=" ")
}
