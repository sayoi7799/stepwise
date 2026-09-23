///|
/// 切分单元的类型。
///
/// 用 `pub(all)`：外部与黑盒测试都可以构造和匹配这些构造子。
pub(all) enum TokenKind {
  Han // 汉字词
  Latin // 拉丁字母连续段（英文单词、缩写、拼音）
  Number // 数字（含小数）
  Punct // 标点与符号
  Space // 空白
} derive(Debug, Eq)

///|
pub extend TokenKind with Debug::{to_repr}

///|
pub extend TokenKind with Eq::{not_equal, equal}

///|
/// 一个切分单元。
///
/// `begin` / `end` 是这个词在原串中的 UTF-16 码元偏移（半开区间），
/// 阅读器要高亮某个词时直接用它定位。`level` 是 HSK 等级，
/// 0 表示词表里没有收录——对学习者来说就是生词。
pub struct Token {
  text : String
  kind : TokenKind
  begin : Int
  end : Int
  level : Int
} derive(Debug, Eq)

///|
pub extend Token with Debug::{to_repr}

///|
pub extend Token with Eq::{not_equal, equal}

///|
/// 字符的码点值。中文判断都走码点区间，避免依赖 Unicode 属性表。
pub fn code_point(c : Char) -> Int {
  c.to_int()
}

///|
/// 是否汉字。覆盖基本区、扩展 A 区与兼容区，够用来读现代中文。
pub fn is_han(c : Char) -> Bool {
  let code = code_point(c)
  (code >= 0x4E00 && code <= 0x9FFF) ||
  (code >= 0x3400 && code <= 0x4DBF) ||
  (code >= 0xF900 && code <= 0xFAFF)
}

///|
/// 是否拉丁字母（含带音调的字母，便于处理拼音）。
pub fn is_latin(c : Char) -> Bool {
  let code = code_point(c)
  (code >= 0x41 && code <= 0x5A) ||
  (code >= 0x61 && code <= 0x7A) ||
  (code >= 0x00C0 && code <= 0x024F && code != 0x00D7 && code != 0x00F7)
}

///|
/// 是否十进制数字。
pub fn is_digit(c : Char) -> Bool {
  let code = code_point(c)
  code >= 0x30 && code <= 0x39
}

///|
/// 是否空白（半角空格、制表符、换行、全角空格）。
pub fn is_space(c : Char) -> Bool {
  let code = code_point(c)
  code == 0x20 || code == 0x09 || code == 0x0A || code == 0x0D || code == 0x3000
}

///|
/// 是否句末标点。
///
/// 句号、叹号、问号、省略号，中英文写法都算。半角 `.` 不算：
/// 它在中文文本里更常出现在数字和小数点中，误判的代价比漏判高。
pub fn is_sentence_end(c : Char) -> Bool {
  let code = code_point(c)
  code == 0x3002 || // 。
  code == 0xFF01 || // ！
  code == 0xFF1F || // ？
  code == 0x2026 || // …
  code == 0x0021 || // !
  code == 0x003F // ?
}

///|
/// 是否「收尾符号」：跟在句末标点后面，仍然属于上一句。
pub fn is_closing_mark(c : Char) -> Bool {
  let code = code_point(c)
  code == 0x201D || // ”
  code == 0x2019 || // ’
  code == 0x300D || // 」
  code == 0x300F || // 』
  code == 0xFF09 || // ）
  code == 0x0029 || // )
  code == 0x300B || // 》
  code == 0x0022 // "
}
