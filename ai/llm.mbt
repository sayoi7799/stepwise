///|
/// 一次模型调用的请求。
///
/// 温度也用千分数存（300 表示 0.3），和流水线其余部分保持一致：
/// 不引入浮点，日志和快照因此完全可比。
pub struct LlmRequest {
  system : String
  user : String
  temperature_permille : Int
} derive(Debug)

///|
pub extend LlmRequest with Debug::{to_repr}

///|
/// 模型的回复。
pub struct LlmResponse {
  text : String
} derive(Debug)

///|
pub extend LlmResponse with Debug::{to_repr}

///|
/// 调用模型可能出的岔子。
pub(all) suberror LlmError {
  Network(String)
  RateLimited(String)
  BadResponse(String)
}

///|
/// 给人看的错误描述。
pub fn LlmError::to_string(self : LlmError) -> String {
  match self {
    Network(why) => "网络问题：\{why}"
    RateLimited(why) => "被限流：\{why}"
    BadResponse(why) => "响应不符合预期：\{why}"
  }
}

///|
/// 模型客户端。
///
/// 这是整条流水线里唯一不确定的东西，所以它被压缩成一个 trait：
/// 生产环境是真客户端，测试里换成脚本化的假客户端，CI 不联网、
/// 不需要 API key 也能跑完整流程。
pub(open) trait LlmClient {
  async fn complete(Self, LlmRequest) -> LlmResponse raise LlmError
}

///|
/// 脚本化的假客户端：按顺序吐出预设回复，并记下每次收到的提示词。
pub struct ScriptedClient {
  replies : Array[String]
  mut cursor : Int
  prompts : Array[String]
}

///|
pub fn ScriptedClient::new(replies : Array[String]) -> ScriptedClient {
  { replies, cursor: 0, prompts: [], }
}

///|
/// 已经被调用过几次。
pub fn ScriptedClient::calls(self : ScriptedClient) -> Int {
  self.cursor
}

///|
/// 调用过程中收到的提示词，按顺序排列。
pub fn ScriptedClient::prompts(self : ScriptedClient) -> Array[String] {
  self.prompts
}

///|
pub impl LlmClient for ScriptedClient with fn complete(self, request) {
  self.prompts.push(request.user)
  let index = self.cursor
  self.cursor = index + 1
  if index < self.replies.length() {
    { text: self.replies[index], }
  } else {
    raise BadResponse("脚本里已经没有更多回复了")
  }
}

///|
pub extend ScriptedClient with LlmClient::{complete}

///|
/// 温度的可读文本，例如 `"0.3"`。
pub fn LlmRequest::temperature_text(self : LlmRequest) -> String {
  let permille = self.temperature_permille
  "\{permille / 1000}.\{permille % 1000 / 100}"
}
