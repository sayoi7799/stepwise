///|
test "流式增量解析：正文、心跳、结束标记、坏数据" {
  assert_eq(
    @ai.stream_delta_text(
      "{\"choices\":[{\"delta\":{\"content\":\"你好\"}}]}",
    ),
    Some("你好"),
  )
  assert_eq(@ai.stream_delta_text("[DONE]"), None)
  // 第一帧只有 role，没有正文
  assert_eq(
    @ai.stream_delta_text(
      "{\"choices\":[{\"delta\":{\"role\":\"assistant\"}}]}",
    ),
    None,
  )
  // 认不出来的载荷不该让整次调用失败
  assert_eq(@ai.stream_delta_text("这不是 JSON"), None)
  assert_eq(@ai.stream_delta_text("{\"choices\":[]}"), None)
}

///|
test "SSE 缓冲：半个事件跨块送达，两个事件粘在一块" {
  let buffer = @ai.SseBuffer::new()
  // 第一块只有半个事件，什么都吐不出来
  assert_eq(buffer.feed(b"data: {\"a\"").length(), 0)
  // 第二块把第一个事件补完，同时带来第二个
  let second = buffer.feed(b":1}\ndata: [DONE]\n")
  assert_eq(second.length(), 2)
  assert_eq(second[0], "{\"a\":1}")
  assert_eq(second[1], "[DONE]")
}

///|
test "SSE 缓冲：注释行与其他字段被忽略" {
  let buffer = @ai.SseBuffer::new()
  let payloads = buffer.feed(
    b": heartbeat\nevent: message\ndata: {\"x\":1}\n\n",
  )
  assert_eq(payloads.length(), 1)
  assert_eq(payloads[0], "{\"x\":1}")
}
