///|
/// 把 OPF 里的相对路径解析成压缩包内的绝对路径。
///
/// 例：`resolve_path("OEBPS", "Text/ch1.xhtml")` → `"OEBPS/Text/ch1.xhtml"`；
/// `resolve_path("OEBPS/Text", "../Images/a.png")` → `"OEBPS/Images/a.png"`。
/// 以 `/` 开头视为从包根算起；`.` 与 `..` 会被消解，越过根的 `..` 直接忽略。
pub fn resolve_path(base_dir : String, href : String) -> String {
  let segments : Array[String] = []
  if !href.has_prefix("/") && base_dir != "" {
    for segment in base_dir.split("/") {
      let piece = segment.to_owned()
      if piece != "" {
        segments.push(piece)
      }
    }
  }
  for segment in href.split("/") {
    let piece = segment.to_owned()
    if piece == "" || piece == "." {
      continue
    } else if piece == ".." {
      if segments.length() > 0 {
        let _ = segments.pop()
      }
    } else {
      segments.push(piece)
    }
  }
  segments.join("/")
}

///|
/// 取一个路径里目录的部分：`"OEBPS/content.opf"` → `"OEBPS"`。
pub fn dir_name(path : String) -> String {
  match path.rev_find("/") {
    None => ""
    Some(index) => path[0:index].to_owned()
  }
}
