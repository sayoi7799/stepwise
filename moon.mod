// 拾级 Stepwise —— 中文分级阅读流水线
// 模块配置文档：https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// 发布到 mooncakes 前，把 name 改成 "你的 GitHub ID/stepwise"。

name = "stepwise"

version = "0.1.0"

readme = "README.md"

repository = ""

license = "Apache-2.0"

keywords = [ "chinese", "graded-reader", "language-learning", "nlp", "llm" ]

preferred_target = "native"

description = "中文分级阅读流水线：用中文理解中文，而不是逐句翻译"

import {
  "moonbitlang/x@0.5.5",
  "moonbit-community/zipc@0.2.2",
  "gaato/http-async@0.1.1",
  "gaato/http@0.1.0",
  "moonbitlang/async@0.22.3",
}
