///|
/// 把生词表转成复习卡。
///
/// 卡片背面留的是首次出现的原句，而不是词典释义——把词放回语境，
/// 学习者记的是「这句话怎么用」，不是一个孤立的中英对照。
pub fn to_cards(entries : Array[VocabEntry]) -> Array[@srs.Card] {
  let out : Array[@srs.Card] = []
  for entry in entries {
    out.push(
      @srs.Card::new(
        entry.word,
        entry.pinyin,
        entry.level,
        entry.first_sentence,
      ),
    )
  }
  out
}
