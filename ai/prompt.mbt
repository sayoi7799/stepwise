///|
/// 提示词里的共同约束。
///
/// 这一句是整个产品立场的技术表达：不要翻译成英文，而是用学习者
/// 已经掌握的中文去解释新的中文。解释本身就是可理解的输入。
const TEACHER_SYSTEM : String = "你是一位面向外国学习者的中文老师。请用中文解释，不要翻译成英文。" +
  "解释里出现的词要尽量控制在学习者当前水平之内，能用一个简单句说清就不要写一段。"

///|
/// 让学生在语境里理解一个词。
///
/// `avoid` 是上一次尝试里被审计判定为超纲的词。重试时把它们点名列出来，
/// 模型才知道具体该换掉什么——只说「太难了」是没有信息量的。
pub fn explain_word_prompt(
  word : String,
  pinyin : String,
  level : Int,
  sentence : String,
  learner_level : Int,
  avoid : Array[String],
) -> LlmRequest {
  let level_text = if level == 0 { "未收录" } else { "HSK \{level}" }
  let strict_text = if avoid.length() == 0 {
    ""
  } else {
    let listed = avoid.join("、")
    "\n注意：上一次的解释对学习者太难了。下面这些词超出了 HSK \{learner_level}，" +
    "请全部换掉，改用更简单的说法：\{listed}。句子要短，不要写书面语。"
  }
  let user = "学习者水平：HSK \{learner_level}\n" +
    "要解释的词：\{word}（拼音 \{pinyin}，等级 \{level_text}）\n" +
    "它所在的句子：\{sentence}\n\n" +
    "请给出：\n" +
    "1. 这个词在这句话里的意思（一句话）；\n" +
    "2. 一个同样是 HSK \{learner_level} 水平的例子。\n" +
    "不要给英文翻译。\{strict_text}"
  { system: TEACHER_SYSTEM, user, temperature_permille: 300, }
}

///|
/// 分级改写：把超出水平的句子改写成一堆「只比现在难一点点」的话。
pub fn rewrite_sentence_prompt(
  sentence : String,
  unknown_words : Array[String],
  learner_level : Int,
) -> LlmRequest {
  let listed = unknown_words.join("、")
  let user = "学习者水平：HSK \{learner_level}\n" +
    "原句：\{sentence}\n" +
    "超出水平的词：\{listed}\n\n" +
    "请把这句话改写成学习者能看懂的中文，保留原意，只保留一到两个新词。"
  { system: TEACHER_SYSTEM, user, temperature_permille: 300, }
}

///|
/// 让模型写一道只有一句话就能答的理解检查题，用来确认真的读懂了。
pub fn comprehension_check_prompt(
  sentence : String,
  learner_level : Int,
) -> LlmRequest {
  let user = "学习者水平：HSK \{learner_level}\n" +
    "句子：\{sentence}\n\n" +
    "请出一道只需要用一个短句回答的理解题，并给出参考答案。都用中文。"
  { system: TEACHER_SYSTEM, user, temperature_permille: 300, }
}

///|
/// 点一句话时用的提示词：改写成学习者读得懂的中文，再附一句英文对照。
///
/// 输出格式写死在提示词里，因为客户端要按前缀把两段拆开；
/// 拆不出来时会退化成「整段当中文」，不会崩。
///
/// `avoid` 是上一轮被判超纲的词，重试时点名让模型换掉。
pub fn sentence_help_prompt(
  sentence : String,
  learner_level : Int,
  avoid : Array[String],
) -> LlmRequest {
  let strict_text = if avoid.length() == 0 {
    ""
  } else {
    let listed = avoid.join("、")
    "\n注意：上一次的改写里，这些词超出了 HSK \{learner_level}，请全部换掉：\{listed}。"
  }
  let user = "学习者水平：HSK \{learner_level}\n" +
    "他正在读的句子：\{sentence}\n\n" +
    "请做两件事，并且严格按下面的格式输出，不要加别的字：\n" +
    "简：用 HSK \{learner_level} 及以内的词，把这句话的意思改写成他读得懂的中文；\n" +
    "英：这句话的英文意思。\n" +
    "\{strict_text}"
  { system: TEACHER_SYSTEM, user, temperature_permille: 300, }
}

///|
/// 把「简：… 英：…」格式的回答拆成中文与英文两段。
///
/// 认不出格式时把整段当作中文、英文留空——宁可少给一行，
/// 也不要把模型说过的话吃掉。
pub fn parse_sentence_help(text : String) -> (String, String) {
  let mut chinese = ""
  let mut english = ""
  for line in text.split("\n") {
    let trimmed = line.trim().to_owned()
    if trimmed == "" {
      continue
    }
    if trimmed.has_prefix("简：") {
      // 「简：」是两个字符：简 + 全角冒号
      chinese = append_line(chinese, trimmed[2:].to_owned())
    } else if trimmed.has_prefix("英：") {
      english = append_line(english, trimmed[2:].to_owned())
    } else if english != "" {
      english = append_line(english, trimmed)
    } else {
      chinese = append_line(chinese, trimmed)
    }
  }
  if chinese == "" && english == "" {
    (text.trim().to_owned(), "")
  } else {
    (chinese, english)
  }
}

///|
/// 往一段文本后面接一行，中间用空格分开。
fn append_line(current : String, line : String) -> String {
  if current == "" {
    line
  } else {
    current + " " + line
  }
}
