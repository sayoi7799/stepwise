///|
/// 复习时的自评结果。
pub(all) enum Grade {
  Again // 完全想不起来
  Hard // 想起来了，但很吃力
  Good // 正常想起来
  Easy // 毫不费力
} derive(Debug, Eq)

///|
pub extend Grade with Debug::{to_repr}

///|
pub extend Grade with Eq::{not_equal, equal}

///|
/// 一张复习卡。
///
/// 难度系数存成千分数（2500 表示 2.5）。SM-2 原本用小数，
/// 这里改成整数是为了让同一份复习计划在任何后端、任何机器上
/// 得到完全一致的结果，也让测试可以写精确断言。
pub struct Card {
  word : String
  pinyin : String
  level : Int
  context : String
  ease_permille : Int
  interval_days : Int
  reps : Int
  due_day : Int
} derive(Debug)

///|
pub extend Card with Debug::{to_repr}

///|
/// 默认难度系数 2.5。
pub const DEFAULT_EASE_PERMILLE : Int = 2500

///|
/// 难度系数下限 1.3，低于它间隔会停止增长。
pub const MIN_EASE_PERMILLE : Int = 1300

///|
/// 新建一张卡：还没复习过，第 0 天到期。
pub fn Card::new(
  word : String,
  pinyin : String,
  level : Int,
  context : String,
) -> Card {
  {
    word,
    pinyin,
    level,
    context,
    ease_permille: DEFAULT_EASE_PERMILLE,
    interval_days: 0,
    reps: 0,
    due_day: 0,
  }
}

///|
/// 自评结果对应的质量分，沿用 SM-2 的 0-5 档。
pub fn quality(grade : Grade) -> Int {
  match grade {
    Again => 1
    Hard => 3
    Good => 4
    Easy => 5
  }
}

///|
/// 难度系数的增量，单位千分数。
///
/// 直接来自 SM-2 的公式 EF' = EF + (0.1 - (5-q)(0.08 + (5-q)0.02))，
/// 只是把小数全部放大一千倍写成整数。
pub fn ease_delta_permille(quality : Int) -> Int {
  let gap = 5 - quality
  100 - gap * (80 + gap * 20)
}

///|
/// 复习一次，返回更新后的卡片。
///
/// `today` 由调用方传入，函数内部不读时钟——这样整条调度逻辑
/// 完全可复现，测试里可以随意快进到任意一天。
pub fn review(card : Card, grade : Grade, today : Int) -> Card {
  let q = quality(grade)
  let raw_ease = card.ease_permille + ease_delta_permille(q)
  let ease = if raw_ease < MIN_EASE_PERMILLE {
    MIN_EASE_PERMILLE
  } else {
    raw_ease
  }
  if q < 3 {
    // 没想起来：连续正确次数清零，明天再来。
    {
      ..card,
      ease_permille: ease,
      interval_days: 1,
      reps: 0,
      due_day: today + 1,
    }
  } else {
    let reps = card.reps + 1
    let interval = if reps == 1 {
      1
    } else if reps == 2 {
      6
    } else {
      round_permille(card.interval_days * ease)
    }
    {
      ..card,
      ease_permille: ease,
      interval_days: interval,
      reps,
      due_day: today + interval,
    }
  }
}

///|
/// 千分数乘法后四舍五入回整数。
fn round_permille(value_permille : Int) -> Int {
  (value_permille + 500) / 1000
}

///|
/// 难度系数的可读文本，例如 `"2.50"`。
pub fn Card::ease_text(self : Card) -> String {
  let whole = self.ease_permille / 1000
  let frac = self.ease_permille % 1000
  "\{whole}.\{frac / 100}\{frac % 100 / 10}"
}

///|
/// 这批卡里今天该复习的，按到期日从早到晚（同样日子保持原顺序）。
pub fn due_cards(cards : Array[Card], today : Int) -> Array[Card] {
  let out : Array[Card] = []
  for card in cards {
    if card.due_day <= today {
      out.push(card)
    }
  }
  stable_sort_by_due(out)
  out
}

///|
/// 按到期日升序做稳定排序（插入排序）。
fn stable_sort_by_due(cards : Array[Card]) -> Unit {
  let mut i = 1
  while i < cards.length() {
    let current = cards[i]
    let mut j = i
    while j > 0 && cards[j - 1].due_day > current.due_day {
      cards[j] = cards[j - 1]
      j = j - 1
    }
    cards[j] = current
    i = i + 1
  }
}
