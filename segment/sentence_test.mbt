///|
test "断句：句号、叹号、问号都断" {
  let sentences = @segment.split_sentences(
    "今天天气很好。我们去看电影吧！你去吗？",
  )
  assert_eq(sentences.length(), 3)
  assert_eq(sentences[0], "今天天气很好。")
  assert_eq(sentences[2], "你去吗？")
}

///|
test "断句：收尾的引号跟着上一句走" {
  let sentences = @segment.split_sentences(
    "他说：“你好。”然后走了。",
  )
  assert_eq(sentences.length(), 2)
  assert_eq(sentences[0], "他说：“你好。”")
  assert_eq(sentences[1], "然后走了。")
}

///|
test "断句：省略号与半角问号" {
  let sentences = @segment.split_sentences("我想了想……算了。")
  assert_eq(sentences.length(), 2)
  assert_eq(sentences[0], "我想了想……")
}

///|
test "断句：连着的句末标点只断一次" {
  let sentences = @segment.split_sentences("真的吗？！我不信。")
  assert_eq(sentences.length(), 2)
  assert_eq(sentences[0], "真的吗？！")
}

///|
test "断句：换行断句，空白片段被丢掉" {
  let sentences = @segment.split_sentences("第一行\n\n第二行")
  assert_eq(sentences.length(), 2)
  assert_eq(sentences[0], "第一行")
}

///|
test "断句：小数点和英文缩写不误判" {
  let sentences = @segment.split_sentences("圆周率是 3.14 左右。")
  assert_eq(sentences.length(), 1)
}

///|
test "断句：空文本得到空结果" {
  assert_eq(@segment.split_sentences("").length(), 0)
  assert_eq(@segment.split_sentences("   \n  ").length(), 0)
}
