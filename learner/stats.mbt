///|
/// 一段文本的可读性统计。
///
/// 覆盖率用千分数（0-1000）表示而不是小数：整条流水线因此不引入浮点
/// 误差，跨后端结果完全一致，测试也能写精确断言。
pub struct TextStats {
  tokens : Int
  known : Int
  unknown_tokens : Int
  unknown_types : Array[String]
} derive(Debug)

///|
pub extend TextStats with Debug::{to_repr}

///|
/// 统计参与阅读的词数，标点和空白不计。
fn is_counted(token : @segment.Token) -> Bool {
  match token.kind {
    Punct | Space => false
    _ => true
  }
}

///|
/// 统计一段切分结果对某个学习者的难度。
pub fn analyze(tokens : Array[@segment.Token], learner : Learner) -> TextStats {
  let seen : @hashmap.HashMap[String, Bool] = @hashmap.HashMap([])
  let unknown_types : Array[String] = []
  let mut total = 0
  let mut known = 0
  let mut unknown_tokens = 0
  for token in tokens {
    if is_counted(token) {
      total = total + 1
      if learner.knows_token(token) {
        known = known + 1
      } else {
        unknown_tokens = unknown_tokens + 1
        if !seen.contains(token.text) {
          seen.set(token.text, true)
          unknown_types.push(token.text)
        }
      }
    }
  }
  { tokens: total, known, unknown_tokens, unknown_types, }
}

///|
/// 参与统计的词数。
pub fn TextStats::tokens(self : TextStats) -> Int {
  self.tokens
}

///|
/// 认识的词数。
pub fn TextStats::known(self : TextStats) -> Int {
  self.known
}

///|
/// 生词出现次数（同一个词出现多次算多次）。
pub fn TextStats::unknown_tokens(self : TextStats) -> Int {
  self.unknown_tokens
}

///|
/// 去重后的生词表，按首次出现顺序排列。
pub fn TextStats::unknown_types(self : TextStats) -> Array[String] {
  self.unknown_types
}

///|
/// 生词种类数。
pub fn TextStats::unknown_types_count(self : TextStats) -> Int {
  self.unknown_types.length()
}

///|
/// 已知词覆盖率，千分数。文本里没有可统计的词时返回 1000。
pub fn TextStats::coverage_permille(self : TextStats) -> Int {
  if self.tokens == 0 {
    1000
  } else {
    self.known * 1000 / self.tokens
  }
}

///|
/// 覆盖率的百分比文本，例如 `"937"` 表示 93.7%。用于报告输出。
pub fn TextStats::coverage_percent_text(self : TextStats) -> String {
  let permille = self.coverage_permille()
  "\{permille / 10}.\{permille % 10}"
}

///|
/// 泛读的舒适度分档。
pub(all) enum Readability {
  TooHard // 覆盖不足九成
  Stretch // 九成到九成八，需要一点支撑
  Comfortable // 九成八以上，可以顺畅读下去
} derive(Debug, Eq)

///|
pub extend Readability with Debug::{to_repr}

///|
pub extend Readability with Eq::{not_equal, equal}

///|
/// 按已知词覆盖率分档。
///
/// 阈值取自泛读研究的经验区间：熟悉度低于 90% 基本读不动，
/// 95%-98% 以上才谈得上顺畅。这里取 900 / 980 两个整数边界。
pub fn readability(stats : TextStats) -> Readability {
  let coverage = stats.coverage_permille()
  if coverage >= 980 {
    Comfortable
  } else if coverage >= 900 {
    Stretch
  } else {
    TooHard
  }
}
