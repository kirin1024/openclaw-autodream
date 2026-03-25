#!/usr/bin/env python3
"""
scrapling 静态页面抓取工具
使用 lxml 高效解析
"""

import sys
import json
import argparse
from pathlib import Path

# 虚拟环境路径
VENV_PATH = Path.home() / ".scrapling-venv"
VENV_PYTHON = VENV_PATH / "bin" / "python"

def get_python():
    """获取可用的 Python"""
    if VENV_PATH.exists():
        return str(VENV_PYTHON)
    return "python3"

def check_installed():
    """检查是否已安装 scrapling"""
    import subprocess
    python = get_python()
    result = subprocess.run(
        [python, "-c", "import scrapling"],
        capture_output=True
    )
    return result.returncode == 0


def fetch_page(url: str, selector: str = None):
    """
    抓取页面并解析（使用 lxml）
    """
    python = get_python()

    if selector:
        script = f'''
import scrapling
from scrapling import FroFetcher

# 使用 FroFetcher（静态 HTML 解析）
fetcher = FroFetcher(target="{url}")
response = fetcher.fetch()

# 使用 CSS 选择器提取
data = response.css("{selector}")
result = [item.text for item in data]

print("---RESULT---")
import json
print(json.dumps(result, ensure_ascii=False))
'''
    else:
        script = f'''
import scrapling
from scrapling import FroFetcher

# 使用 FroFetcher（静态 HTML 解析）
fetcher = FroFetcher(target="{url}")
response = fetcher.fetch()

# 获取页面标题和主要文本
title = response.get_title()
text = response.get_text()[:5000]  # 限制长度

result = {{
    "title": title,
    "text": text[:2000]
}}

print("---RESULT---")
import json
print(json.dumps(result, ensure_ascii=False))
'''

    # 检查是否安装
    if not check_installed():
        print("❌ scrapling 未安装，请先运行 install.py")
        return None

    import subprocess
    result = subprocess.run(
        [python, "-c", script],
        capture_output=True,
        text=True,
        timeout=30
    )

    if result.returncode != 0:
        print(f"❌ 抓取失败: {result.stderr}")
        return None

    # 解析输出
    output = result.stdout
    if "---RESULT---" in output:
        json_str = output.split("---RESULT---")[1].strip()
        try:
            return json.loads(json_str)
        except:
            return json_str
    return output


def fetch_simple(url: str):
    """
    简单抓取（使用 requests + lxml）
    """
    python = get_python()

    script = f'''
import requests
from lxml import html

# 获取页面（跳过 SSL 验证）
response = requests.get("{url}", timeout=10, verify=False)
response.encoding = 'utf-8'

# 解析 HTML
tree = html.fromstring(response.text)

# 提取标题
title = tree.xpath('//title/text()')

# 提取所有链接
links = tree.xpath('//a/@href')

# 提取主要文本 (去除脚本和样式)
for script in tree.xpath('//script | //style'):
    script.getparent().remove(script)

body_text = tree.xpath('//body//text()')
clean_text = '\\n'.join([t.strip() for t in body_text if t.strip()])[:3000]

result = {{
    "url": "{url}",
    "title": title[0] if title else "",
    "links_count": len(links),
    "sample_links": links[:10],
    "text_preview": clean_text[:2000]
}}

print("---RESULT---")
import json
print(json.dumps(result, ensure_ascii=False))
'''

    import subprocess
    result = subprocess.run(
        [python, "-c", script],
        capture_output=True,
        text=True,
        timeout=30
    )

    if result.returncode != 0:
        print(f"❌ 抓取失败: {result.stderr}")
        return None

    output = result.stdout
    if "---RESULT---" in output:
        json_str = output.split("---RESULT---")[1].strip()
        try:
            return json.loads(json_str)
        except:
            return json_str
    return output


def main():
    parser = argparse.ArgumentParser(description="scrapling 静态页面抓取工具")
    parser.add_argument("url", help="目标 URL")
    parser.add_argument("-s", "--selector", help="CSS 选择器")

    args = parser.parse_args()

    print(f"🔄 正在抓取: {args.url}")

    if args.selector:
        result = fetch_page(args.url, args.selector)
    else:
        # 默认使用简单方式
        result = fetch_simple(args.url)

    if result:
        print("\n✅ 抓取成功!")
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
