# 拾级 Stepwise

**给中文学习者的分级阅读流水线：用中文理解中文，而不是逐句翻译。**

Stepwise is a graded-reading pipeline for learners of Chinese. Instead of
translating a page into English, it measures how much of a text you already
understand, finds the words that are exactly one level above you, and keeps
every explanation inside Chinese you can already read.

## 为什么不是「又一个翻译器」

把一段中文翻成英文，学习者读完只记住了英文，中文还是没进去。真正让语言
长起来的是**可理解输入**：读的东西刚好只比现在的水平难一点点，也就是常说的
「i + 1」。

所以这个项目的立场是：

1. **不翻译。** 解释用中文写，并且解释本身也要控制在学习者的词汇范围之内。
2. **先量再读。** 一篇文本对某个学习者到底难不难，用已知词覆盖率算出来，
   不靠感觉。
3. **在语境里学词。** 生词卡片背面放的是它出现的那句话，不是中英对照。

第二条和第三条都能在离线状态下验证，第一条则由下面这个机制兜底。

## 模型的输出也要过一遍我们的尺子

整条流水线里唯一不确定的东西是模型调用，所以它被压缩成一个 trait。
模型给出的解释会被送回**我们自己的分词器和学习者模型**审计：如果解释里
超纲词太多，就带上更严格的约束重新生成。

```
生成解释 → 用自己的分词器审可读性 → 不达标就加严重试 → 达标才给学习者看
```

这意味着 CI 里不需要 API key、不需要网络，也能把整条流程跑完整——测试用的
是脚本化的假客户端（`ai.ScriptedClient`）；真客户端也走同一个 trait。

## 现在能做什么

### 读一整本 EPUB

```bash
moon run cmd/main -- analyze samples/sample.epub --level 2
```

```
# 我的中国朋友

## 全书概览

- 章节数：2
- 已知词覆盖率：89.6%
- 生词：7 个（共出现 11 次）

## 逐章体检

| 章节 | 词数 | 覆盖率 | 判定 |
| --- | --- | --- | --- |
| 第一章 我有一个中国朋友 | 57 | 91.2% | 有点挑战，需要一点支撑 |
| 第二章 茶是一种语言 | 49 | 87.7% | 偏难，建议先降级改写再读 |
```

EPUB 就是 ZIP 加一套 XML。这里按规范三步走：先读
`META-INF/container.xml` 找到 OPF，再从 OPF 读清单与阅读顺序，最后按
spine 顺序把每章 XHTML 提成纯文本。解压交给 `moonbit-community/zipc`，
路径解析、实体解码、标签剥离都是自己的代码，全部有测试。
加 `--chapter 2` 可以只看某一章。

### 真的让模型解释一个词

```bash
export DEEPSEEK_API_KEY=sk-...
moon run cmd/main -- explain 意思 "这句话很有意思。" --pinyin yìsi --word-level 3
```

```
模型：deepseek-chat
学习者水平：HSK 2

（模型用中文给出的解释）

可读性审计：覆盖率 96.0%，生词 1 个
结论：这段解释对当前水平是够浅的。
```

HTTP、TLS、连接池交给 `gaato/http-async`（底子是官方的
`moonbitlang/async`）；拼报文和读响应是我们自己的纯函数，有测试精确固定。
想先看看要发出去什么，用 `prompt` 命令，它完全离线。

### 单篇文章

```bash
moon run cmd/main -- analyze samples/sample.txt --level 2
```

```
# samples/sample.txt

学习者水平：HSK 2

## 概览

- 句子数：11
- 词数：117
- 已知词覆盖率：90.5%
- 生词：7 个（共出现 11 次）
- 判定：有点挑战，需要一点支撑

## 生词表

| 词 | 拼音 | 等级 | 出现 |
| --- | --- | --- | --- |
| 只是 | zhǐshì | HSK 3 | 2 |
| 慢慢 | mànmàn | HSK 3 | 2 |
| 世界 | shìjiè | HSK 3 | 1 |
...
```

其它命令：

```bash
moon run cmd/main -- vocab  <文件> [--level N]      只列生词表
moon run cmd/main -- anki   <文件> [--level N]      导出 Anki 可直接导入的卡片
moon run cmd/main -- prompt <词> <原句> [--level N] 打印会发给模型的提示词（离线）
```

（`stepwise` 是产品名；开发期统一用 `moon run cmd/main --` 调用，命令要在
项目根目录执行，因为默认词表路径是相对的。）

## 快速开始

