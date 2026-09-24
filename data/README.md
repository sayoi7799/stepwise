# 词表目录

## 文件

| 文件 | 说明 |
| --- | --- |
| `hsk30.tsv` | 本项目实际使用的词表，10,978 条，由脚本从下面的原始数据生成 |
| `source/hsk30-expanded.csv` | 原始数据：变体已展开，一行一个词形 |
| `source/hsk30.csv` | 原始数据：未展开变体（保留作对照，程序不读它） |
| `source/LICENSE-hsk30.txt` | 原始数据的许可证 |

`hsk30.tsv` 是生成物，**不要手工编辑**——改了会在下次重新生成时丢掉。

## 数据来源与许可

- 词源：HSK 3.0《国际中文教育中文水平等级标准》(GF 0025-2021) 词汇表
- 数据整理：[ivankra/hsk30](https://github.com/ivankra/hsk30)，MIT License
- 版权：Copyright (c) 2023 Ivan Krasilnikov、Copyright (c) 2021 Shawky、
  Copyright (c) 2021 Pleco Inc.，全文见 `source/LICENSE-hsk30.txt`
- 取得日期：2026-09-24

MIT 许可证要求保留版权声明，所以 `source/` 下的两份原始 CSV 和许可证文件
都随仓库一起提交，没有做删改。

## TSV 格式

```
词 <TAB> 等级 <TAB> 拼音
爱	1	ài
爱好	1	àihào
```

- 行首为 `#` 的是注释，加载时被忽略
- 等级为 1-7 的整数，**7 代表官方标准中的「7-9 级」高级段**
- 拼音可以省略（本词表全部填了）

想换成别的词表（HSK 2.0、TOCFL、你自己的分级表），只要保持上面这三列
就能直接用，不需要改代码：

```bash
moon run cmd/main -- analyze 你的文章.txt --lexicon 你的词表.tsv
```

## 生成过程

```powershell
pwsh tools/convert_hsk30.ps1
```

脚本做三件事：

1. 把等级字段 `7-9` 记成 `7`；
2. 同一个词出现多次时保留第一次出现的等级（本次去重 187 条）；
3. 以 UTF-8 无 BOM、LF 换行写出 `hsk30.tsv`。

转换结果：11,165 行原始数据 → 10,978 条词表，各等级分布为
1 级 508、2 级 753、3 级 953、4 级 973、5 级 1059、6 级 1124、7 级 5608。
