///|
test "接口地址：默认指向 DeepSeek，末尾多写斜杠也能容忍" {
  let client = @ai.OpenAiCompatClient::new("test-key")
  assert_eq(client.endpoint(), "https://api.deepseek.com/chat/completions")
  assert_eq(client.model(), "deepseek-chat")
  let other = @ai.OpenAiCompatClient::new(
    "test-key",
    base_url="https://example.com/v1/",
    model="other-model",
  )
  assert_eq(other.endpoint(), "https://example.com/v1/chat/completions")
  assert_eq(other.model(), "other-model")
}

///|
test "报文组装：两条消息，温度从千分数换算成小数" {
  let request = @ai.explain_word_prompt(
    "词", "cí", 3, "这个中文词很好。", 2, false,
  )
  let text = @ai.chat_request_json("deepseek-chat", request).stringify()
  assert_eq(text.contains("\"model\":\"deepseek-chat\""), true)
  assert_eq(text.contains("\"role\":\"system\""), true)
  assert_eq(text.contains("\"role\":\"user\""), true)
  assert_eq(text.contains("\"temperature\":0.3"), true)
  assert_eq(text.contains("\"stream\":false"), true)
  // 提示词的约束必须原样进报文，不能在路上被改掉
  assert_eq(text.contains("不要给英文翻译"), true)
}

///|
test "解析响应：取第一条 choice 的 content" {
  let body = @json.parse(
    "{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"这个词的意思是很好。\"}}]}",
  ) catch {
    _ => fail("测试用的 JSON 应当能解析")
  }
  let result : Result[String, @ai.LlmError] = Ok(@ai.chat_response_text(body)) catch {
    e => Err(e)
  }
  match result {
    Ok(text) => assert_eq(text, "这个词的意思是很好。")
    Err(e) => fail("解析失败：\{e.to_string()}")
  }
}

///|
test "解析响应：服务端报错时把 error 原样带出来" {
  let body = @json.parse("{\"error\":{\"message\":\"Invalid API key\"}}") catch {
    _ => fail("测试用的 JSON 应当能解析")
  }
  let result : Result[String, @ai.LlmError] = Ok(@ai.chat_response_text(body)) catch {
    e => Err(e)
  }
  match result {
    Err(@ai.LlmError::BadResponse(message)) =>
      assert_eq(message.contains("Invalid API key"), true)
    _ => fail("应当报 BadResponse")
  }
}

///|
test "解析响应：字段缺失时说清楚缺了什么" {
  let no_choices = @json.parse("{\"id\":\"x\"}") catch {
    _ => fail("测试用的 JSON 应当能解析")
  }
  let result : Result[String, @ai.LlmError] = Ok(
    @ai.chat_response_text(no_choices),
  ) catch {
    e => Err(e)
  }
  match result {
    Err(@ai.LlmError::BadResponse(message)) =>
      assert_eq(message.contains("没有 choices"), true)
    _ => fail("应当报 BadResponse")
  }
}

///|
test "错误的可读描述" {
  assert_eq(
    @ai.LlmError::Network("超时").to_string(),
    "网络问题：超时",
  )
  assert_eq(
    @ai.LlmError::BadResponse("空").to_string(),
    "响应不符合预期：空",
  )
}