1. 安装 MoonBit 工具链（Windows PowerShell）：

   ```powershell
   irm https://cli.moonbitlang.com/install/powershell.ps1 | iex
   ```

2. 在项目根目录跑：

   ```bash
   moon check          # 编译检查
   moon test           # 52 个测试，全部离线
   moon run cmd/main -- analyze samples/sample.txt --level 2
   ```

## 设计要点

**确定性的内核，不确定的外壳。** 分句、分词、覆盖率、生词表、句子评分、
复习调度全是纯函数式的加分模块，能写精确断言；只有一次模型调用是变化的，
被隔离在 `LlmClient` 后面。

**时钟和随机数由调用方传入。** `srs.review(card, grade, today)` 不读系统
时间，所以「一个月后的复习计划」在测试里可以瞬间验证。同一个原则也用在
审计和报告里——同样的输入永远得到同样的字节。

**不引入浮点。** 覆盖率存千分数（761 表示 76.1%），SM-2 的难度系数同样存
千分数。跨后端结果一致，快照测试稳定，也避免小数格式在各处的差异。

**分词用双向最大匹配。** 正向和反向各切一遍，取词数更少的结果；词数相同时
取单字更少的结果。`研究生命的起源` 会被正确切成 `研究 / 生命 / 的 / 起源`，
而不是正向匹配会得到的 `研究生 / 命 / 的 / 起源`——这条有专门的测试。

## 目录结构

```
lexicon/   词表：TSV 加载、等级查询、最长词长度
segment/   分句、双向最大匹配分词、token 类型与偏移
learner/   学习者画像、覆盖率、难度分档、生词表、精读句挑选
srs/       间隔重复调度（SM-2，整数版本）
epub/      EPUB 读取：ZIP 容器、OPF 清单、XHTML 转纯文本
ai/        模型接口与 OpenAI 兼容客户端、提示词组装、输出审计、质量闸门
export/    Anki 卡片导出、Markdown 阅读报告
cmd/main/  命令行入口
data/      HSK 3.0 词表与原始数据（含许可说明）
tools/     词表转换脚本
samples/   示例文本
```

## 词表

仓库里带的是完整的 **HSK 3.0 词汇表，10,978 个词**，来自
《国际中文教育中文水平等级标准》(GF 0025-2021)，经
[ivankra/hsk30](https://github.com/ivankra/hsk30) 整理，MIT 许可。
原始 CSV 和许可证全文都随仓库提交在 `data/source/`，转换脚本在
`tools/convert_hsk30.ps1`，细节见 `data/README.md`。

各等级词数：1 级 508、2 级 753、3 级 953、4 级 973、5 级 1059、
6 级 1124、7 级 5608（7 代表官方的「7-9 级」高级段）。

换词表不需要改代码，只要保持「词 / 等级 / 拼音」三列：

```bash
moon run cmd/main -- analyze 你的文章.txt --lexicon 你的词表.tsv
```

示例文本里 `明` 被标成「未收录」，是因为它来自人名「小明」——
HSK 词表不收专有名词，这是分词在真实文本上的正常边界，
后续会加一份人名/地名忽略表来减少这类噪声。

## 测试

```bash
moon test
```

覆盖内容包括：词表解析与脏数据、断句的边界情况（省略号、连续句末标点、
收尾引号、小数点不误判）、分词的双向匹配修正、覆盖率与分档边界、生词表
排序与去重、SM-2 的间隔序列与难度下限、模型输出审计与重试闸门、Anki 导出
的字段转义。

## 路线图

- [x] 接入完整 HSK 3.0 词表（10,978 词，含拼音与许可说明）
- [ ] 人名 / 地名 / 专有名词忽略表，减少「小明」这类假生词
- [x] EPUB 读取：整本书切章节、逐章评估
- [x] 真模型客户端（OpenAI 兼容接口），假客户端保留为测试默认
- [ ] SSE 流式输出：边生成边显示
- [ ] Markdown / 纯文本的章节切分
- [ ] 跨章节的词汇去重，按「这一章需要的新词」组织复习
- [ ] 阅读进度与复习记录持久化，让掌握范围真的随时间长大
- [ ] `wasm-gc` 后端的浏览器阅读器

## 与 2026 MoonBit 黑客松的对应

方向属于「AI 应用」。项目的主要实现语言是 MoonBit，确定性内核与模型外壳
分离，全部测试离线可复现。

## 许可证

Apache-2.0。见 `LICENSE`。

参赛用的一页项目说明见 `docs/项目说明.md`。
