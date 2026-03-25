#!/usr/bin/env python3
"""
AI日报 - 播报生成模块
将新闻、金句、案例组装成最终格式
"""

import os
import json
import sys
from datetime import datetime

# 添加父目录到路径，以便导入其他脚本
sys.path.insert(0, os.path.dirname(__file__))

from fetch_news import fetch_ai_news
from fetch_quotes import fetch_all_quotes
from fetch_cases import fetch_global_cases, fetch_china_cases

WEEKDAYS = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]

def format_report(news, quotes, global_cases, china_cases):
    """组装完整日报"""
    now = datetime.now()
    date_str = now.strftime("%Y年%-m月%-d日")
    weekday = WEEKDAYS[now.weekday()]
    
    report = f"""🚀 AI杠杆玩家早报 | {date_str} {weekday}

一、AI极简资讯（今日{len(news)}大风向）

"""
    # 新闻
    for i, item in enumerate(news, 1):
        title = item.get("title", "").strip()
        content = item.get("content", "").strip()
        url = item.get("url", "")
        report += f"{i}. {title} ⭐⭐⭐⭐⭐\n{content}\n({url})\n\n---\n\n"
    
    # 金句
    report += "二、塔尖人物金句\n\n"
    if quotes:
        for q in quotes:
            name = q.get("name", "")
            title = q.get("title", "")
            quote = q.get("quote", "").strip()
            url = q.get("url", "")
            report += f"• {name}（{title}）：\n"
            if quote:
                report += f'"{quote}"\n'
                if url:
                    report += f"来源：{url}\n"
            report += "\n"
    else:
        report += "今日暂无重要金句更新。\n"
    
    report += "\n---\n\n三、全球搞钱前哨 🌍\n\n"
    
    if global_cases:
        for i, case in enumerate(global_cases, 1):
            title = case.get("title", "").strip()
            content = case.get("content", "").strip()
            url = case.get("url", "")
            report += f"案例{i}：{title}\n{content}\n◦ 链接：{url}\n\n---\n\n"
    else:
        report += "本周暂无新案例。\n"
    
    report += "\n四、中国大陆搞钱实操 🇨🇳\n\n"
    
    if china_cases:
        for i, case in enumerate(china_cases, 1):
            title = case.get("title", "").strip()
            content = case.get("content", "").strip()
            url = case.get("url", "")
            report += f"{i}. {title}\n{content}\n◦ 链接：{url}\n\n"
    else:
        report += "本周暂无新案例。\n"
    
    report += f"""
---
📮 来源：AI杠杆玩家早报 | 仅供内部参考
"""
    
    return report

def generate_daily_report():
    """生成完整日报"""
    print("正在抓取新闻...", file=sys.stderr)
    news = fetch_ai_news(max_results=10)
    
    print("正在抓取金句...", file=sys.stderr)
    quotes = fetch_all_quotes(max_people=12)
    
    print("正在抓取案例...", file=sys.stderr)
    global_cases = fetch_global_cases(max_results=3)
    china_cases = fetch_china_cases(max_results=3)
    
    print("正在生成报告...", file=sys.stderr)
    report = format_report(news, quotes, global_cases, china_cases)
    
    return report, {
        "news_count": len(news),
        "quotes_count": len(quotes),
        "global_cases_count": len(global_cases),
        "china_cases_count": len(china_cases)
    }

if __name__ == "__main__":
    report, stats = generate_daily_report()
    print("=== REPORT STATS ===")
    print(json.dumps(stats))
    print("=== REPORT CONTENT ===")
    print(report)
