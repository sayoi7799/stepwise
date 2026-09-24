///|
/// 命令行入口。
///
/// analyze / vocab / anki 全部在本地完成：读文件、分词、算难度、出报告。
/// `prompt` 只把要发出去的提示词打印出来，`explain` 才真的调模型，
/// 并且把模型的输出送回我们自己的分词器审计。
async fn main {
  let args = @env.args()
  let command = if args.length() >= 2 { args[1] } else { "" }
  match command {
    "analyze" => run_analyze(args)
    "vocab" => run_vocab(args)
    "anki" => run_anki(args)
    "prompt" => run_prompt(args)
    "explain" => run_explain(args)
    _ => print_usage()
  }
}

///|
fn print_usage() -> Unit {
  println("拾级 Stepwise —— 中文分级阅读流水线")
  println("")
  println("用法：")
  println("  stepwise analyze <文件> [--level N] [--lexicon 词表.tsv]")
  println("      给一篇文章做难度体检，输出 Markdown 报告")
  println("  stepwise vocab <文件> [--level N]")
  println("      只列生词表")
  println("  stepwise anki <文件> [--level N]")
  println("      导出 Anki 可直接导入的卡片文本")
  println("  stepwise prompt <词> <原句> [--level N] [--learner-level M]")
  println("      打印会发给模型的提示词（离线，不联网）")
  println("  stepwise explain <词> <原句> [--level N] [--learner-level M]")
  println(
    "      真的让模型解释这个词：输出会先过一遍可读性审计，",
  )
  println(
    "      不达标就带着更严的约束重试。需要 DEEPSEEK_API_KEY。",
  )
  println("")
  println(
    "默认学习者等级为 2，默认词表为 data/hsk30.tsv（HSK 3.0，10978 词）。",
  )
}

///|
/// 让模型真的解释一个词，并把审计结果一并打出来。
///
/// 读 `DEEPSEEK_API_KEY`。没配的时候给出设置方法，而不是直接崩掉——
/// 使用者多半是第一次跑，告诉他怎么配比抛一个栈有用。
async fn run_explain(args : Array[String]) -> Unit {
  let word = match positional(args, 2) {
    None => {
      print_usage()
      return
    }
    Some(value) => value
  }
  let sentence = match positional(args, 3) {
    None => {
      print_usage()
      return
    }
    Some(value) => value
  }
  let key = match api_key() {
    None => {
      println("没有找到 DEEPSEEK_API_KEY 环境变量。")
      println("在 PowerShell 里这样设置（只对当前窗口有效）：")
      println("  $env:DEEPSEEK_API_KEY = \"sk-...\"")
      println(
        "想先看看要发出去的提示词，可以用 stepwise prompt。",
      )
      return
    }
    Some(value) => value
  }
  let lexicon = load_lexicon(args)
  let learner = learner_from(args)
  let client = @ai.OpenAiCompatClient::new(key)
  println("模型：\{client.model()}")
  println("地址：\{client.endpoint()}")
  println("学习者水平：HSK \{learner.level()}\n")
  let answer = @ai.explain_with_audit(
    client,
    word,
    string_flag(args, "--pinyin", ""),
    int_flag(args, "--word-level", 0),
    sentence,
    lexicon,
    learner,
    int_flag(args, "--attempts", 3),
  ) catch {
    error => {
      println("调用失败：\{error.to_string()}")
      return
    }
  }
  println(answer)
  let stats = @ai.audit(answer, lexicon, learner)
  println("")
  println(
    "可读性审计：覆盖率 \{stats.coverage_percent_text()}%，生词 \{stats.unknown_types_count()} 个",
  )
  if @ai.acceptable_explanation(stats) {
    println("结论：这段解释对当前水平是够浅的。")
  } else {
    println(
      "结论：这段解释偏难，重试后仍不达标，建议换个说法或降低等级。",
    )
  }
}

///|
/// 从环境变量取 API key；没设置或者是空白都算没配。
fn api_key() -> String? {
  match @env.get_env_var("DEEPSEEK_API_KEY") {
    None => None
    Some(key) => {
      let trimmed = key.trim().to_owned()
      if trimmed == "" {
        None
      } else {
        Some(trimmed)
      }
    }
  }
}

///|
fn run_analyze(args : Array[String]) -> Unit {
  match positional(args, 2) {
    Some(path) => {
      let learner = learner_from(args)
      if path.has_suffix(".epub") {
        analyze_epub(path, args, learner)
      } else {
        match load(path, args) {
          Some(loaded) =>
            println(@export.markdown_report(path, loaded.1, loaded.0, learner))
          None => println("读不到文件：\{path}")
        }
      }
    }
    None => print_usage()
  }
}

///|
/// 读一整本 EPUB。
///
/// 带 `--chapter N` 时只体检第 N 章，不带就输出整本书的报告。
fn analyze_epub(
  path : String,
  args : Array[String],
  learner : @learner.Learner,
) -> Unit {
  let lexicon = load_lexicon(args)
  let bytes = match read_bytes(path) {
    Some(content) => content
    None => {
      println("读不到文件：\{path}")
      return
    }
  }
  let book = match open_book(bytes) {
    Some(book) => book
    None => {
      println("这本书打不开（需要是标准 EPUB）：\{path}")
      return
    }
  }
  let chapter_index = int_flag(args, "--chapter", 0)
  let chapters = book.chapters()
  if chapter_index > 0 {
    if chapter_index > chapters.length() {
      println("这本书只有 \{chapters.length()} 章。")
    } else {
      let chapter = chapters[chapter_index - 1]
      println(
        @export.markdown_report(chapter.title, chapter.text, lexicon, learner),
      )
    }
  } else {
    println(@export.markdown_book_report(book, lexicon, learner))
  }
}

