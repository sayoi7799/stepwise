///|
/// 把一段文本切成句子。
///
/// 规则：遇到句末标点断句，并把紧跟的收尾符号（引号、括号）并入上一句；
/// 换行也断句，但换行本身不进句子。全是空白的片段会被丢掉。
pub fn split_sentences(text : String) -> Array[String] {
  let chars = text.to_array()
  let out : Array[String] = []
  let mut buf : Array[Char] = []
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if is_sentence_end(c) {
      buf.push(c)
      i = i + 1
      // 连着来的句末标点（如「……」「！？」）和收尾引号都算同一句。
      while i < chars.length() &&
            (is_sentence_end(chars[i]) || is_closing_mark(chars[i])) {
        buf.push(chars[i])
        i = i + 1
      }
      flush_sentence(out, buf)
      buf = []
    } else if code_point(c) == 0x0A || code_point(c) == 0x0D {
      flush_sentence(out, buf)
      buf = []
      i = i + 1
    } else {
      buf.push(c)
      i = i + 1
    }
  }
  flush_sentence(out, buf)
  out
}

///|
/// 把缓冲区里的字合成一句推入结果；只有空白就不推。
fn flush_sentence(out : Array[String], buf : Array[Char]) -> Unit {
  let s = chars_to_string(buf).trim().to_owned()
  if s != "" {
    out.push(s)
  }
}
