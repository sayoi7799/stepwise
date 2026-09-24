///|
test "取属性值：双引号、单引号、缺失" {
  assert_eq(
    @epub.attribute("<item href=\"a.xhtml\"/>", "href"),
    Some("a.xhtml"),
  )
  assert_eq(@epub.attribute("<item href='b.xhtml'/>", "href"), Some("b.xhtml"))
  assert_eq(@epub.attribute("<item id=\"x\"/>", "href"), None)
}

///|
test "标签名边界：item 不会匹配到 itemref" {
  let opf = "<manifest><item id=\"a\" href=\"a.xhtml\"/><itemref idref=\"a\"/></manifest>"
  assert_eq(@epub.tags(opf, "item").length(), 1)
  assert_eq(@epub.tags(opf, "itemref").length(), 1)
}

///|
test "取元素正文" {
  assert_eq(
    @epub.element_text("<dc:title>我的中国朋友</dc:title>", "dc:title"),
    Some("我的中国朋友"),
  )
  assert_eq(@epub.element_text("<a>x</a>", "b"), None)
}

///|
test "实体解码：命名与数字" {
  assert_eq(@epub.decode_entities("&ldquo;你好&rdquo;"), "“你好”")
  assert_eq(@epub.decode_entities("a&amp;b"), "a&b")
  assert_eq(@epub.decode_entities("&#20013;&#x6587;"), "中文")
  // 认不出来的保持原样，不要悄悄吃掉
  assert_eq(@epub.decode_entities("&unknown;"), "&unknown;")
  assert_eq(@epub.decode_entities("100% & 5"), "100% & 5")
}

///|
test "删元素：连带内容一起删掉" {
  let html = "<head><title>t</title></head><body>正文</body>"
  assert_eq(@epub.remove_element(html, "head"), "<body>正文</body>")
}

///|
test "XHTML 转纯文本：块级标签断行，标签消失，实体还原" {
  let html = "<html><head><title>标题</title></head><body><h1>第一章</h1><p>甲。</p><p>乙 &amp; 丙。</p><script>var x=1;</script></body></html>"
  assert_eq(@epub.xhtml_to_text(html), "第一章\n甲。\n乙 & 丙。")
}

///|
test "空行会被压掉" {
  assert_eq(
    @epub.normalize_lines("  甲  \n\n  乙\n\n\n丙 "),
    "甲\n乙\n丙",
  )
}
