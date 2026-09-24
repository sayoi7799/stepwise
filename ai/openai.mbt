///|
/// OpenAI 兼容接口的客户端。
///
/// 默认指向 DeepSeek（`https://api.deepseek.com`），任何实现了
/// Chat Completions 协议的服务改 `base_url` 就能用。
///
/// 这里刻意只做「拼请求 + 读响应」这一层：HTTP、连接池、超时、TLS
/// 都交给 gaato/http-async 提供的传输层，我们不重复造轮子，
/// 但也因此能用它的假传输层在测试里完全离线地验证报文。
pub struct OpenAiCompatClient {
  transport : @async_http.AsyncTransport
  base_url : String
  api_key : String
  model : String
}

///|
pub fn OpenAiCompatClient::new(
  api_key : String,
  base_url? : String = "https://api.deepseek.com",
  model? : String = "deepseek-chat",
) -> OpenAiCompatClient {
  {
    transport: @async_http.AsyncTransport::new(timeout_ms=60000),
    base_url,
    api_key,
    model,
  }
}

///|
/// 当前使用的模型名。
pub fn OpenAiCompatClient::model(self : OpenAiCompatClient) -> String {
  self.model
}

///|
/// 补全接口的完整地址。`base_url` 末尾多写一个斜杠也能容忍。
pub fn OpenAiCompatClient::endpoint(self : OpenAiCompatClient) -> String {
  let trimmed = if self.base_url.has_suffix("/") {
    self.base_url[0:self.base_url.length() - 1].to_owned()
  } else {
    self.base_url
  }
  trimmed + "/chat/completions"
}

///|
/// 把一次请求组装成 Chat Completions 报文。
///
/// 纯函数，不碰网络——所以报文长什么样可以被测试精确固定住，
/// 提示词改了什么、报文里就多什么，一测便知。
pub fn chat_request_json(model : String, request : LlmRequest) -> Json {
  let messages = Json::array([
    Json::object({
      "role": Json::string("system"),
      "content": Json::string(request.system),
    }),
    Json::object({
      "role": Json::string("user"),
      "content": Json::string(request.user),
    }),
  ])
  Json::object({
    "model": Json::string(model),
    "messages": messages,
    "temperature": Json::number(
      request.temperature_permille.to_double() / 1000.0,
    ),
    "stream": Json::boolean(false),
  })
}

///|
/// 从响应里取出正文。
///
/// 服务端报错时会直接给 `error` 字段，把它原样带出来比一句
/// 「解析失败」有用得多。
pub fn chat_response_text(response : Json) -> String raise LlmError {
  let fields = match response {
    Object(object) => object
    _ => raise BadResponse("响应不是一个 JSON 对象")
  }
  match fields.get("error") {
    Some(err) => raise BadResponse("服务端返回错误：\{err.stringify()}")
    None => ()
  }
  let choices = match fields.get("choices") {
    None => raise BadResponse("响应里没有 choices 字段")
    Some(value) =>
      match value {
        Array(array) => array
        _ => raise BadResponse("choices 不是数组")
      }
  }
  if choices.length() == 0 {
    raise BadResponse("choices 是空的")
  }
  let first_choice = match choices[0] {
    Object(object) => object
    _ => raise BadResponse("choices[0] 不是 JSON 对象")
  }
  let message = match first_choice.get("message") {
    None => raise BadResponse("choices[0] 里没有 message 字段")
    Some(value) =>
      match value {
        Object(object) => object
        _ => raise BadResponse("choices[0].message 不是 JSON 对象")
      }
  }
  let content = match message.get("content") {
    None => raise BadResponse("message 里没有 content")
    Some(value) => value
  }
  match content {
    String(text) => text
    _ => raise BadResponse("content 不是字符串")
  }
}

///|
pub impl LlmClient for OpenAiCompatClient with fn complete(self, request) {
  let payload = chat_request_json(self.model, request)
  let http_request = @http.Request::post(self.endpoint())
    .header("Content-Type", "application/json")
    .header("Authorization", "Bearer " + self.api_key)
    .json_body(payload)
  let response = self.transport.send(http_request) catch {
    @http.HttpError::Connect(why) =>
      raise Network("连不上模型服务：\{why}")
    @http.HttpError::Timeout(ms) =>
      raise Network("请求超时（\{ms} 毫秒）")
    @http.HttpError::Protocol(why) => raise BadResponse("协议错误：\{why}")
  }
  if !response.is_success() {
    raise BadResponse(
      "HTTP \{response.status}：\{response.text() catch { _ => "" }}",
    )
  }
  let body = response.json() catch {
    _ => raise BadResponse("响应不是合法的 JSON")
  }
  { text: chat_response_text(body), }
}

///|
pub extend OpenAiCompatClient with LlmClient::{complete}
