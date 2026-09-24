///|
test "相对路径解析" {
  assert_eq(@epub.resolve_path("OEBPS", "chap1.xhtml"), "OEBPS/chap1.xhtml")
  assert_eq(
    @epub.resolve_path("OEBPS/Text", "../Images/a.png"),
    "OEBPS/Images/a.png",
  )
  assert_eq(
    @epub.resolve_path("OEBPS", "./Text/ch1.xhtml"),
    "OEBPS/Text/ch1.xhtml",
  )
}

///|
test "绝对路径从包根算起" {
  assert_eq(
    @epub.resolve_path("OEBPS/Text", "/OEBPS/ch1.xhtml"),
    "OEBPS/ch1.xhtml",
  )
}

///|
test "越过根的 .. 直接忽略" {
  assert_eq(@epub.resolve_path("", "../../a.xhtml"), "a.xhtml")
}

///|
test "取目录部分" {
  assert_eq(@epub.dir_name("OEBPS/content.opf"), "OEBPS")
  assert_eq(@epub.dir_name("content.opf"), "")
}
