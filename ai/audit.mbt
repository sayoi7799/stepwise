///|
/// 用我们自己的分词器和学习者模型去审一份模型输出。
///
/// 这是这个项目最关键的一个设计：模型的解释也要被当作「读物」来评估。
/// 如果解释本身超出学习者水平，那它就起不到可理解输入的作用。
pub fn audit(
  text : String,
  lex : @lexicon.Lexicon,
  learner : @learner.Learner,
) -> @learner.TextStats {
  @learner.analyze(@segment.segment(text, lex), learner)
}

///|
/// 审一段「解释某词」的文本，把被解释的词本身排除在生词之外。
///
/// 少了这一步，任何解释都会因为提到了那个新词而被判成偏难——
/// 度量会一直说谎，模型再改也过不了门槛。
pub fn audit_explanation(
  text : String,
  lex : @lexicon.Lexicon,
  learner : @learner.Learner,
  word : String,
) -> @learner.TextStats {
  @learner.analyze_ignoring(@segment.segment(text, lex), learner, [word])
}

///|
/// 解释是否够浅：覆盖率至少 95%。
pub fn acceptable_explanation(stats : @learner.TextStats) -> Bool {
  stats.coverage_permille() >= 950
}

///|
/// 带质量闸门的解释生成。
///
/// 流程是「生成 → 用自己的尺度审 → 不过就带着更严的约束重试」。
/// 最多试 `max_attempts` 次，全部不达标时返回最后一次的结果——
/// 宁可交付一份略难的答案，也不要让整个阅读流程卡住。
/// 一次尝试的记录：第几轮、模型给的原话、这一轮的可读性覆盖率。
///
/// 把尝试过程显式返回，而不是用回调往外捅——回调在异步函数里
/// 既难写也难测，而一个数组既好断言又好展示。
pub struct Attempt {
  round : Int
  text : String
  coverage_permille : Int
} derive(Debug)

///|
pub extend Attempt with Debug::{to_repr}

///|
/// 这一段解释是否已经够浅。
pub fn Attempt::acceptable(self : Attempt) -> Bool {
  self.coverage_permille >= 950
}

///|
/// 覆盖率文本，例如 `"93.7"`。
pub fn Attempt::coverage_text(self : Attempt) -> String {
  "\{self.coverage_permille / 10}.\{self.coverage_permille % 10}"
}

///|
/// 带质量闸门的解释生成，并把每一次尝试都记下来。
///
/// 循环是「生成 → 用自己的尺度审 → 不过就带着更严的约束重试」。
/// 达到门槛就立刻停，否则一直试到把 `max_attempts` 用完。
pub async fn[C : LlmClient] explain_traced(
  client : C,
  word : String,
  pinyin : String,
  level : Int,
  sentence : String,
  lex : @lexicon.Lexicon,
  learner : @learner.Learner,
  max_attempts : Int,
) -> Array[Attempt] raise LlmError {
  let attempts : Array[Attempt] = []
  // 上一轮被判定超纲的词，下一轮点名让模型换掉
  let mut avoid : Array[String] = []
  let mut round = 0
  while round < max_attempts {
    let request = explain_word_prompt(
      word,
      pinyin,
      level,
      sentence,
      learner.level(),
      avoid,
    )
    let response = client.complete(request)
    let stats = audit_explanation(response.text, lex, learner, word)
    avoid = stats.unknown_types()
    let attempt = {
      round: round + 1,
      text: response.text,
      coverage_permille: stats.coverage_permille(),
    }
    attempts.push(attempt)
    if attempt.acceptable() {
      break
    }
    round = round + 1
  }
  attempts
}

///|
/// 只关心最终结果时的便捷入口：返回最后一次尝试的文本。
///
/// 全程不达标时返回最后一次的结果——宁可交付一份略难的答案，
/// 也不要让整个阅读流程卡住。
pub async fn[C : LlmClient] explain_with_audit(
  client : C,
  word : String,
  pinyin : String,
  level : Int,
  sentence : String,
  lex : @lexicon.Lexicon,
  learner : @learner.Learner,
  max_attempts : Int,
) -> String raise LlmError {
  let attempts = explain_traced(
    client, word, pinyin, level, sentence, lex, learner, max_attempts,
  )
  if attempts.length() == 0 {
    ""
  } else {
    attempts[attempts.length() - 1].text
  }
}