///|
fn run_vocab(args : Array[String]) -> Unit {
  match positional(args, 2) {
    Some(path) =>
      match load(path, args) {
        Some(loaded) => {
          let vocab = @learner.collect_vocabulary(
            loaded.1,
            loaded.0,
            learner_from(args),
          )
          if vocab.length() == 0 {
            println("没有生词。")
          } else {
            for entry in vocab {
              println(
                "\{entry.word}\t\{entry.pinyin}\t\{@export.level_label(entry.level)}\t出现 \{entry.count} 次",
              )
            }
          }
        }
        None => println("读不到文件：\{path}")
      }
    None => print_usage()
  }
}

///|
fn run_anki(args : Array[String]) -> Unit {
  match positional(args, 2) {
    Some(path) =>
      match load(path, args) {
        Some(loaded) => {
          let vocab = @learner.collect_vocabulary(
            loaded.1,
            loaded.0,
            learner_from(args),
          )
          println(@export.vocab_to_anki_tsv(vocab))
        }
        None => println("读不到文件：\{path}")
      }
    None => print_usage()
  }
}

///|
fn run_prompt(args : Array[String]) -> Unit {
  match positional(args, 2) {
    Some(word) =>
      match positional(args, 3) {
        Some(sentence) => {
          let level = int_flag(args, "--word-level", 0)
          let request = @ai.explain_word_prompt(
            word,
            string_flag(args, "--pinyin", ""),
            level,
            sentence,
            int_flag(args, "--learner-level", 2),
            false,
          )
          println("--- system ---")
          println(request.system)
          println("--- user ---")
          println(request.user)
        }
        None => print_usage()
      }
    None => print_usage()
  }
}

///|
/// 第 n 个位置参数（跳过程序名与子命令）。
fn positional(args : Array[String], index : Int) -> String? {
  if index < args.length() {
    Some(args[index])
  } else {
    None
  }
}

///|
/// 读取正文字和词表。
///
/// 词表路径可以用 `--lexicon` 指定；不给就用仓库里的示例词表。
fn load(path : String, args : Array[String]) -> (@lexicon.Lexicon, String)? {
  load_text(path, args)
}

///|
/// 读入待分析的正文。
///
/// `.epub` 先解出整本书的纯文本，其它扩展名按文本直接读。所有命令都走这里，
/// 就不会出现「analyze 认 epub、vocab 不认」这种前后不一致的事。
fn load_text(
  path : String,
  args : Array[String],
) -> (@lexicon.Lexicon, String)? {
  let lexicon = load_lexicon(args)
  if path.has_suffix(".epub") {
    let bytes = match read_bytes(path) {
      None => return None
      Some(value) => value
    }
    let book = match open_book(bytes) {
      None => return None
      Some(value) => value
    }
    Some((lexicon, book.plain_text()))
  } else {
    match read_text(path) {
      None => None
      Some(content) => Some((lexicon, content))
    }
  }
}

///|
/// 读词表：`--lexicon` 指定路径，默认用仓库里随附的 HSK 3.0 词表。
fn load_lexicon(args : Array[String]) -> @lexicon.Lexicon {
  let path = string_flag(args, "--lexicon", "data/hsk30.tsv")
  match read_text(path) {
    Some(raw) => @lexicon.Lexicon::from_tsv(raw)
    None => @lexicon.Lexicon::empty()
  }
}

///|
/// 读文件，失败返回 None（命令行的错误提示自己负责，不抛异常）。
fn read_text(path : String) -> String? {
  let result : String? = Some(@fs.read_file_to_string(path)) catch { _ => None }
  result
}

///|
/// 读二进制文件，失败返回 None。
fn read_bytes(path : String) -> Bytes? {
  let result : Bytes? = Some(@fs.read_file_to_bytes(path)) catch { _ => None }
  result
}

///|
/// 打开一本 EPUB，失败返回 None。
fn open_book(bytes : Bytes) -> @epub.Book? {
  let result : @epub.Book? = Some(@epub.open(bytes)) catch { _ => None }
  result
}

///|
fn learner_from(args : Array[String]) -> @learner.Learner {
  @learner.Learner::new(int_flag(args, "--level", 2))
}

///|
/// 取 `--名字 值` 形式的字符串参数。
fn string_flag(
  args : Array[String],
  name : String,
  fallback : String,
) -> String {
  let mut i = 0
  while i + 1 < args.length() {
    if args[i] == name {
      return args[i + 1]
    }
    i = i + 1
  }
  fallback
}

///|
/// 取 `--名字 值` 形式的整数参数；解析不出来就用默认值。
fn int_flag(args : Array[String], name : String, fallback : Int) -> Int {
  parse_int(string_flag(args, name, ""), fallback)
}

///|
/// 只认十进制的非负整数。自己写一遍是为了不把格式错误变成崩溃。
pub fn parse_int(text : String, fallback : Int) -> Int {
  if text == "" {
    return fallback
  }
  let mut value = 0
  let mut valid = true
  for c in text.to_array() {
    let digit = c.to_int() - 0x30
    if digit >= 0 && digit <= 9 {
      value = value * 10 + digit
    } else {
      valid = false
    }
  }
  if valid {
    value
  } else {
    fallback
  }
}
