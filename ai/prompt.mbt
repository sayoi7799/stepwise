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
