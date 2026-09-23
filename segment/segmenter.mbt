///|
/// 词表驱动的中文切分。
///
/// 汉字连续段走「双向最大匹配」：正向和反向各切一遍，取词数更少的结果；
/// 词数相同时取单字更少的结果；仍然相同则取反向结果。拉丁字母、数字、
/// 标点、空白各自成 token。
pub fn segment(text : String, lex : @lexicon.Lexicon) -> Array[Token] {
  let chars = text.to_array()
  let n = chars.length()
  let offsets = compute_offsets(chars)
  let max_word_length = if lex.max_word_length() > 0 {
    lex.max_word_length()
  } else {
    1
  }
  let out : Array[Token] = []
  let mut i = 0
  while i < n {
    let c = chars[i]
    if is_han(c) {
      let mut stop = i
      while stop < n && is_han(chars[stop]) {
        stop = stop + 1
      }
      for span in cut_han_run(chars, i, stop, lex, max_word_length) {
        let word = slice_string(chars, span.0, span.1)
        out.push({
          text: word,
          kind: Han,
          begin: offsets[span.0],
          end: offsets[span.1],
          level: lex.level_of(word),
        })
      }
      i = stop
    } else if is_latin(c) {
      let mut stop = i
      while stop < n && is_latin(chars[stop]) {
        stop = stop + 1
      }
      out.push({
        text: slice_string(chars, i, stop),
        kind: Latin,
        begin: offsets[i],
        end: offsets[stop],
        level: 0,
      })
      i = stop
    } else if is_digit(c) {
      let mut stop = i
      while stop < n &&
            (
              is_digit(chars[stop]) ||
              (
                code_point(chars[stop]) == 0x2E &&
                stop + 1 < n &&
                is_digit(chars[stop + 1])
              )
            ) {
        stop = stop + 1
      }
      out.push({
        text: slice_string(chars, i, stop),
        kind: Number,
        begin: offsets[i],
        end: offsets[stop],
        level: 0,
      })
      i = stop
    } else if is_space(c) {
      let mut stop = i
      while stop < n && is_space(chars[stop]) {
        stop = stop + 1
      }
      out.push({
        text: slice_string(chars, i, stop),
        kind: Space,
        begin: offsets[i],
        end: offsets[stop],
        level: 0,
      })
      i = stop
    } else {
      out.push({
        text: slice_string(chars, i, i + 1),
        kind: Punct,
        begin: offsets[i],
        end: offsets[i + 1],
        level: 0,
      })
      i = i + 1
    }
  }
  out
}

///|
/// 每个字符对应的 UTF-16 起始偏移，外加末尾的总长度。
fn compute_offsets(chars : Array[Char]) -> Array[Int] {
  let out : Array[Int] = []
  let mut acc = 0
  for c in chars {
    out.push(acc)
    acc = acc + c.utf16_len()
  }
  out.push(acc)
  out
}

///|
/// 把 `[start, stop)` 范围内的字合成字符串。
fn slice_string(chars : Array[Char], start : Int, stop : Int) -> String {
  let buf : Array[Char] = []
  let mut i = start
  while i < stop {
    buf.push(chars[i])
    i = i + 1
  }
  chars_to_string(buf)
}

///|
/// 把一串字合成字符串。
///
/// 目前用朴素拼接。句子长度有限，先保证正确；等接上整本书的流水线时
/// 再换成可复用的缓冲，避免长文本上的重复拷贝。
pub fn chars_to_string(chars : Array[Char]) -> String {
  let mut buf = ""
  for c in chars {
    buf = buf + c.to_string()
  }
  buf
}

///|
/// 一个汉字段该怎么切。
fn cut_han_run(
  chars : Array[Char],
  start : Int,
  stop : Int,
  lex : @lexicon.Lexicon,
  max_word_length : Int,
) -> Array[(Int, Int)] {
  if stop - start <= 1 {
    return [(start, stop)]
  }
  let forward = forward_max_match(chars, start, stop, lex, max_word_length)
  let backward = backward_max_match(chars, start, stop, lex, max_word_length)
  let forward_len = forward.length()
  let backward_len = backward.length()
  if forward_len < backward_len {
    forward
  } else if backward_len < forward_len {
    backward
  } else if count_single(forward) <= count_single(backward) {
    forward
  } else {
    backward
  }
}

///|
/// 正向最大匹配：从左往右，每次尽量取最长的词。
fn forward_max_match(
  chars : Array[Char],
  start : Int,
  stop : Int,
  lex : @lexicon.Lexicon,
  max_word_length : Int,
) -> Array[(Int, Int)] {
  let out : Array[(Int, Int)] = []
  let mut i = start
  while i < stop {
    let remaining = stop - i
    let cap = if remaining < max_word_length {
      remaining
    } else {
      max_word_length
    }
    let mut chosen = 1
    let mut len = cap
    while len >= 2 {
      if lex.contains(slice_string(chars, i, i + len)) {
        chosen = len
        len = 0
      } else {
        len = len - 1
      }
    }
    out.push((i, i + chosen))
    i = i + chosen
  }
  out
}

///|
/// 反向最大匹配：从右往左，每次尽量取最长的词，最后再翻回原来的顺序。
fn backward_max_match(
  chars : Array[Char],
  start : Int,
  stop : Int,
  lex : @lexicon.Lexicon,
  max_word_length : Int,
) -> Array[(Int, Int)] {
  let reversed : Array[(Int, Int)] = []
  let mut i = stop
  while i > start {
    let remaining = i - start
    let cap = if remaining < max_word_length {
      remaining
    } else {
      max_word_length
    }
    let mut chosen = 1
    let mut len = cap
    while len >= 2 {
      if lex.contains(slice_string(chars, i - len, i)) {
        chosen = len
        len = 0
      } else {
        len = len - 1
      }
    }
    reversed.push((i - chosen, i))
    i = i - chosen
  }
  let out : Array[(Int, Int)] = []
  let mut k = reversed.length()
  while k > 0 {
    k = k - 1
    out.push(reversed[k])
  }
  out
}

///|
/// 数一数这一段里有多少个单字词。
fn count_single(spans : Array[(Int, Int)]) -> Int {
  let mut count = 0
  for span in spans {
    if span.1 - span.0 == 1 {
      count = count + 1
    }
  }
  count
}
