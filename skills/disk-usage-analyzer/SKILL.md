---
name: disk-usage-analyzer
description: 磁盘使用分析 Skill。当陈老师说"分析磁盘占用"、"查看文件大小"、"openclaw 占用"或类似需求时执行。功能：生成交互式矩形树图（Treemap），展示指定目录的磁盘占用情况，便于发现哪些文件和文件夹占用空间最大。
---

# Disk Usage Analyzer

## 触发条件

陈老师说"分析磁盘占用"、"查看文件大小"、"openclaw 占用"或类似需求时执行。

## 执行流程

### 第1步：获取磁盘占用数据

```bash
# 分析 OpenClaw 目录
du -ah ~/.openclaw --max-depth=2 2>/dev/null | grep -v "^0" | sort -hr | head -50

# 分析其他目录
du -ah <目录路径> --max-depth=2 | sort -hr | head -50

# 快速查看一级目录总大小
du -sh ~/.openclaw/*
```

### 第2步：生成树图 HTML

1. 将 `du` 数据整理成 ECharts 矩形树图格式（JSON）
2. 读取模板：`~/.openclaw/workspace/skills/disk-usage-analyzer/assets/openclaw-disk-usage.html`
3. 替换以下占位符：
   - `<!--TOTAL_SIZE-->` → 总大小（如 "1.1 GB"）
   - `<!--UPDATE_TIME-->` → 当前时间（如 "2026-03-24"）
   - `<!--DATA_JSON-->` → 整理后的 JSON 数据树
4. 输出路径：`~/.openclaw/workspace/openclaw-disk-usage.html`

### 第3步：输出结果

- 告诉陈老师 HTML 文件路径
- 如需展示，可调用 `browser` 工具打开

## ECharts 矩形树图数据结构

```json
{
  "name": ".openclaw",
  "value": 1126400,
  "children": [
    {
      "name": "browser",
      "value": 1011712,
      "children": [
        {
          "name": "user-data",
          "value": 948672,
          "children": [
            { "name": "Cache/Cache_Data", "value": 608256 },
            { "name": "Code Cache/js", "value": 199680 }
          ]
        }
      ]
    }
  ]
}
```

**注意**：`value` 单位为 KB（与 `du` 输出一致）。

## 注意事项

- `browser` 目录通常最大（浏览器缓存），可重点关注
- 超大型目录可调整 `--max-depth` 参数控制深度
- `du -h` 输出以 KB/K/M/G 为单位，需统一转换为 KB
