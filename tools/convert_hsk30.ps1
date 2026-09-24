# 把 ivankra/hsk30 的 CSV 转成本项目使用的 TSV 词表。
#
# 用法（在项目根目录）：
#   pwsh tools/convert_hsk30.ps1
#
# 输入 data/source/hsk30-expanded.csv 已经是「变体展开过」的版本，
# 每一行就是一个干净词形，不需要再处理 爸爸|爸 或 有（一）点儿 这类写法。

param(
  [string]$InputPath = "data/source/hsk30-expanded.csv",
  [string]$OutputPath = "data/hsk30.tsv"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $InputPath)) {
  Write-Error "找不到输入文件：$InputPath"
  exit 1
}

$rows = Import-Csv $InputPath

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# 本文件由 tools/convert_hsk30.ps1 生成，请勿手工编辑。")
$lines.Add("#")
$lines.Add("# 词源：HSK 3.0《国际中文教育中文水平等级标准》(GF 0025-2021) 词汇表")
$lines.Add("# 数据来源：https://github.com/ivankra/hsk30 （MIT License）")
$lines.Add("# 等级 7 代表官方标准中的「7-9 级」高级段。")
$lines.Add("# 格式：词 <TAB> 等级 <TAB> 拼音")

$seen = @{}
$skippedEmpty = 0
$duplicates = 0

foreach ($item in $rows) {
  $word = $item.Simplified.Trim()
  if ([string]::IsNullOrWhiteSpace($word)) {
    $skippedEmpty++
    continue
  }

  # 同一个词可能因为多音、多义出现多次，保留第一次出现的等级。
  if ($seen.ContainsKey($word)) {
    $duplicates++
    continue
  }
  $seen[$word] = $true

  $level = switch ($item.Level) {
    "7-9" { 7 }
    default { [int]$item.Level }
  }

  $pinyin = if ($null -eq $item.Pinyin) { "" } else { $item.Pinyin.Trim() }

  $lines.Add("$word`t$level`t$pinyin")
}

# 一律用 LF 写出去，和其他文本文件保持一致。
$text = ($lines -join "`n") + "`n"
[System.IO.File]::WriteAllText(
  (Resolve-Path -LiteralPath (Split-Path $OutputPath -Parent)).Path + "\" + (Split-Path $OutputPath -Leaf),
  $text,
  (New-Object System.Text.UTF8Encoding($false))
)

Write-Output "词条数：$($seen.Count)"
Write-Output "跳过空行：$skippedEmpty"
Write-Output "去重：$duplicates"
Write-Output "已写入：$OutputPath"
