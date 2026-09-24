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
  let mut attempt = 0
  let mut last = ""
  while attempt < max_attempts {
    let request = explain_word_prompt(
      word,
      pinyin,
      level,
      sentence,
      learner.level(),
      attempt > 0,
    )
    let response = client.complete(request)
    last = response.text
    if acceptable_explanation(audit(last, lex, learner)) {
      return last
    }
    attempt = attempt + 1
  }
  last
}
