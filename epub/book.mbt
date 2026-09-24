///|
/// 打开 EPUB 时可能遇到的问题。
pub(all) suberror EpubError {
  NotAnArchive(String)
  MissingRootfile(String)
  MissingEntry(String)
  BrokenArchive(String)
}

///|
/// 给人看的错误描述。
pub fn EpubError::to_string(self : EpubError) -> String {
  match self {
    NotAnArchive(why) => "不是有效的 EPUB：\{why}"
    MissingRootfile(why) => "找不到 OPF：\{why}"
    MissingEntry(path) => "压缩包里没有这个条目：\{path}"
    BrokenArchive(why) => "压缩包损坏：\{why}"
  }
}

///|
/// 一章：标题加正文。
pub struct Chapter {
  title : String
  text : String
} derive(Debug)

///|
pub extend Chapter with Debug::{to_repr}

///|
/// 一本打开的 EPUB。
pub struct Book {
  title : String
  chapters : Array[Chapter]
} derive(Debug)

///|
pub extend Book with Debug::{to_repr}

///|
/// 书名。
pub fn Book::title(self : Book) -> String {
  self.title
}

///|
/// 全部章节，顺序就是书的阅读顺序。
pub fn Book::chapters(self : Book) -> Array[Chapter] {
  self.chapters
}

///|
/// 章节数。
pub fn Book::chapter_count(self : Book) -> Int {
  self.chapters.length()
}

///|
/// 把整本书拼成一段纯文本，章节之间用换行分隔。
pub fn Book::plain_text(self : Book) -> String {
  let parts : Array[String] = []
  for chapter in self.chapters {
    parts.push(chapter.text)
  }
  parts.join("\n")
}

///|
/// 打开一本 EPUB。
///
/// 走标准三步：先读 `META-INF/container.xml` 找到 OPF，
/// 再从 OPF 里读清单与阅读顺序，最后按顺序把每章正文提成纯文本。
pub fn open(bytes : Bytes) -> Book raise EpubError {
  let archive = @zipc.Archive::from_bytes(bytes) catch {
    _ => raise NotAnArchive("这不是一个有效的 ZIP 压缩包")
  }
  let container = match read_entry(archive, "META-INF/container.xml") {
    Some(text) => text
    None => raise NotAnArchive("压缩包里没有 META-INF/container.xml")
  }
  let opf_path = match rootfile_path(container) {
    Some(path) => path
    None => raise MissingRootfile("container.xml 里没有 rootfile")
  }
  let opf = match read_entry(archive, opf_path) {
    Some(text) => text
    None => raise MissingEntry(opf_path)
  }
  let base_dir = dir_name(opf_path)
  let title = match element_text(opf, "dc:title") {
    Some(raw) => decode_entities(raw).trim().to_owned()
    None => ""
  }
  { title, chapters: build_chapters(archive, opf, base_dir), }
}

///|
/// 从 container.xml 里取 OPF 的路径。
pub fn rootfile_path(container_xml : String) -> String? {
  for tag in tags(container_xml, "rootfile") {
    match attribute(tag, "full-path") {
      Some(path) => if path != "" { return Some(path) }
      None => ()
    }
  }
  None
}

///|
/// 读一个条目并解成 UTF-8 文本。条目不存在或解不开返回 `None`。
fn read_entry(archive : @zipc.Archive, path : String) -> String? {
  match archive.find(path) {
    None => None
    Some(entry) =>
      match entry.kind() {
        Dir => None
        File(file) => {
          let bytes : Bytes = file.to_bytes() catch { _ => return None }
          Some(@utf8.decode_lossy(bytes))
        }
      }
  }
}

///|
/// 按 spine 的顺序把正文提出来。
///
/// manifest 提供 id → href，spine 提供阅读顺序；两者缺一不可。
fn build_chapters(
  archive : @zipc.Archive,
  opf : String,
  base_dir : String,
) -> Array[Chapter] {
  let href_by_id : @hashmap.HashMap[String, String] = @hashmap.HashMap([])
  for tag in tags(opf, "item") {
    match (attribute(tag, "id"), attribute(tag, "href")) {
      (Some(id), Some(href)) => href_by_id.set(id, href)
      _ => ()
    }
  }
  let chapters : Array[Chapter] = []
  let mut index = 0
  for tag in tags(opf, "itemref") {
    let href = match attribute(tag, "idref") {
      None => None
      Some(id) => href_by_id.get(id)
    }
    match href {
      None => ()
      Some(relative) => {
        let path = resolve_path(base_dir, relative)
        match read_entry(archive, path) {
          None => ()
          Some(raw) => {
            index = index + 1
            chapters.push({
              title: chapter_title(raw, index),
              text: xhtml_to_text(raw),
            })
          }
        }
      }
    }
  }
  chapters
}

///|
/// 章节标题：优先用 `<title>`，其次用第一行正文（通常是 h1），
/// 都没有就退回「第 N 章」。
fn chapter_title(xhtml : String, index : Int) -> String {
  match element_text(xhtml, "title") {
    Some(raw) => {
      let decoded = decode_entities(raw).trim().to_owned()
      if decoded != "" {
        return decoded
      }
    }
    None => ()
  }
  let lines = xhtml_to_text(xhtml).split("\n").to_array()
  if lines.length() > 0 {
    let first = lines[0].trim().to_owned()
    if first != "" && first.char_length() <= 30 {
      return first
    }
  }
  "第 \{index} 章"
}
