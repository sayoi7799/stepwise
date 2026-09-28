///|
/// HTML 转义。
///
/// 电子书正文里出现 `<`、`&` 是常有的事，不转义的话它们会直接变成标签，
/// 轻则排版乱掉，重则把后面的内容整段吃掉。`&` 必须最先替换，
/// 否则会把刚生成的 `&lt;` 再转一次。
pub fn escape_html(text : String) -> String {
  text
  .replace_all(old="&", new="&amp;")
  .replace_all(old="<", new="&lt;")
  .replace_all(old=">", new="&gt;")
  .replace_all(old="\"", new="&quot;")
  .replace_all(old="'", new="&#39;")
}

///|
/// 一个词的悬停提示：拼音加等级。
fn word_tip(token : @segment.Token) -> String {
  let level = if token.level == 0 { "未收录" } else { "HSK \{token.level}" }
  level
}

///|
/// 把一行文本渲染成 HTML：生词高亮并带上悬停提示，其余原样输出。
fn render_line(
  line : String,
  lex : @lexicon.Lexicon,
  learner : @learner.Learner,
) -> String {
  let mut out = ""
  for token in @segment.segment(line, lex) {
    let escaped = escape_html(token.text)
    match token.kind {
      Punct | Space => out = out + escaped
      _ =>
        if learner.knows_token(token) {
          out = out + "<span class=\"w\">" + escaped + "</span>"
        } else {
          out = out +
            "<span class=\"w new\" data-tip=\"" +
            escape_html(word_tip(token)) +
            "\">" +
            escaped +
            "</span>"
        }
    }
  }
  out
}

///|
/// 学习版网页的样式。全部内联，不依赖任何外部资源。
const PAGE_STYLE : String =
  #|<style>
  #|  :root {
  #|    --ink: #1c1c1e; --dim: #6b6b70; --line: #e6e6ea;
  #|    --bg: #fbfbf9; --card: #ffffff; --mark: #fff2c2; --accent: #b4531f;
  #|  }
  #|  * { box-sizing: border-box; }
  #|  body {
  #|    margin: 0; background: var(--bg); color: var(--ink);
  #|    font-family: -apple-system, "Segoe UI", "Microsoft YaHei", sans-serif;
  #|    line-height: 1.75;
  #|  }
  #|  .wrap { max-width: 980px; margin: 0 auto; padding: 32px 20px 80px; }
  #|  header { border-bottom: 2px solid var(--ink); padding-bottom: 16px; margin-bottom: 8px; }
  #|  h1 { font-size: 1.6rem; margin: 0 0 8px; }
  #|  h2 { font-size: 1.1rem; margin: 36px 0 12px; }
  #|  .meta { color: var(--dim); font-size: 0.92rem; margin: 4px 0; }
  #|  .verdict { margin: 10px 0 0; font-weight: 600; color: var(--accent); }
  #|  .legend { color: var(--dim); font-size: 0.85rem; margin-top: 10px; }
  #|  .legend b { background: var(--mark); padding: 1px 6px; border-radius: 3px; font-weight: 500; }
  #|  .chapter { background: var(--card); border: 1px solid var(--line); border-radius: 10px;
  #|             padding: 20px 24px; margin-top: 20px; }
  #|  .chapter h3 { margin: 0 0 4px; font-size: 1rem; color: var(--dim); font-weight: 600; }
  #|  p { font-family: Georgia, "Songti SC", "SimSun", serif; font-size: 1.12rem; margin: 14px 0; }
  #|  .w { position: relative; }
  #|  .new { background: var(--mark); border-radius: 3px; cursor: help; }
  #|  .new:hover::after {
  #|    content: attr(data-tip); position: absolute; left: 0; top: 1.7em;
  #|    background: #1c1c1e; color: #fff; font-family: sans-serif; font-size: 0.75rem;
  #|    padding: 3px 8px; border-radius: 4px; white-space: nowrap; z-index: 9;
  #|  }
  #|  table { border-collapse: collapse; width: 100%; font-size: 0.92rem; background: var(--card); }
  #|  th, td { border: 1px solid var(--line); padding: 7px 10px; text-align: left; vertical-align: top; }
  #|  th { background: #f4f4f1; font-weight: 600; }
  #|  ul.sentences { padding-left: 20px; }
  #|  ul.sentences li { font-family: Georgia, "Songti SC", serif; margin: 8px 0; }
  #|  .hint { color: var(--dim); font-size: 0.85rem; }
  #|  p.clickable { cursor: pointer; border-radius: 6px; }
  #|  p.clickable:hover { background: #fffdf3; box-shadow: 0 0 0 6px #fffdf3; }
  #|  .card { margin: 6px 0 18px; padding: 14px 18px; background: #fff;
  #|          border-left: 3px solid var(--accent); border-radius: 6px;
  #|          font-family: -apple-system, "Segoe UI", sans-serif; font-size: 1rem;
  #|          box-shadow: 0 1px 3px rgba(0,0,0,0.06); }
  #|  .card .zh { font-weight: 500; }
  #|  .card .en { color: var(--dim); margin-top: 6px; font-size: 0.95rem; }
  #|  .card .note { color: var(--dim); margin-top: 8px; font-size: 0.8rem; }
  #|  footer { color: var(--dim); font-size: 0.82rem; margin-top: 48px; border-top: 1px solid var(--line); padding-top: 14px; }
  #|</style>

