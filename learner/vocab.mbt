///|
/// 一句话的学习价值评估。
pub struct SentenceReport {
  text : String
  unknown : Array[String]
  score : Int
} derive(Debug)

///|
pub extend SentenceReport with Debug::{to_repr}

///|
/// 句子的可学习程度打分。
///
/// 一个生词都没有的句子只能巩固，价值最低；一到三个生词正好落在
/// 「跳一跳够得着」的区间，价值最高；四个以上负担偏重，居中间。
pub fn sentence_score(unknown_count : Int) -> Int {
  if unknown_count == 0 {
    1
  } else if unknown_count <= 3 {
    3
  } else {
    2
  }
}

///|
/// 逐句切分并评分。
pub fn sentence_reports(
  text : String,
  lex : @lexicon.Lexicon,
  learner : Learner,
) -> Array[SentenceReport] {
  let out : Array[SentenceReport] = []
  for sentence in @segment.split_sentences(text) {
    let tokens = @segment.segment(sentence, lex)
    let stats = analyze(tokens, learner)
    out.push({
      text: sentence,
      unknown: stats.unknown_types(),
      score: sentence_score(stats.unknown_types_count()),
    })
  }
  out
}

///|
/// 挑出最适合精读的句子，按分值从高到低；同分保持原文顺序。
///
/// `limit` 为 0 或负数时返回空数组。
pub fn pick_learning_sentences(
  text : String,
  lex : @lexicon.Lexicon,
  learner : Learner,
  limit : Int,
) -> Array[SentenceReport] {
  let reports = sentence_reports(text, lex, learner)
  stable_sort_by_score(reports)
  let out : Array[SentenceReport] = []
  let mut i = 0
  while i < reports.length() && i < limit {
    out.push(reports[i])
    i = i + 1
  }
  out
}

///|
/// 按分值降序做稳定排序（插入排序）。句子数量在教材尺度内很小，
/// 自己写一遍换来的是确定的顺序，方便写精确测试。
fn stable_sort_by_score(reports : Array[SentenceReport]) -> Unit {
  let mut i = 1
  while i < reports.length() {
    let current = reports[i]
    let mut j = i
    while j > 0 && reports[j - 1].score < current.score {
      reports[j] = reports[j - 1]
      j = j - 1
    }
    reports[j] = current
    i = i + 1
  }
}

///|
/// 生词表里的一条：词形、等级、拼音、出现次数，以及首次出现的句子。
///
/// 带上原句是为了直接做「句子挖矿」式卡片——把词放回语境，
/// 比孤立背词更容易建立语感。
pub struct VocabEntry {
  word : String
  level : Int
  pinyin : String
  count : Int
  first_sentence : String
} derive(Debug)

///|
pub extend VocabEntry with Debug::{to_repr}

///|
/// 抽取整段文本的生词表。
///
/// 排序规则：先按 HSK 等级升序（等级 0 的未收录词排在最后，
/// 因为它们最难定位），等级相同按首次出现顺序。
pub fn collect_vocabulary(
  text : String,
  lex : @lexicon.Lexicon,
  learner : Learner,
) -> Array[VocabEntry] {
  let counts : @hashmap.HashMap[String, Int] = @hashmap.HashMap([])
  let order : Array[VocabEntry] = []
  for sentence in @segment.split_sentences(text) {
    let tokens = @segment.segment(sentence, lex)
    for token in tokens {
      if is_counted(token) && !learner.knows_token(token) {
        match counts.get(token.text) {
          Some(n) => counts.set(token.text, n + 1)
          None => {
            counts.set(token.text, 1)
            let pinyin = match lex.lookup(token.text) {
              Some(word) => word.pinyin
              None => ""
            }
            order.push({
              word: token.text,
              level: token.level,
              pinyin,
              count: 1,
              first_sentence: sentence,
            })
          }
        }
      }
    }
  }
  let entries : Array[VocabEntry] = []
  for entry in order {
    let count = match counts.get(entry.word) {
      Some(n) => n
      None => entry.count
    }
    entries.push({ ..entry, count, })
  }
  stable_sort_by_level(entries)
  entries
}

///|
/// 按等级升序做稳定排序，等级 0 视为最大值排到最后。
fn stable_sort_by_level(entries : Array[VocabEntry]) -> Unit {
  let mut i = 1
  while i < entries.length() {
    let current = entries[i]
    let mut j = i
    while j > 0 && sort_rank(entries[j - 1].level) > sort_rank(current.level) {
      entries[j] = entries[j - 1]
      j = j - 1
    }
    entries[j] = current
    i = i + 1
  }
}

///|
/// 排序用的等级权重：未收录（0）排到最后。
pub fn sort_rank(level : Int) -> Int {
  if level == 0 {
    100
  } else {
    level
  }
}
