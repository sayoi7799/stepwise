///|
const PAGE_LEXICON : String =
  #|我	1	wǒ
  #|喜欢	2	xǐhuan
  #|中文	1	Zhōngwén
  #|研究	3	yánjiū

///|
test "HTML 转义：& 先于 < 处理，避免二次转义" {
  assert_eq(@export.escape_html("a&b"), "a&amp;b")
  assert_eq(@export.escape_html("<p>"), "&lt;p&gt;")
  // 如果先转 < 再转 &，这里会变成 &amp;lt;
  assert_eq(@export.escape_html("<"), "&lt;")
  assert_eq(@export.escape_html("\"x'"), "&quot;x&#39;")
}

///|
/// 正文里的尖括号必须变成实体，否则电子书内容会被当成标签执行。
test "正文里的 HTML 标签会被转义，不会破坏页面结构" {
  let lex = @lexicon.Lexicon::from_tsv(PAGE_LEXICON)
  let learner = @learner.Learner::new(1)
  let page = @export.study_page(
    "测试",
    "我喜欢<b>中文</b>。",
    lex,
    learner,
    [],
  )
  assert_eq(page.contains("&lt;b&gt;"), true)
  assert_eq(page.contains("<b>中文</b>"), false)
}

///|
test "生词高亮，认识的词不高亮" {
  let lex = @lexicon.Lexicon::from_tsv(PAGE_LEXICON)
  let learner = @learner.Learner::new(1)
  let page = @export.study_page("测试", "我喜欢研究。", lex, learner, [])
  // 研究是 3 级词，对 1 级学习者算生词
  assert_eq(page.contains("class=\"w new\""), true)
  assert_eq(page.contains("data-tip=\"HSK 3\""), true)
}

///|
test "页头给出覆盖率与判定" {
  let lex = @lexicon.Lexicon::from_tsv(PAGE_LEXICON)
  let learner = @learner.Learner::new(2)
  let page = @export.study_page(
    "我的书",
    "我喜欢中文。",
    lex,
    learner,
    [],
  )
  assert_eq(page.has_prefix("<!DOCTYPE html>"), true)
  assert_eq(page.contains("<title>拾级 · 我的书</title>"), true)
  assert_eq(page.contains("学习者水平：HSK 2"), true)
  assert_eq(page.contains("已知词覆盖率 100.0%"), true)
  assert_eq(page.contains("判定：顺畅，适合泛读"), true)
}

///|
test "生词表有模型解释时多一列，没有时不加空列" {
  let lex = @lexicon.Lexicon::from_tsv(PAGE_LEXICON)
  let learner = @learner.Learner::new(1)
  let plain = @export.study_page("测试", "我喜欢研究。", lex, learner, [])
  assert_eq(plain.contains("<th>解释</th>"), false)
  let rich = @export.study_page("测试", "我喜欢研究。", lex, learner, [
    ("研究", "研究就是仔细地看一件事。"),
  ])
  assert_eq(rich.contains("<th>解释</th>"), true)
  assert_eq(rich.contains("研究就是仔细地看一件事。"), true)
}

///|
test "页面自包含：没有任何外部资源引用" {
  let lex = @lexicon.Lexicon::from_tsv(PAGE_LEXICON)
  let page = @export.study_page(
    "测试",
    "我喜欢中文。",
    lex,
    @learner.Learner::new(1),
    [],
  )
  assert_eq(page.contains("<link"), false)
  assert_eq(page.contains("<script"), false)
  assert_eq(page.contains("http://"), false)
  assert_eq(page.contains("https://"), false)
}

///|
/// 交互模式才注入脚本：静态页面点不动是设计如此，不是 bug。
test "交互模式注入点击脚本，静态模式不注入" {
  let lex = @lexicon.Lexicon::from_tsv(PAGE_LEXICON)
  let learner = @learner.Learner::new(1)
  let plain = @export.study_page("测试", "我喜欢中文。", lex, learner, [])
  assert_eq(plain.contains("<script"), false)
  let live = @export.study_page(
    "测试",
    "我喜欢中文。",
    lex,
    learner,
    [],
    interactive=true,
  )
  assert_eq(live.contains("<script"), true)
  assert_eq(live.contains("askExplain"), true)
  // 走同源相对路径，不写死主机名和端口
  assert_eq(live.contains("fetch('explain'"), true)
  assert_eq(live.contains("127.0.0.1"), false)
}

///|
test "没有正文时给出提示而不是空页" {
  let lex = @lexicon.Lexicon::from_tsv(PAGE_LEXICON)
  let page = @export.study_page(
    "空书",
    "   \n  ",
    lex,
    @learner.Learner::new(1),
    [],
  )
  assert_eq(page.contains("这一篇没有正文"), true)
}

///|
/// 端到端：样例 EPUB 生成的学习版页面必须是完整可打开的文档。
test "整本 EPUB 生成学习版网页" {
  let bytes = @fs.read_file_to_bytes("samples/sample.epub") catch { _ => b"" }
  let book = @epub.open(bytes) catch { error => fail(error.to_string()) }
  let lex = @lexicon.Lexicon::from_tsv(PAGE_LEXICON)
  let learner = @learner.Learner::new(2)
  let page = @export.study_page(book.title(), book.plain_text(), lex, learner, [])
  assert_eq(page.contains("<title>拾级 · 我的中国朋友</title>"), true)
  assert_eq(page.contains("他叫小明"), true)
  assert_eq(page.has_suffix("</html>\n"), true)
}
