///|
const AI_LEXICON : String =
  #|我	1	wǒ
  #|喜欢	2	xǐhuan
  #|中文	1	Zhōngwén
  #|这个	1	zhège
  #|词	1	cí
  #|意思	1	yìsi
  #|很	1	hěn
  #|好	1	hǎo
  #|看	1	kàn
  #|书	1	shū
  #|的	1	de
  #|是	1	shì
  #|深奥	7	shēn'ào
  #|晦涩	7	huìsè
  #|诠释	7	quánshì

///|
test "提示词带上学习者水平和原句" {
  let request = @ai.explain_word_prompt(
    "词",
    "cí",
    3,
    "这个中文词很好。",
    2,
    [],
  )
  assert_eq(request.user.contains("HSK 2"), true)
  assert_eq(request.user.contains("这个中文词很好。"), true)
  assert_eq(request.user.contains("不要给英文翻译"), true)
  assert_eq(request.temperature_text(), "0.3")
}

///|
test "重试时把上一轮的超纲词点名列出" {
  let normal = @ai.explain_word_prompt(
    "词",
    "cí",
    3,
    "这个中文词很好。",
    2,
    [],
  )
  let strict = @ai.explain_word_prompt(
    "词",
    "cí",
    3,
    "这个中文词很好。",
    2,
    ["好玩", "让人"],
  )
  assert_eq(
    strict.user.contains("上一次的解释对学习者太难了"),
    true,
  )
  // 关键：不是笼统说「太难」，而是把具体该换掉的词列出来
  assert_eq(strict.user.contains("好玩、让人"), true)
  assert_eq(strict.user.length() > normal.user.length(), true)
}

///|
test "审计：超纲词太多的解释不通过" {
  let lex = @lexicon.Lexicon::from_tsv(AI_LEXICON)
  let learner = @learner.Learner::new(2)
  let hard = @ai.audit("这个诠释深奥晦涩。", lex, learner)
  assert_eq(@ai.acceptable_explanation(hard), false)
  let easy = @ai.audit("这个词的意思是很喜欢看书。", lex, learner)
  assert_eq(@ai.acceptable_explanation(easy), true)
  assert_eq(easy.coverage_permille(), 1000)
}

///|
test "审计解释时，被解释的词本身不算超纲" {
  let lex = @lexicon.Lexicon::from_tsv(AI_LEXICON)
  let learner = @learner.Learner::new(2)
  // 深奥是 7 级词，对 2 级学习者算生词
  let naive = @ai.audit("深奥的意思是不好懂。", lex, learner)
  assert_eq(naive.unknown_types_count() > 0, true)
  // 但如果正在解释的就是「深奥」，它出现在句子里是必然的
  let fair = @ai.audit_explanation(
    "深奥的意思是不好懂。", lex, learner, "深奥",
  )
  assert_eq(fair.unknown_types_count() < naive.unknown_types_count(), true)
}

///|
async test "质量闸门：第一次太深就带着更严的约束重试" {
  let lex = @lexicon.Lexicon::from_tsv(AI_LEXICON)
  let learner = @learner.Learner::new(2)
  let client = @ai.ScriptedClient::new([
    "这个诠释深奥晦涩。", "这个词的意思是很喜欢看书。",
  ])
  let answer = @ai.explain_with_audit(
    client, "词", "cí", 3, "这个中文词很好。", lex, learner, 3,
  )
  assert_eq(answer, "这个词的意思是很喜欢看书。")
  assert_eq(client.calls(), 2)
  // 第二次调用带上了加严提示
  assert_eq(client.prompts()[1].contains("太难了"), true)
}

///|
async test "质量闸门：一直不达标时返回最后一次结果，不卡住流程" {
  let lex = @lexicon.Lexicon::from_tsv(AI_LEXICON)
  let learner = @learner.Learner::new(1)
  let client = @ai.ScriptedClient::new([
    "这个诠释深奥晦涩。", "深奥", "晦涩",
  ])
  let answer = @ai.explain_with_audit(
    client, "词", "cí", 3, "这个词很好。", lex, learner, 3,
  )
  assert_eq(answer, "晦涩")
  assert_eq(client.calls(), 3)
}

///|
async test "脚本用尽时报 BadResponse" {
  let client = @ai.ScriptedClient::new([])
  let request = @ai.explain_word_prompt("词", "cí", 3, "句子", 1, [])
  let result : Result[@ai.LlmResponse, @ai.LlmError] = Ok(
    client.complete(request),
  ) catch {
    error => Err(error)
  }
  match result {
    Err(@ai.LlmError::BadResponse(message)) =>
      assert_eq(message, "脚本里已经没有更多回复了")
    _ => fail("应当报 BadResponse")
  }
}

///|
test "分级改写提示词会列出超纲词" {
  let request = @ai.rewrite_sentence_prompt(
    "我喜欢研究生命的起源。",
    ["研究", "生命"],
    2,
  )
  assert_eq(request.user.contains("研究、生命"), true)
  assert_eq(request.user.contains("只保留一到两个新词"), true)
}
