///|
/// 样例书固定在 samples/sample.epub，由 tools/make_sample_epub.ps1 生成。
fn sample_epub_bytes() -> Bytes {
  @fs.read_file_to_bytes("samples/sample.epub") catch {
    _ => b""
  }
}

///|
test "打开样例 EPUB：书名与章节" {
  let book = @epub.open(sample_epub_bytes()) catch {
    e => fail("打开失败：\{e.to_string()}")
  }
  assert_eq(book.title(), "我的中国朋友")
  assert_eq(book.chapter_count(), 2)
}

///|
test "章节标题来自 title 标签，正文是纯文本" {
  let book = @epub.open(sample_epub_bytes()) catch {
    e => fail("打开失败：\{e.to_string()}")
  }
  let chapters = book.chapters()
  assert_eq(chapters[0].title, "第一章 我有一个中国朋友")
  assert_eq(chapters[1].title, "第二章 茶是一种语言")
  // 段落各占一行，标签和实体都已经处理掉
  assert_eq(chapters[0].text.contains("<p>"), false)
  assert_eq(chapters[0].text.contains("&ldquo;"), false)
  assert_eq(
    chapters[1].text.contains("“为什么中国人这么喜欢喝茶？”"),
    true,
  )
}

///|
test "整本书拼起来能拿到全部正文" {
  let book = @epub.open(sample_epub_bytes()) catch {
    e => fail("打开失败：\{e.to_string()}")
  }
  let text = book.plain_text()
  assert_eq(text.contains("他叫小明"), true)
  assert_eq(text.contains("一种看世界的方法"), true)
}

///|
test "不是压缩包时报 NotAnArchive" {
  let result : Result[@epub.Book, @epub.EpubError] = Ok(
    @epub.open(b"这不是 zip"),
  ) catch {
    e => Err(e)
  }
  match result {
    Err(@epub.EpubError::NotAnArchive(_)) => ()
    _ => fail("应当报 NotAnArchive")
  }
}
