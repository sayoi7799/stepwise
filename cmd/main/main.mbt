///|
/// 命令行入口。
///
/// 目前所有命令都在本地完成：读文件、分词、算难度、出报告。
/// 需要模型的那一步（`prompt`）只把提示词原样打印出来，方便
/// 先用假客户端把质量闸门跑通，再决定接哪家模型。
fn main {
  let args = @env.args()
  let command = if args.length() >= 2 { args[1] } else { "" }
  match command {
    "analyze" => run_analyze(args)
    "vocab" => run_vocab(args)
    "anki" => run_anki(args)
    "prompt" => run_prompt(args)
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
  println("")
  println(
    "默认学习者等级为 2，默认词表为 data/hsk30.tsv（HSK 3.0，10978 词）。",
  )
}

///|
fn run_analyze(args : Array[String]) -> Unit {
  match positional(args, 2) {
    Some(path) =>
      match load(path, args) {
        Some(loaded) =>
          println(
            @export.markdown_report(
              path,
              loaded.1,
              loaded.0,
              learner_from(args),
            ),
          )
        None => println("读不到文件：\{path}")
      }
    None => print_usage()
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
  let text = read_text(path)
  match text {
    None => None
    Some(content) => {
      let lexicon_path = string_flag(args, "--lexicon", "data/hsk30.tsv")
      let lexicon = match read_text(lexicon_path) {
        Some(raw) => @lexicon.Lexicon::from_tsv(raw)
        None => @lexicon.Lexicon::empty()
      }
      Some((lexicon, content))
    }
  }
}

///|
/// 读文件，失败返回 None（命令行的错误提示自己负责，不抛异常）。
fn read_text(path : String) -> String? {
  let result : String? = Some(@fs.read_file_to_string(path)) catch { _ => None }
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
