# 生成一个最小但结构完整的 EPUB 3 样本，供测试与演示使用。
#
# 用法（在项目根目录）：
#   pwsh tools/make_sample_epub.ps1
#
# 生成 samples/sample.epub：mimetype 按规范第一个写入且不压缩，
# 后面是 container.xml、content.opf 和两章正文。

param(
  [string]$OutputPath = "samples/sample.epub"
)

$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$title = "我的中国朋友"

$containerXml = @'
<?xml version="1.0" encoding="UTF-8"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>
'@

$contentOpf = @"
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="bookid">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>$title</dc:title>
    <dc:language>zh-CN</dc:language>
    <dc:identifier id="bookid">stepwise-sample-1</dc:identifier>
  </metadata>
  <manifest>
    <item id="chap1" href="chap1.xhtml" media-type="application/xhtml+xml"/>
    <item id="chap2" href="chap2.xhtml" media-type="application/xhtml+xml"/>
  </manifest>
  <spine>
    <itemref idref="chap1"/>
    <itemref idref="chap2"/>
  </spine>
</package>
"@

$chap1 = @'
<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>第一章 我有一个中国朋友</title></head>
<body>
<h1>第一章</h1>
<p>我有一个中国朋友，他叫小明。我们是同学，一起在学校学习中文。</p>
<p>小明的家很近，走路只要十分钟。周末的时候，我常常去他家。他的妈妈很热情，每次都给我喝茶，还做很好吃的米饭。</p>
</body>
</html>
'@

$chap2 = @'
<?xml version="1.0" encoding="UTF-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
<head><title>第二章 茶是一种语言</title></head>
<body>
<h1>第二章</h1>
<p>有一次，我问他：&ldquo;为什么中国人这么喜欢喝茶？&rdquo;他说：&ldquo;因为茶不只是水，还是一种语言。&rdquo;</p>
<p>我觉得这句话很有意思。学习中文不只是记生词，也是在学习一种看世界的方法。</p>
</body>
</html>
'@

$outDir = Split-Path $OutputPath -Parent
if (-not (Test-Path $outDir)) {
  New-Item -ItemType Directory -Path $outDir | Out-Null
}
$fullPath = [System.IO.Path]::GetFullPath($OutputPath)
if (Test-Path $fullPath) {
  Remove-Item -LiteralPath $fullPath -Force
}

$utf8 = New-Object System.Text.UTF8Encoding($false)

$zip = [System.IO.Compression.ZipFile]::Open($fullPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
  function Add-Entry {
    param($Archive, $Name, $Content, $Compressed)
    $level = if ($Compressed) {
      [System.IO.Compression.CompressionLevel]::Optimal
    } else {
      [System.IO.Compression.CompressionLevel]::NoCompression
    }
    $entry = $Archive.CreateEntry($Name, $level)
    $stream = $entry.Open()
    $bytes = $utf8.GetBytes($Content)
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Dispose()
  }

  # mimetype 必须是第一个条目，且不压缩——这是 EPUB 规范的要求。
  Add-Entry $zip "mimetype" "application/epub+zip" $false
  Add-Entry $zip "META-INF/container.xml" $containerXml $true
  Add-Entry $zip "OEBPS/content.opf" $contentOpf $true
  Add-Entry $zip "OEBPS/chap1.xhtml" $chap1 $true
  Add-Entry $zip "OEBPS/chap2.xhtml" $chap2 $true
}
finally {
  $zip.Dispose()
}

Write-Output "已生成：$OutputPath（$((Get-Item $fullPath).Length) 字节）"
