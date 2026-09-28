///|
/// 启动本机服务：学习版页面和模型调用都从本机走。
///
/// 为什么不让页面自己去调模型 API：那样既要把 API key 塞进网页
/// （谁拿到这个文件谁就拿到你的 key），又要跟浏览器的跨域策略较劲。
/// 起一个本机服务，页面同源请求它，key 只留在环境变量里，一步都不外泄。
async fn run_serve(args : Array[String]) -> Unit {
  let path = match positional(args, 2) {
    None => {
      print_usage()
      return
    }
    Some(value) => value
  }
  let lexicon = load_lexicon(args)
  let learner = learner_from(args)
  let text = match load_text(path, args) {
    None => {
      println("读不到文件：\{path}")
      return
    }
    Some(value) => value.1
  }
  let title = book_title(path).unwrap_or(path)
  let key = api_key()
  if key is None {
    println(
      "提醒：没有找到 DEEPSEEK_API_KEY，页面能打开、生词会高亮，",
    )
    println(
      "      但点段落不会出解释。设置好 key 再重启本服务即可。\n",
    )
  }
  // 预先把前几个生词的解释做好，页面一打开就有内容可看
  let explanations = match key {
    None => []
    Some(value) => {
      let limit = int_flag(args, "--explain-top", 3)
      if limit <= 0 {
        []
      } else {
        let vocab = @learner.collect_vocabulary(text, lexicon, learner)
        explain_top_vocab(
          vocab,
          lexicon,
          learner,
          limit,
          value,
          int_flag(args, "--attempts", 3),
        )
      }
    }
  }
  let page = @export.study_page(
    title,
    text,
    lexicon,
    learner,
    explanations,
    interactive=true,
  )
  let page_bytes = @utf8.encode(page)
  let port = int_flag(args, "--port", 8787)
  let address = "127.0.0.1:\{port}"
  let server = @ahttp.Server(@socket.Addr::parse(address))
  println("学习版已就绪：http://\{address}/")
  println(
    "在页面里点任意一段，就会让模型解释它。按 Ctrl+C 结束。\n",
  )
  server.run_forever() <| ((request, body, conn) => {
    let route = request.path
    match request.meth {
      @ahttp.RequestMethod::Get =>
        if route == "/" {
          serve_page(conn, page_bytes)
        } else {
          serve_not_found(conn)
        }
      @ahttp.RequestMethod::Post =>
        if route == "/explain" {
          serve_explain(
            conn,
            body,
            key,
            lexicon,
            learner,
            int_flag(args, "--attempts", 2),
          )
        } else {
          serve_not_found(conn)
        }
      _ => serve_not_found(conn)
    }
  })
}

///|
/// 把学习版页面发给浏览器。
async fn serve_page(conn : @ahttp.ServerConnection, page : Bytes) -> Unit {
  conn
  ..send_response(200, "OK", extra_headers={
    "Content-Type": "text/html; charset=utf-8",
  })
  ..write(page)
  .end_response()
}

///|
async fn serve_not_found(conn : @ahttp.ServerConnection) -> Unit {
  conn
  ..send_response(404, "NotFound", extra_headers={
    "Content-Type": "text/plain",
  })
  ..write(b"not found")
  .end_response()
}

///|
/// 回应「点了一段」：把这一段改写成学习者读得懂的中文，附英文对照。
///
/// 中文那一半照样要过可读性审计——不达标就带着上一轮的超纲词重试。
/// 页面上会显示覆盖率，学习者看得见我们凭什么说它是「读得懂的」。
async fn serve_explain(
  conn : @ahttp.ServerConnection,
  body : &@io.Reader,
  key : String?,
  lexicon : @lexicon.Lexicon,
  learner : @learner.Learner,
  attempts : Int,
) -> Unit {
  let payload = body.read_all().text() catch { _ => "" }
  let sentence = extract_text_field(payload)
  let result = match key {
    None => {
      let json = Json::object({
        "zh": Json::string(
          "本机没有配置 DEEPSEEK_API_KEY，无法解释。",
        ),
        "en": Json::string(""),
        "audit": Json::string("请在启动服务前设置 DEEPSEEK_API_KEY。"),
      })
      json.stringify()
    }
    Some(api_key_value) =>
      match sentence {
        None =>
          Json::object({
            "zh": Json::string("这一段读不出来。"),
            "en": Json::string(""),
            "audit": Json::string(""),
          }).stringify()
        Some(value) => {
          let client = @ai.OpenAiCompatClient::new(api_key_value)
          let (chinese, english, note) = sentence_help(
            client, value, lexicon, learner, attempts,
          ) catch {
            error => {
              let message = error.to_string()
              ("调用模型失败：\{message}", "", "")
            }
          }
          Json::object({
            "zh": Json::string(chinese),
            "en": Json::string(english),
            "audit": Json::string(note),
          }).stringify()
        }
      }
  }
  let bytes = @utf8.encode(result)
  conn
  ..send_response(200, "OK", extra_headers={
    "Content-Type": "application/json; charset=utf-8",
  })
  ..write(bytes)
  .end_response()
}

///|
/// 从请求体里取出 `{"text": "..."}` 的正文。
fn extract_text_field(payload : String) -> String? {
  let json = @json.parse(payload) catch { _ => return None }
  let fields = match json {
    Object(object) => object
    _ => return None
  }
  match fields.get("text") {
    Some(value) =>
      match value {
        String(text) => Some(text)
        _ => None
      }
    None => None
  }
}

///|
/// 带审计的整句解释：返回（更简单的中文，英文，审计说明）。
///
/// 中文部分不达标就带着具体超纲词重试；英文部分不参与审计——
/// 它的作用是给一个意思上的锚，不是给学习者读的材料。
async fn[C : @ai.LlmClient] sentence_help(
  client : C,
  sentence : String,
  lexicon : @lexicon.Lexicon,
  learner : @learner.Learner,
  attempts : Int,
) -> (String, String, String) raise @ai.LlmError {
  let mut avoid : Array[String] = []
  let mut chinese = ""
  let mut english = ""
  let mut coverage = 1000
  let mut round = 0
  while round < attempts {
    let request = @ai.sentence_help_prompt(sentence, learner.level(), avoid)
    let response = client.complete(request)
    let (zh, en) = @ai.parse_sentence_help(response.text)
    chinese = zh
    english = en
    let stats = @ai.audit(chinese, lexicon, learner)
    coverage = stats.coverage_permille()
    if @ai.acceptable_explanation(stats) {
      break
    }
    avoid = stats.unknown_types()
    round = round + 1
  }
  let note = if coverage >= 950 {
    "可读性审计：覆盖率 \{coverage / 10}.\{coverage % 10}% —— 这段改写在你当前水平内。"
  } else {
    "可读性审计：覆盖率 \{coverage / 10}.\{coverage % 10}%，仍有超纲词（\{avoid.join("、")}）。"
  }
  (chinese, english, note)
}
