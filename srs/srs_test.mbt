///|
test "新卡默认 2.5 难度，第 0 天到期" {
  let card = @srs.Card::new("研究", "yánjiū", 3, "我喜欢研究生命。")
  assert_eq(card.ease_permille, 2500)
  assert_eq(card.interval_days, 0)
  assert_eq(card.reps, 0)
  assert_eq(card.due_day, 0)
  assert_eq(card.ease_text(), "2.50")
}

///|
test "连续答对：间隔走 1 天、6 天、然后按难度系数放大" {
  let card = @srs.Card::new("研究", "yánjiū", 3, "")
  let first = @srs.review(card, @srs.Grade::Good, 0)
  assert_eq(first.interval_days, 1)
  assert_eq(first.due_day, 1)
  assert_eq(first.reps, 1)
  let second = @srs.review(first, @srs.Grade::Good, 1)
  assert_eq(second.interval_days, 6)
  let third = @srs.review(second, @srs.Grade::Good, 7)
  // 6 天 × 2.5 = 15 天
  assert_eq(third.interval_days, 15)
  assert_eq(third.due_day, 22)
}

///|
test "想不起来：连续次数清零，间隔回到 1 天" {
  let card = @srs.Card::new("研究", "yánjiū", 3, "")
  let learned = @srs.review(
    @srs.review(card, @srs.Grade::Good, 0),
    @srs.Grade::Good,
    1,
  )
  let again = @srs.review(learned, @srs.Grade::Again, 7)
  assert_eq(again.reps, 0)
  assert_eq(again.interval_days, 1)
  assert_eq(again.due_day, 8)
  // 2.5 - 0.54 = 1.96
  assert_eq(again.ease_permille, 1960)
}

///|
test "简单会拉高难度系数，吃力会拉低" {
  let card = @srs.Card::new("研究", "yánjiū", 3, "")
  assert_eq(@srs.review(card, @srs.Grade::Easy, 0).ease_permille, 2600)
  assert_eq(@srs.review(card, @srs.Grade::Hard, 0).ease_permille, 2360)
  assert_eq(@srs.review(card, @srs.Grade::Good, 0).ease_permille, 2500)
}

///|
test "难度系数不会掉到 1.3 以下" {
  let mut card = @srs.Card::new("研究", "yánjiū", 3, "")
  let mut i = 0
  while i < 10 {
    card = @srs.review(card, @srs.Grade::Again, i)
    i = i + 1
  }
  assert_eq(card.ease_permille, 1300)
}

///|
test "质量分与增量对照表" {
  assert_eq(@srs.quality(@srs.Grade::Again), 1)
  assert_eq(@srs.quality(@srs.Grade::Easy), 5)
  assert_eq(@srs.ease_delta_permille(5), 100)
  assert_eq(@srs.ease_delta_permille(4), 0)
  assert_eq(@srs.ease_delta_permille(3), -140)
  assert_eq(@srs.ease_delta_permille(1), -540)
}

///|
test "今天该复习的卡片按到期日排序" {
  let a = @srs.review(@srs.Card::new("甲", "", 1, ""), @srs.Grade::Good, 0)
  let b = @srs.Card::new("乙", "", 1, "")
  let c = @srs.review(@srs.Card::new("丙", "", 1, ""), @srs.Grade::Good, 3)
  let due = @srs.due_cards([a, b, c], 4)
  let words = due.map(card => card.word)
  assert_eq(words, ["乙", "甲", "丙"])
}
