# 工具

这些脚本是数据准备用的，不参与程序构建。

## `convert_hsk30.ps1`

把 `data/source/hsk30-expanded.csv` 转成程序读取的 `data/hsk30.tsv`。

```powershell
pwsh tools/convert_hsk30.ps1
```

可选参数：

```powershell
pwsh tools/convert_hsk30.ps1 -InputPath 别的.csv -OutputPath 别的.tsv
```

转换规则见 `data/README.md`。
