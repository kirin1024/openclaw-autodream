#!/usr/bin/env python3
"""
AI日报 - 新闻抓取模块
使用 Tavily 搜索 AI/科技新闻
"""

import os
import json
from datetime import datetime
from tavily import TavilyClient

def get_tavily_client():
    api_key = os.environ.get("TAVILY_API_KEY")
    if not api_key:
        raise ValueError("TAVILY_API_KEY not found in environment")
    return TavilyClient(api_key=api_key)

def fetch_ai_news(max_results=10):
    """抓取今日AI新闻"""
    client = get_tavily_client()
    
    queries = [
        "AI artificial intelligence latest news today 2025",
        "large language model GPT Claude Gemini latest",
        "AI startup funding investment news",
        "OpenAI Anthropic Google DeepMind latest",
    ]
    
    max_results_per_query = 5
    all_results = []
    seen_urls = set()
    
    for q in queries:
        try:
            response = client.search(
                query=q,
                search_depth="basic",
                time_range="day",
                max_results=max_results_per_query
            )
            for item in response.get("results", []):
                if item.get("url") not in seen_urls:
                    seen_urls.add(item.get("url"))
                    all_results.append({
                        "title": item.get("title", ""),
                        "content": item.get("content", "")[:300],
                        "url": item.get("url", ""),
                        "score": item.get("score", 0)
                    })
        except Exception as e:
            print(f"Search error for query '{q}': {e}")
    
    # 按分数排序，取前max_results条
    all_results.sort(key=lambda x: x.get("score", 0), reverse=True)
    return all_results[:max_results]

if __name__ == "__main__":
    news = fetch_ai_news()
    print(json.dumps(news, ensure_ascii=False, indent=2))
