///|
test "整句解释的提示词要求固定格式" {
  let request = @ai.sentence_help_prompt("茶不只是水。", 2, [])
  assert_eq(request.user.contains("HSK 2"), true)
  assert_eq(request.user.contains("简："), true)
  assert_eq(request.user.contains("英："), true)
}

///|
test "重试时把上一轮的超纲词点名列出" {
  let strict = @ai.sentence_help_prompt("茶不只是水。", 2, [
    "只是", "一种",
  ])
  assert_eq(strict.user.contains("请全部换掉：只是、一种"), true)
}

///|
test "按前缀拆成中英两段" {
  let (zh, en) = @ai.parse_sentence_help(
    "简：茶不只是水。\n英：Tea is not just water.",
  )
  assert_eq(zh, "茶不只是水。")
  assert_eq(en, "Tea is not just water.")
}

///|
/// 模型不守格式时不能把内容吃掉——整段当中文，英文留空。
test "格式认不出来时整段当中文" {
  let (zh, en) = @ai.parse_sentence_help(
    "茶不只是水，还是一种语言。",
  )
  assert_eq(zh, "茶不只是水，还是一种语言。")
  assert_eq(en, "")
}

///|
test "多行会拼成一段" {
  let (zh, en) = @ai.parse_sentence_help(
    "简：第一句。\n简：第二句。\n英：One.\n英：Two.",
  )
  assert_eq(zh, "第一句。 第二句。")
  assert_eq(en, "One. Two.")
}

///|
test "只有英文时中文留空" {
  let (zh, en) = @ai.parse_sentence_help("英：Hello.")
  assert_eq(zh, "")
  assert_eq(en, "Hello.")
}
