///|
/// 把一串字合成字符串。接受视图，方便直接传切片。
fn chars_to_string(chars : ArrayView[Char]) -> String {
  let mut buf = ""
  for c in chars {
    buf = buf + c.to_string()
  }
  buf
}

///|
/// 标签名边界：空白、`/`、`>` 都算，用来避免 `<item` 匹配到 `<itemref`。
fn is_tag_boundary(c : Char) -> Bool {
  let code = c.to_int()
  code == 0x20 ||
  code == 0x09 ||
  code == 0x0A ||
  code == 0x0D ||
  code == 0x2F ||
  code == 0x3E
}

///|
/// 取第 index 个字符；越界返回 `None`。
///
/// 直接对字符串下标拿到的是 UTF-16 码元（UInt16），
/// 要按字符用就得走 `get_char`。
fn char_at(text : String, index : Int) -> Char? {
  text.get_char(index)
}

///|
/// 从 index 开始是不是一个标签名边界（越界也算，相当于标签结束）。
fn boundary_at(text : String, index : Int) -> Bool {
  match char_at(text, index) {
    None => true
    Some(c) => is_tag_boundary(c)
  }
}

///|
/// 在一个起始标签里取属性值：`attribute("<item href=\"a.xhtml\"/>", "href")`
/// 得到 `"a.xhtml"`。单双引号都认，没有这个属性就返回 `None`。
pub fn attribute(tag : String, name : String) -> String? {
  let needle = name + "="
  match tag.find(needle) {
    None => None
    Some(index) => {
      let start = index + needle.length()
      if start >= tag.length() {
        return None
      }
      let quote = tag[start:start + 1].to_owned()
      if quote != "\"" && quote != "'" {
        return None
      }
      let rest = tag[start + 1:].to_owned()
      match rest.find(quote) {
        None => None
        Some(end) => Some(rest[0:end].to_owned())
      }
    }
  }
}

///|
/// 找出所有指定名字的标签（连同尖括号），按出现顺序返回。
///
/// 只看名字边界，所以 `tags(xml, "item")` 不会把 `<itemref>` 也算进来。
pub fn tags(xml : String, name : String) -> Array[String] {
  let out : Array[String] = []
  let open = "<" + name
  let mut offset = 0
  while offset < xml.length() {
    let rest = xml[offset:].to_owned()
    match rest.find(open) {
      None => break
      Some(index) => {
        let start = offset + index
        let name_end = start + open.length()
        if !boundary_at(xml, name_end) {
          offset = name_end
          continue
        }
        let tail = xml[start:].to_owned()
        match tail.find(">") {
          None => break
          Some(gt) => {
            out.push(tail[0:gt + 1].to_owned())
            offset = start + gt + 1
          }
        }
      }
    }
  }
  out
}

///|
/// 取 `<name ...>正文</name>` 里的正文（保留实体原文）。
pub fn element_text(xml : String, name : String) -> String? {
  let open = "<" + name
  match xml.find(open) {
    None => None
    Some(index) => {
      let tail = xml[index:].to_owned()
      match tail.find(">") {
        None => None
        Some(gt) => {
          let body_start = index + gt + 1
          let rest = xml[body_start:].to_owned()
          match rest.find("</" + name + ">") {
            None => None
            Some(end) => Some(rest[0:end].to_owned())
          }
        }
      }
    }
  }
}

///|
/// 删掉某个元素连同它的内容，用来处理 script / style / head 这类不该进正文的部分。
pub fn remove_element(xml : String, name : String) -> String {
  let mut out = xml
  let open = "<" + name
  let close = "</" + name + ">"
  let mut steps = 0
  while steps < 1000 {
    steps = steps + 1
    match out.find(open) {
      None => break
      Some(index) => {
        let name_end = index + open.length()
        if !boundary_at(out, name_end) {
          // 名字前缀相同但不是同一个标签，从这个名字之后继续找。
          let tail = out[name_end:].to_owned()
          match tail.find(open) {
            None => break
            Some(next) =>
              out = out[0:name_end].to_owned() + tail[next:].to_owned()
          }
        } else {
          let tail = out[index:].to_owned()
          match tail.find(">") {
            None => break
            Some(gt) => {
              let after_open = index + gt + 1
              let rest = out[after_open:].to_owned()
              match rest.find(close) {
                None => {
                  // 没有结束标签：保留开标签之前的内容，后面整段丢掉。
                  out = out[0:index].to_owned()
                  break
                }
                Some(end) => {
                  let after_close = after_open + end + close.length()
                  out = out[0:index].to_owned() + out[after_close:].to_owned()
                }
              }
            }
          }
        }
      }
    }
  }
  out
}

///|
/// 常见命名实体。中文排版里 `&ldquo;` `&rdquo;` 出现得很频繁，必须认。
fn named_entities() -> Array[(String, String)] {
  [
    ("&amp;", "&"),
    ("&lt;", "<"),
    ("&gt;", ">"),
    ("&quot;", "\""),
    ("&apos;", "'"),
    ("&nbsp;", " "),
    ("&ldquo;", "“"),
    ("&rdquo;", "”"),
    ("&lsquo;", "‘"),
    ("&rsquo;", "’"),
    ("&hellip;", "…"),
    ("&mdash;", "—"),
    ("&ndash;", "–"),
    ("&middot;", "·"),
  ]
}

