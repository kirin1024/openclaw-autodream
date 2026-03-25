#!/usr/bin/env python3
"""
AI日报 - 案例抓取模块
抓取全球和中国AI创业/投资案例
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

def fetch_global_cases(max_results=3):
    """抓取全球AI创业案例"""
    client = get_tavily_client()
    
    queries = [
        "AI startup success story revenue 2025",
        "AI SaaS tool launched indiehackers",
        "artificial intelligence business profitable case",
    ]
    
    results = []
    seen_urls = set()
    
    for q in queries:
        try:
            response = client.search(
                query=q,
                search_depth="basic",
                time_range="week",
                max_results=max_results
            )
            for item in response.get("results", []):
                if item.get("url") not in seen_urls:
                    seen_urls.add(item.get("url"))
                    results.append({
                        "title": item.get("title", ""),
                        "content": item.get("content", "")[:300],
                        "url": item.get("url", "")
                    })
        except Exception as e:
            print(f"Error fetching global case '{q}': {e}")
    
    return results[:max_results]

def fetch_china_cases(max_results=3):
    """抓取中国大陆AI创业案例"""
    client = get_tavily_client()
    
    queries = [
        "中国AI创业 大模型 应用 2025",
        "AI工具出海 中国团队 产品",
        "国产大模型进展 Kimi ChatGLM 智谱",
    ]
    
    results = []
    seen_urls = set()
    
    for q in queries:
        try:
            response = client.search(
                query=q,
                search_depth="basic",
                time_range="week",
                max_results=max_results
            )
            for item in response.get("results", []):
                if item.get("url") not in seen_urls:
                    seen_urls.add(item.get("url"))
                    results.append({
                        "title": item.get("title", ""),
                        "content": item.get("content", "")[:300],
                        "url": item.get("url", "")
                    })
        except Exception as e:
            print(f"Error fetching China case '{q}': {e}")
    
    return results[:max_results]

if __name__ == "__main__":
    print("=== 全球案例 ===")
    global_cases = fetch_global_cases()
    print(json.dumps(global_cases, ensure_ascii=False, indent=2))
    
    print("\n=== 中国案例 ===")
    china_cases = fetch_china_cases()
    print(json.dumps(china_cases, ensure_ascii=False, indent=2))
