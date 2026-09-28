///|
/// 点一段时可以选几种解释方式。
///
/// 每种方式都是「同一件事的不同切法」：有的给你读得懂的改写，
/// 有的告诉你每个生词在这句话里是什么意思，有的拆语法，
/// 有的反过来考你一句。
pub(all) enum ExplainMode {
  Simplify // 改成简单中文，附英文对照
  Words // 逐个生词解释
  Grammar // 语法拆解
  Check // 理解检查：出一道题
  Translate // 只要英文
} derive(Debug, Eq)

///|
pub extend ExplainMode with Debug::{to_repr}

///|
pub extend ExplainMode with Eq::{not_equal, equal}

///|
/// 给界面用的按钮文字。
pub fn ExplainMode::label(self : ExplainMode) -> String {
  match self {
    Simplify => "改成简单中文"
    Words => "逐词解释"
    Grammar => "语法拆解"
    Check => "理解检查"
    Translate => "英文翻译"
  }
}

///|
/// 从参数里的短名解析，认不出来就退回最常用的「改成简单中文」。
pub fn ExplainMode::parse(key : String) -> ExplainMode {
  match key {
    "words" => Words
    "grammar" => Grammar
    "check" => Check
    "translate" => Translate
    _ => Simplify
  }
}

///|
/// 这个模式的输出是不是「给学习者读的中文」，需要过可读性审计。
///
/// 纯英文翻译不审——它的作用是给个意思上的锚，不是学习者要读的材料。
pub fn ExplainMode::needs_audit(self : ExplainMode) -> Bool {
  match self {
    Translate => false
    _ => true
  }
}

///|
/// 上一轮超纲词的回灌提示，所有模式共用。
pub fn avoid_hint(avoid : Array[String], learner_level : Int) -> String {
  if avoid.length() == 0 {
    ""
  } else {
    "\n注意：上一次的输出里，这些词超出了 HSK \{learner_level}，请全部换掉：\{avoid.join("、")}。"
  }
}

///|
/// 按模式组装提示词。
pub fn explain_request(
  mode : ExplainMode,
  sentence : String,
  learner_level : Int,
  avoid : Array[String],
) -> LlmRequest {
  let hint = avoid_hint(avoid, learner_level)
  match mode {
    Simplify => sentence_help_prompt(sentence, learner_level, avoid)
    Translate => {
      let user = "把下面这句话翻译成自然、地道的英文，只输出英文：\n\{sentence}"
      { system: TEACHER_SYSTEM, user, temperature_permille: 300, }
    }
    Words => {
      let user = "学习者水平：HSK \{learner_level}\n" +
        "他正在读的句子：\{sentence}\n\n" +
        "请把这句话里超出他水平的词挑出来，每个词一行，格式是「词：它在这句话里的意思」。\n" +
        "解释要用 HSK \{learner_level} 及以内的词，不要给英文。\{hint}"
      { system: TEACHER_SYSTEM, user, temperature_permille: 300, }
    }
    Grammar => {
      let user = "学习者水平：HSK \{learner_level}\n" +
        "他正在读的句子：\{sentence}\n\n" +
        "请拆解这句话的语法：主干是什么，修饰部分挂在哪里，有没有值得注意的句型。\n" +
        "用 HSK \{learner_level} 及以内的词写，三到五句，不要给英文。\{hint}"
      { system: TEACHER_SYSTEM, user, temperature_permille: 300, }
    }
    Check => {
      let user = "学习者水平：HSK \{learner_level}\n" +
        "他正在读的句子：\{sentence}\n\n" +
        "请针对这句话出一道只要一个短句就能回答的理解题，先写「问：」，再写「答：」。\n" +
        "都用 HSK \{learner_level} 及以内的中文。\{hint}"
      { system: TEACHER_SYSTEM, user, temperature_permille: 300, }
    }
  }
}

///|
/// 按模式把模型的回复拆成（正文，英文对照）。
pub fn parse_explain(mode : ExplainMode, text : String) -> (String, String) {
  match mode {
    Simplify => parse_sentence_help(text)
    _ => (text.trim().to_owned(), "")
  }
}
