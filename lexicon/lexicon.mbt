///|
/// 词表里的一个词：词形、等级、拼音。
///
/// 等级用 HSK 的数字表示（1-9）；0 表示「未收录」，对学习者来说等同于生词。
pub struct Word {
  text : String
  level : Int
  pinyin : String
} derive(Debug, Eq)

///|
pub extend Word with Debug::{to_repr}

///|
pub extend Word with Eq::{not_equal, equal}

///|
/// 词表。
///
/// 除了查询，还记录「最长词的长度」，供分词做最长匹配时确定该往前看几个字。
pub struct Lexicon {
  index : @hashmap.HashMap[String, Word]
  max_word_length : Int
  size : Int
}

///|
/// 空词表。所有查询都会返回 `None`。
pub fn Lexicon::empty() -> Lexicon {
  { index: @hashmap.HashMap([]), max_word_length: 0, size: 0, }
}

///|
/// 从 TSV 文本构建词表。
///
/// 行格式为 `词 <TAB> 等级 <TAB> 拼音`，拼音可省略。空行与以 `#`
/// 开头的注释行会被忽略；字段不足两列的行同样被忽略。
pub fn Lexicon::from_tsv(text : String) -> Lexicon {
  let index : @hashmap.HashMap[String, Word] = @hashmap.HashMap([])
  let mut max_word_length = 0
  let mut size = 0
  for line in text.split("\n") {
    let trimmed = line.trim().to_owned()
    if trimmed != "" && !trimmed.has_prefix("#") {
      let fields = trimmed.split("\t").to_array()
      if fields.length() >= 2 {
        let word = fields[0].trim().to_owned()
        if word != "" {
          let level = parse_level(fields[1].trim().to_owned())
          let pinyin = if fields.length() >= 3 {
            fields[2].trim().to_owned()
          } else {
            ""
          }
          index.set(word, { text: word, level, pinyin, })
          size = size + 1
          let word_length = word.char_length()
          if word_length > max_word_length {
            max_word_length = word_length
          }
        }
      }
    }
  }
  { index, max_word_length, size, }
}

///|
/// 查一个词。查不到时返回 `None`。
pub fn Lexicon::lookup(self : Lexicon, word : String) -> Word? {
  self.index.get(word)
}

///|
/// 查一个词并直接返回等级；查不到返回 0。
pub fn Lexicon::level_of(self : Lexicon, word : String) -> Int {
  match self.index.get(word) {
    Some(w) => w.level
    None => 0
  }
}

///|
/// 该词是否收录在词表里。
pub fn Lexicon::contains(self : Lexicon, word : String) -> Bool {
  self.index.contains(word)
}

///|
/// 词表规模（词条数）。
pub fn Lexicon::size(self : Lexicon) -> Int {
  self.size
}

///|
/// 词表中最长词的字数。分词的最长匹配窗口由它决定。
pub fn Lexicon::max_word_length(self : Lexicon) -> Int {
  self.max_word_length
}

///|
/// 把等级字段转成数字。认不出的写法一律当作 0（未收录），
/// 这样即使词表里混进 "1a"、"HSK3" 之类的脏数据也不会让流水线崩掉。
fn parse_level(field : String) -> Int {
  match field {
    "1" => 1
    "2" => 2
    "3" => 3
    "4" => 4
    "5" => 5
    "6" => 6
    "7" => 7
    "8" => 8
    "9" => 9
    _ => 0
  }
}
