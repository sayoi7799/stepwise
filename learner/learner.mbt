///|
/// 学习者画像。
///
/// 掌握范围用一个等级上限加一张「额外认识」名单来表示：
/// 等级不超过 `level` 的词算已掌握，其余靠名单补充。真实产品里
/// 这份名单会由复习记录不断长出来，这里先做成可显式维护的结构。
pub struct Learner {
  level : Int
  extra_known : @hashmap.HashMap[String, Bool]
}

///|
/// 建一个非空画像：`level` 会被夹在 0 到 9 之间，负数按 0 处理。
pub fn Learner::new(level : Int) -> Learner {
  let clamped = if level < 0 { 0 } else if level > 9 { 9 } else { level }
  { level: clamped, extra_known: @hashmap.HashMap([]), }
}

///|
/// 当前等级上限。
pub fn Learner::level(self : Learner) -> Int {
  self.level
}

///|
/// 认识一个词（超出等级的专有名词、术语等）。
pub fn Learner::mark_known(self : Learner, word : String) -> Unit {
  self.extra_known.set(word, true)
}

///|
/// 认识的额外词数。
pub fn Learner::extra_known_count(self : Learner) -> Int {
  self.extra_known.length()
}

///|
/// 是否认识一个带等级的 token。
///
/// 没有等级（词表未收录）一律算生词——这正是要提醒学习者注意的地方。
pub fn Learner::knows_token(self : Learner, token : @segment.Token) -> Bool {
  if self.extra_known.contains(token.text) {
    true
  } else {
    token.level > 0 && token.level <= self.level
  }
}