///|
/// 生成一份自包含的学习版网页。
///
/// 这是产品对学习者的交付面：打开就能读，生词高亮，悬停看拼音与等级，
/// 生词表可以带模型的解释。不引任何外部资源，离线可用。
pub fn study_page(
  title : String,
  text : String,
  lex : @lexicon.Lexicon,
  learner : @learner.Learner,
  explanations : Array[(String, String)],
  interactive? : Bool = false,
) -> String {
  let stats = @learner.analyze(@segment.segment(text, lex), learner)
  let vocab = @learner.collect_vocabulary(text, lex, learner)
  let picked = @learner.pick_learning_sentences(text, lex, learner, 5)
  let heading = if title == "" { "（未命名）" } else { title }
  let mut out = "<!DOCTYPE html>\n<html lang=\"zh-CN\">\n<head>\n"
  out = out + "<meta charset=\"utf-8\">\n"
  out = out +
    "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
  out = out + "<title>拾级 · " + escape_html(heading) + "</title>\n"
  out = out + PAGE_STYLE + "\n</head>\n<body>\n<div class=\"wrap\">\n"
  // 页头：先把「读得动吗」摆出来，这是学习者最关心的一句话
  out = out + "<header>\n<h1>" + escape_html(heading) + "</h1>\n"
  out = out +
    "<p class=\"meta\">学习者水平：HSK " +
    learner.level().to_string() +
    "</p>\n"
  out = out + "<p class=\"meta\">词数 "
  out = out + stats.tokens().to_string()
  out = out + " · 已知词覆盖率 "
  out = out + stats.coverage_percent_text()
  out = out + "% · 生词 "
  out = out + stats.unknown_types_count().to_string()
  out = out + " 个（共出现 "
  out = out + stats.unknown_tokens().to_string()
  out = out + " 次）</p>\n"
  out = out +
    "<p class=\"verdict\">判定：" +
    readability_label(@learner.readability(stats)) +
    "</p>\n"
  out = out +
    "<p class=\"legend\">高亮的是超出你当前水平的词，鼠标停上去看拼音和等级。</p>\n"
  out = out + "</header>\n"
  // 正文：一段一行，生词逐个高亮
  out = out + "<h2>正文</h2>\n"
  let normalized = @epub.normalize_lines(text)
  let paragraphs = normalized.split("\n").to_array()
  if normalized == "" {
    out = out + "<p class=\"hint\">这一篇没有正文。</p>\n"
  } else {
    out = out + "<section class=\"text\">\n"
    for paragraph in paragraphs {
      let line = paragraph.to_owned()
      out = out + "<p>" + render_line(line, lex, learner) + "</p>\n"
    }
    out = out + "</section>\n"
  }
  // 生词表：有模型解释就用上，没有就只列词、拼音、等级
  out = out + "<h2>生词表</h2>\n"
  if vocab.length() == 0 {
    out = out +
      "<p class=\"hint\">这一篇没有生词，可以直接读。</p>\n"
  } else {
    let has_explanation = explanations.length() > 0
    out = out +
      "<table>\n<tr><th>词</th><th>拼音</th><th>等级</th><th>出现</th>"
    if has_explanation {
      out = out + "<th>解释</th>"
    }
    out = out + "</tr>\n"
    for entry in vocab {
      out = out +
        "<tr><td>" +
        escape_html(entry.word) +
        "</td><td>" +
        escape_html(entry.pinyin) +
        "</td><td>" +
        level_label(entry.level) +
        "</td><td>" +
        entry.count.to_string() +
        "</td>"
      if has_explanation {
        out = out +
          "<td>" +
          escape_html(lookup_explanation(explanations, entry.word)) +
          "</td>"
      }
      out = out + "</tr>\n"
    }
    out = out + "</table>\n"
  }
  // 精读句：把「今天该看哪几句」直接给出来
  out = out + "<h2>值得精读的句子</h2>\n"
  if picked.length() == 0 {
    out = out + "<p class=\"hint\">还没有可推荐的句子。</p>\n"
  } else {
    out = out + "<ul class=\"sentences\">\n"
    for report in picked {
      out = out + "<li>" + escape_html(report.text)
      let unknown = report.unknown.join("、")
      if unknown != "" {
        out = out +
          "<br><span class=\"hint\">生词：" +
          escape_html(unknown) +
          "</span>"
      }
      out = out + "</li>\n"
    }
    out = out + "</ul>\n"
  }
  out = out +
    "<footer>由「拾级 Stepwise」生成 · 词表 HSK 3.0 · 覆盖率门槛 95%</footer>\n"
  out = out + "</div>\n"
  if interactive {
    out = out + PAGE_SCRIPT + "\n"
  }
  out = out + "</body>\n</html>\n"
  out
}

