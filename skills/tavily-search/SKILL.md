# SKILL.md - Tavily AI 搜索工具

> 强大的 AI 搜索服务，支持实时网页搜索和内容提取

## 前置要求

### 1. 安装 SDK
```bash
pip install tavily-python
```

### 2. 配置 API Key
**方式一：环境变量**
```bash
echo "TAVILY_API_KEY=tvly-你的API密钥" >> ~/.openclaw/.env
openclaw gateway restart
```

**方式二：运行时传入**（待实现）

---

## 工具定义

### tavily_search
AI 搜索，返回结构化结果。

**参数：**
- `query` (必填): 搜索关键词
- `search_depth`: 搜索深度 - "basic" | "advanced"，默认 "basic"
- `max_results`: 返回结果数量，默认 10
- `include_answer`: 是否包含 AI 摘要，默认 false
- `include_raw_content`: 是否包含原始内容，默认 false
- `include_images`: 是否包含图片，默认 false
- `time_range`: 时间范围 - "day" | "week" | "month" | "year"

**返回：**
```json
{
  "results": [
    {
      "title": "结果标题",
      "url": "https://...",
      "content": "内容摘要",
      "score": 0.95,
      "published_date": "2024-01-01"
    }
  ],
  "answer": "AI 生成的答案摘要",
  "images": ["图片URL列表"]
}
```

### tavily_extract
提取指定网页的详细内容。

**参数：**
- `urls` (必填): 网页 URL，支持单个或多个（用逗号分隔）
- `query`: 要提取的关键信息描述

---

## 使用示例

### 简单搜索
```python
from tavily import TavilyClient
import os

api_key = os.environ.get("TAVILY_API_KEY")
tavily = TavilyClient(api_key=api_key)

response = tavily.search("Python 教程")
for result in response.get("results", []):
    print(f"标题: {result['title']}")
    print(f"链接: {result['url']}")
    print(f"摘要: {result['content']}")
    print("---")
```

### 高级搜索（带 AI 摘要）
```python
response = tavily.search(
    query="AI 最新新闻",
    search_depth="advanced",
    max_results=5,
    include_answer=True,
    time_range="week"
)

print(response.get("answer"))  # AI 生成的摘要
```

### 网页内容提取
```python
response = tavily.extract(
    urls="https://example.com",
    query="关于页面的关键信息"
)
```

---

## 注意事项

- API Key 需要从陈老师获取
- 搜索结果按相关性 score 排序
- advanced 搜索会返回更精准的结果，但耗时更长
- include_answer=True 时，Tavily 会生成 AI 摘要
