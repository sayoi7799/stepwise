# 一条命令跑完整条主线，用于演示和自助验收。
#
# 用法（在项目根目录）：
#   pwsh tools/demo.ps1
#
# 前四段不需要网络。最后一段要真的调模型，需要先设置 DEEPSEEK_API_KEY，
# 没设置就自动跳过。

$ErrorActionPreference = "Stop"

function Write-Section {
  param([string]$Title)
  Write-Output ""
  Write-Output ("=" * 60)
  Write-Output "  $Title"
  Write-Output ("=" * 60)
}

function Invoke-Moon {
  param([string[]]$MoonArgs)
  & moon @MoonArgs
  if ($LASTEXITCODE -ne 0) {
    Write-Output ""
    Write-Output "！这一步失败了（exit $LASTEXITCODE），后面的步骤可能不可信。"
  }
}

Write-Section "一、全部测试（离线，不需要 API key）"
Invoke-Moon @("test")

Write-Section "二、读一整本 EPUB，输出逐章体检表"
Invoke-Moon @("run", "cmd/main", "--", "analyze", "samples/sample.epub", "--level", "2")

Write-Section "三、只看第二章"
Invoke-Moon @("run", "cmd/main", "--", "analyze", "samples/sample.epub", "--level", "2", "--chapter", "2")

Write-Section "四、导出 Anki 卡片（背面是生词所在的原文句子）"
Invoke-Moon @("run", "cmd/main", "--", "anki", "samples/sample.epub", "--level", "2")

Write-Section "五、要发给模型的提示词（离线，不联网）"
Invoke-Moon @("run", "cmd/main", "--", "prompt", "意思", "这句话很有意思。", "--pinyin", "yìsi", "--word-level", "3", "--learner-level", "2")

if ($env:DEEPSEEK_API_KEY) {
  Write-Section "六、生成学习版网页（用模型解释前 3 个生词）"
  Invoke-Moon @("run", "cmd/main", "--", "html", "samples/sample.epub", "--level", "2", "--out", "samples/sample.study.html", "--explain-top", "3")
}
else {
  Write-Section "六、生成学习版网页（不调模型，只做高亮与生词表）"
  Invoke-Moon @("run", "cmd/main", "--", "html", "samples/sample.epub", "--level", "2", "--out", "samples/sample.study.html")
}

if ($env:DEEPSEEK_API_KEY) {
  Write-Section "七、真的调模型：生成 → 审计 → 不达标就加严重试"
  Invoke-Moon @("run", "cmd/main", "--", "explain", "意思", "这句话很有意思。", "--pinyin", "yìsi", "--word-level", "3", "--learner-level", "2", "--attempts", "3")
}
else {
  Write-Section "七、真模型这一段需要 DEEPSEEK_API_KEY，已跳过"
  Write-Output "  设置方法（PowerShell，只对当前窗口有效）："
  Write-Output '    $env:DEEPSEEK_API_KEY = "sk-..."'
  Write-Output "  然后再跑一次 pwsh tools/demo.ps1"
}

Write-Output ""
Write-Output "演示结束。学习版网页已生成，用浏览器打开 samples/sample.study.html 就能读。"
