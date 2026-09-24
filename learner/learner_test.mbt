///|
const LEARNER_LEXICON : String =
  #|我	1	wǒ
  #|喜欢	2	xǐhuan
  #|中文	1	Zhōngwén
  #|学习	2	xuéxí
  #|研究	3	yánjiū
  #|生命	4	shēngmìng
  #|起源	4	qǐyuán

///|
test "等级以内的词算认识，超出的算生词" {
  let lex = @lexicon.Lexicon::from_tsv(LEARNER_LEXICON)
  let learner = @learner.Learner::new(2)
  let tokens = @segment.segment("我喜欢学习研究", lex)
  let stats = @learner.analyze(tokens, learner)
  assert_eq(stats.tokens(), 4)
  assert_eq(stats.known(), 3)
  assert_eq(stats.unknown_types_count(), 1)
  assert_eq(stats.unknown_types()[0], "研究")
}

///|
test "词表没收录的词算生词" {
  let lex = @lexicon.Lexicon::from_tsv(LEARNER_LEXICON)
  let learner = @learner.Learner::new(9)
  let tokens = @segment.segment("我喜欢猫", lex)
  let stats = @learner.analyze(tokens, learner)
  assert_eq(stats.unknown_types()[0], "猫")
}

///|
test "额外认识的词不再算生词" {
  let lex = @lexicon.Lexicon::from_tsv(LEARNER_LEXICON)
  let learner = @learner.Learner::new(1)
  learner.mark_known("研究")
  let tokens = @segment.segment("我研究中文", lex)
  let stats = @learner.analyze(tokens, learner)
  assert_eq(stats.unknown_types_count(), 0)
  assert_eq(learner.extra_known_count(), 1)
}

///|
test "覆盖率是千分数，标点不计入" {
  let lex = @lexicon.Lexicon::from_tsv(LEARNER_LEXICON)
  let learner = @learner.Learner::new(2)
  let tokens = @segment.segment("我喜欢你。", lex)
  let stats = @learner.analyze(tokens, learner)
  // 我(1) / 喜欢(2) / 你(未收录) 三个词，前两个认识，句号不计入
  assert_eq(stats.tokens(), 3)
  assert_eq(stats.coverage_permille(), 666)
  assert_eq(stats.coverage_percent_text(), "66.6")
}

///|
test "覆盖率分档的三个边界" {
  let lex = @lexicon.Lexicon::from_tsv(LEARNER_LEXICON)
  let learner = @learner.Learner::new(4)
  let easy = @learner.analyze(@segment.segment("我喜欢中文", lex), learner)
  assert_eq(@learner.readability(easy), @learner.Readability::Comfortable)
  let hard = @learner.analyze(
    @segment.segment("我喜欢猫和狗", lex),
    learner,
  )
  assert_eq(@learner.readability(hard), @learner.Readability::TooHard)
}

///|
test "等级被夹在 0 到 9 之间" {
  assert_eq(@learner.Learner::new(-3).level(), 0)
  assert_eq(@learner.Learner::new(42).level(), 9)
}

///|
test "空文本的覆盖率按 100% 处理" {
  let learner = @learner.Learner::new(1)
  let stats = @learner.analyze([], learner)
  assert_eq(stats.tokens(), 0)
  assert_eq(stats.coverage_permille(), 1000)
}

///|
test "被解释的词可以排除在生词之外" {
  let lex = @lexicon.Lexicon::from_tsv(LEARNER_LEXICON)
  let learner = @learner.Learner::new(1)
  let tokens = @segment.segment("我研究中文", lex)
  // 研究是 3 级词，对 1 级学习者算生词
  assert_eq(@learner.analyze(tokens, learner).unknown_types_count(), 1)
  // 但如果这一句就是在解释「研究」，它本身不该算超纲
  let ignored = @learner.analyze_ignoring(tokens, learner, ["研究"])
  assert_eq(ignored.unknown_types_count(), 0)
  assert_eq(ignored.coverage_permille(), 1000)
  assert_eq(ignored.tokens(), 3)
}

///|
test "句子评分：0 个生词 1 分，1-3 个 3 分，4 个以上 2 分" {
  assert_eq(@learner.sentence_score(0), 1)
  assert_eq(@learner.sentence_score(1), 3)
  assert_eq(@learner.sentence_score(3), 3)
  assert_eq(@learner.sentence_score(4), 2)
}

///|
test "挑出的学习句按分值排序，同分保持原文顺序" {
  let lex = @lexicon.Lexicon::from_tsv(LEARNER_LEXICON)
  let learner = @learner.Learner::new(2)
  let text = "我喜欢中文。我喜欢研究生命。我喜欢中文，也喜欢猫。"
  let picked = @learner.pick_learning_sentences(text, lex, learner, 2)
  // 第一句 0 个生词（1 分）；第二句 2 个（3 分）；第三句 2 个（3 分）。
  // 高分的两句都保留，且第二句在第三句之前——同分不乱序。
  assert_eq(picked.length(), 2)
  assert_eq(picked[0].text, "我喜欢研究生命。")
  assert_eq(picked[1].text, "我喜欢中文，也喜欢猫。")
}

///|
test "生词表按等级排序，未收录的排最后，并带上原句" {
  let lex = @lexicon.Lexicon::from_tsv(LEARNER_LEXICON)
  let learner = @learner.Learner::new(1)
  let text = "我喜欢研究猫。"
  let vocab = @learner.collect_vocabulary(text, lex, learner)
  assert_eq(vocab.length(), 3)
  assert_eq(vocab[0].word, "喜欢")
  assert_eq(vocab[0].level, 2)
  assert_eq(vocab[0].pinyin, "xǐhuan")
  assert_eq(vocab[1].word, "研究")
  assert_eq(vocab[1].level, 3)
  assert_eq(vocab[2].word, "猫")
  assert_eq(vocab[2].level, 0)
  assert_eq(vocab[2].count, 1)
  assert_eq(vocab[2].first_sentence, "我喜欢研究猫。")
}

///|
test "生词表在重复出现时只保留一条并累计次数" {
  let lex = @lexicon.Lexicon::from_tsv(LEARNER_LEXICON)
  let learner = @learner.Learner::new(1)
  let vocab = @learner.collect_vocabulary("猫猫猫。", lex, learner)
  assert_eq(vocab.length(), 1)
  assert_eq(vocab[0].count, 3)
}