///|
/// 解码实体：命名实体查表，`&#123;` 与 `&#x1F600;` 按码点还原。
///
/// 认不出来的一律原样保留——读电子书时宁可看到 `&foo;`，
/// 也不该把它悄悄吃掉。
pub fn decode_entities(text : String) -> String {
  let chars = text.to_array()
  let table = named_entities()
  let mut out = ""
  let mut i = 0
  while i < chars.length() {
    if chars[i] == '&' {
      let mut j = i + 1
      while j < chars.length() && chars[j] != ';' && j - i <= 12 {
        j = j + 1
      }
      if j < chars.length() && chars[j] == ';' {
        let body = chars_to_string(chars[i:j + 1])
        let inner = chars_to_string(chars[i + 1:j])
        if inner.has_prefix("#") {
          match parse_code_point(inner) {
            Some(code) =>
              match Int::to_char(code) {
                Some(c) => {
                  out = out + c.to_string()
                  i = j + 1
                  continue
                }
                None => ()
              }
            None => ()
          }
        } else {
          let mut matched = false
          for pair in table {
            if body == pair.0 {
              out = out + pair.1
              matched = true
            }
          }
          if matched {
            i = j + 1
            continue
          }
        }
      }
    }
    out = out + chars[i].to_string()
    i = i + 1
  }
  out
}

///|
/// 解析 `#123` 或 `#x1F600` 形式的码点。
fn parse_code_point(inner : String) -> Int? {
  let digits = inner[1:].to_owned()
  if digits == "" {
    return None
  }
  let hex = digits.has_prefix("x") || digits.has_prefix("X")
  let body = if hex { digits[1:].to_owned() } else { digits }
  if body == "" {
    return None
  }
  let radix = if hex { 16 } else { 10 }
  let mut value = 0
  for c in body.to_array() {
    let code = c.to_int()
    let digit = if code >= 0x30 && code <= 0x39 {
      code - 0x30
    } else if code >= 0x41 && code <= 0x46 {
      code - 0x41 + 10
    } else if code >= 0x61 && code <= 0x66 {
      code - 0x61 + 10
    } else {
      return None
    }
    if digit >= radix {
      return None
    }
    value = value * radix + digit
  }
  if value > 0x10FFFF {
    None
  } else {
    Some(value)
  }
}

///|
/// 块级标签：这些标签结束时补一个换行，段落结构才不会糊成一团。
fn is_block_tag(tag_body : String) -> Bool {
  let trimmed = tag_body.trim().to_owned()
  let name = if trimmed.has_prefix("/") {
    trimmed[1:].to_owned()
  } else {
    trimmed
  }
  let mut end = name.length()
  let mut i = 0
  while i < name.length() {
    let c = name[i:i + 1].to_owned()
    if c == " " || c == "\t" || c == "\n" || c == "\r" || c == "/" {
      end = i
      break
    }
    i = i + 1
  }
  let bare = name[0:end].to_owned().to_lower()
  bare == "p" ||
  bare == "div" ||
  bare == "br" ||
  bare == "li" ||
  bare == "tr" ||
  bare == "hr" ||
  bare == "h1" ||
  bare == "h2" ||
  bare == "h3" ||
  bare == "h4" ||
  bare == "h5" ||
  bare == "h6" ||
  bare == "blockquote" ||
  bare == "section" ||
  bare == "article" ||
  bare == "figure" ||
  bare == "figcaption"
}

///|
/// 把 XHTML 正文提成纯文本。
///
/// 处理顺序：扔掉 script / style / head，按块级标签断行，剥掉其余标签，
/// 解码实体，最后按行压缩空白。结果是「一段一行」，正好适合按句切分。
pub fn xhtml_to_text(xhtml : String) -> String {
  let cleaned = remove_element(
    remove_element(remove_element(xhtml, "script"), "style"),
    "head",
  )
  let chars = cleaned.to_array()
  let mut out = ""
  let mut tag_buf : Array[Char] = []
  let mut in_tag = false
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if in_tag {
      if c == '>' {
        in_tag = false
        if is_block_tag(chars_to_string(tag_buf[:])) {
          out = out + "\n"
        }
        tag_buf = []
      } else {
        tag_buf.push(c)
      }
    } else if c == '<' {
      in_tag = true
      tag_buf = []
    } else {
      out = out + c.to_string()
    }
    i = i + 1
  }
  normalize_lines(decode_entities(out))
}

///|
/// 每行去掉首尾空白、丢掉空行，再用换行接起来。
pub fn normalize_lines(text : String) -> String {
  let lines = text.split("\n").to_array()
  let kept : Array[String] = []
  for line in lines {
    let trimmed = line.trim().to_owned()
    if trimmed != "" {
      kept.push(trimmed)
    }
  }
  kept.join("\n")
}