///|
/// 交互模式注入的脚本：点一段，交给本机服务去问模型。
///
/// 用 `#|` 原样字符串写，所以 JS 里的花括号和反斜杠都不用转义。
const PAGE_SCRIPT : String =
  #|<script>
  #|  const askExplain = async (para) => {
  #|    const previous = para.nextElementSibling;
  #|    if (previous && previous.classList.contains('card')) previous.remove();
  #|    const card = document.createElement('div');
  #|    card.className = 'card';
  #|    card.textContent = '正在让模型解释这一段……';
  #|    para.after(card);
  #|    try {
  #|      const res = await fetch('explain', {
  #|        method: 'POST',
  #|        headers: { 'Content-Type': 'application/json' },
  #|        body: JSON.stringify({ text: para.innerText })
  #|      });
  #|      if (!res.ok) throw new Error('HTTP ' + res.status);
  #|      const data = await res.json();
  #|      card.textContent = '';
  #|      const zh = document.createElement('div');
  #|      zh.className = 'zh';
  #|      zh.textContent = data.zh;
  #|      card.append(zh);
  #|      if (data.en) {
  #|        const en = document.createElement('div');
  #|        en.className = 'en';
  #|        en.textContent = data.en;
  #|        card.append(en);
  #|      }
  #|      if (data.audit) {
  #|        const note = document.createElement('div');
  #|        note.className = 'note';
  #|        note.textContent = data.audit;
  #|        card.append(note);
  #|      }
  #|    } catch (err) {
  #|      card.textContent = '连不上本机服务。请用 stepwise serve 启动后再刷新页面；'
  #|        + '直接双击打开的文件是静态的，点不动。';
  #|    }
  #|  };
  #|  document.querySelectorAll('.text > p').forEach((para) => {
  #|    para.classList.add('clickable');
  #|    para.title = '点一下，让模型解释这一段';
  #|    para.addEventListener('click', () => askExplain(para));
  #|  });
  #|</script>

///|
/// 从解释表里取出某个词的解释，没有就返回空串。
fn lookup_explanation(
  explanations : Array[(String, String)],
  word : String,
) -> String {
  for pair in explanations {
    if pair.0 == word {
      return pair.1
    }
  }
  ""
}
