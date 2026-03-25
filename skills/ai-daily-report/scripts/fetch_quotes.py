#!/usr/bin/env python3
"""
AI日报 - 金句抓取模块 v5 (final)
基于 Nitter RSS 方案，参考 Chen 的"纯RSS + 多实例Fallback"架构
- 多Nitter实例自动切换
- DNS污染环境下使用DoH备用解析
- 1.5秒请求间隔，零封号风险
"""

import os
import sys
import json
import random
import time
import ssl
import socket
import re
import gzip
import urllib.request
import urllib.error
import xml.etree.ElementTree as ET
from datetime import datetime

# ============================================================
# Nitter 实例列表（按稳定性排序）
# ============================================================
NITTER_INSTANCES = [
    "nitter.net",                    # 优先使用
    "nitter.privacydev.net",         # 备用1
    "nitter.poast.org",              # 备用2
    "nitter.sethforprivacy.com",     # 备用3
    "nitter.kavin.rocks",            # 备用4
]

# ============================================================
# DNS-over-HTTPS 解析（应对DNS污染）
# ============================================================
def resolve_hostname_doh(hostname):
    """
    使用 Google DoH 解析真实IP，绕过DNS污染
    仅在直接DNS解析失败时调用
    """
    doh_url = f"https://dns.google/resolve?name={hostname}&type=A"
    try:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        
        req = urllib.request.Request(doh_url, headers={
            'Accept': 'application/dns-json',
            'User-Agent': 'Mozilla/5.0'
        })
        with urllib.request.urlopen(req, timeout=8, context=ctx) as resp:
            data = json.loads(resp.read().decode())
            answers = data.get('Answer', [])
            for a in answers:
                if a['type'] == 1:  # A record
                    return a['data']
    except Exception:
        pass
    return None

# ============================================================
# 带SNI的HTTPS请求（应对IP直连SSL失败）
# ============================================================
def fetch_url_with_sni(url, host, ip=None, timeout=10):
    """
    使用指定IP+原始Host头访问，配合SSL SNI
    处理DNS污染情况
    """
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    
    if ip:
        # 直接连接IP，设置Server Host Name
        sock = socket.create_connection((ip, 443), timeout=timeout)
        ssock = ctx.wrap_socket(sock, server_hostname=host)
    else:
        # 标准方式
        req = urllib.request.Request(url, headers={
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
            'Accept-Encoding': 'gzip, deflate',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        })
        with urllib.request.urlopen(req, timeout=timeout, context=ctx) as response:
            content = response.read()
            if response.headers.get('Content-Encoding') == 'gzip':
                content = gzip.decompress(content)
            return content.decode('utf-8', errors='replace')
    
    # IP直连方式
    try:
        req = urllib.request.Request(url, headers={
            'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
            'Host': host,
            'Accept-Encoding': 'gzip, deflate',
        })
        with urllib.request.urlopen(req, timeout=timeout, context=ctx) as response:
            content = response.read()
            if response.headers.get('Content-Encoding') == 'gzip':
                content = gzip.decompress(content)
            return content.decode('utf-8', errors='replace')
    except Exception:
        return None

# ============================================================
# RSS 解析
# ============================================================
def fetch_rss(instance, username, use_doh=False):
    """
    从指定Nitter实例获取用户最新RSS
    返回: (成功bool, tweets列表, 使用的IP或None, 错误信息)
    """
    url = f"https://{instance}/{username}/rss"
    headers = {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
    }
    
    resolved_ip = None
    
    try:
        # 先尝试标准DNS解析
        ip = socket.gethostbyname(instance)
        if ip == "0.0.0.0" or ip.startswith("127."):
            # DNS污染，使用DoH
            if use_doh:
                ip = resolve_hostname_doh(instance)
                if ip:
                    resolved_ip = ip
                    url_for_ip = f"https://{ip}/{username}/rss"
                else:
                    return False, [], None, "DoH解析失败"
            else:
                return False, [], None, "DNS污染"
        
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        
        req = urllib.request.Request(url, headers=headers)
        with urllib.request.urlopen(req, timeout=10, context=ctx) as response:
            content = response.read()
            if response.headers.get('Content-Encoding') == 'gzip':
                content = gzip.decompress(content)
            text = content.decode('utf-8', errors='replace')
            
            return parse_rss(text, username)
    
    except ssl.SSLError as e:
        # SSL错误，尝试DoH解析+IP直连
        if use_doh and not resolved_ip:
            resolved_ip = resolve_hostname_doh(instance)
            if resolved_ip:
                content = fetch_url_with_sni(f"https://{instance}/{username}/rss", instance, resolved_ip)
                if content:
                    return parse_rss(content, username)
        return False, [], None, f"SSL错误: {e}"
    
    except Exception as e:
        err_str = str(e)
        # 检查是否是DNS污染
        if "0.0.0.0" in str(e) or "name or service not known" in str(e):
            return False, [], None, "DNS污染"
        return False, [], None, err_str

def parse_rss(text, username):
    """解析RSS XML，提取推文"""
    try:
        root = ET.fromstring(text)
        channel = root.find('channel')
        if channel is None:
            return False, [], None, "无效RSS"
        
        tweets = []
        items = channel.findall('item')
        for item in items[:5]:
            title = item.findtext('title', '').strip()
            link = item.findtext('link', '').strip()
            pub_date = item.findtext('pubDate', '').strip()
            
            # 清理title中的 "username: " 前缀
            prefix1 = f"@{username}: "
            prefix2 = f"{username}: "
            for prefix in [prefix1, prefix2]:
                if title.startswith(prefix):
                    title = title[len(prefix):]
            
            if title:
                tweets.append({
                    "text": title,
                    "link": link,
                    "pub_date": pub_date
                })
        
        return True, tweets, None, ""
    except ET.ParseError as e:
        return False, [], None, f"XML解析错误: {e}"

# ============================================================
# 用户名映射
# ============================================================
def extract_username(platform_id):
    """从 platform_id 提取 X 用户名"""
    username = platform_id.lstrip('@')
    mapping = {
        "ylecun": "ylecun",
        "sama": "sama",
        "elonmusk": "elonmusk",
        "karpathy": "karpathy",
        "DrJimFan": "DrJimFan",
        "simonw": "simonw",
        "pmarca": "pmarca",
        "ilyasut": "ilyasut",
        "ylecun": "ylecun",
        "dpkingma": "dpkingma",
        "goodside": "goodside",
        "percyliang": "percyliang",
        "john_schulman": "johnschulman",
        "jeffdean": "jeffdean",
        "oriolvinyals": "oriolvinyals",
        "demishassabis": "demishassabis",
        "darioamodei": "darioamodei",
        "chipro": "chipro",
        "thomwolf": "thomwolf",
    }
    return mapping.get(username, username)

# ============================================================
# 核心抓取函数
# ============================================================
def fetch_tweets_for_user(username, max_tweets=3, use_doh=True):
    """
    尝试所有Nitter实例，自动切换
    use_doh: 是否使用DNS-over-HTTPS（应对DNS污染环境）
    """
    random.shuffle(NITTER_INSTANCES)
    
    for instance in NITTER_INSTANCES:
        success, tweets, ip, err = fetch_rss(instance, username, use_doh=use_doh)
        if success and tweets:
            return tweets[:max_tweets], instance, ip
        # 不打印失败，避免刷屏
        time.sleep(1.5)
    
    return [], None, None

def is_recent(pub_date_str, days=2):
    """判断推文是否在最近days天内"""
    if not pub_date_str:
        return True
    try:
        from email.utils import parsedate_to_datetime
        dt = parsedate_to_datetime(pub_date_str)
        now = datetime.now(dt.tzinfo)
        delta = now - dt
        return delta.days < days
    except:
        return True

# ============================================================
# 主入口
# ============================================================
def fetch_all_quotes(max_people=15, use_doh=True):
    """
    抓取所有leader的最新推文
    use_doh: 在DNS污染环境下设为True（本地Mac测试用）
    """
    config_path = os.path.join(os.path.dirname(__file__), "../config/leaders.json")
    with open(config_path, "r", encoding="utf-8") as f:
        leaders = json.load(f)
    
    today_str = datetime.now().strftime("%Y-%m-%d")
    random.seed(f"{today_str}-{len(leaders)}-v5")
    
    # 优先 tier 2（AI Builder）和 tier 3（实战派）
    priority = [l for l in leaders if l.get("tier") in [2, 3]]
    other = [l for l in leaders if l.get("tier") not in [2, 3]]
    random.shuffle(priority)
    random.shuffle(other)
    
    selected = priority[:max_people]
    if len(selected) < max_people:
        selected.extend(other[:max_people - len(selected)])
    
    quotes_output = []
    
    for leader in selected:
        name = leader["name"]
        platform_id = leader.get("platform_id", "")
        username = extract_username(platform_id)
        
        if not username:
            continue
        
        tweets, instance, used_ip = fetch_tweets_for_user(username, max_tweets=3, use_doh=use_doh)
        
        # 过滤最近2天内的推文
        recent = [t for t in tweets if is_recent(t.get("pub_date", ""), days=2)]
        
        if recent:
            quotes_output.append({
                "name": name,
                "title": leader.get("domain", ""),
                "platform_id": platform_id,
                "quote": recent[0]["text"],
                "link": recent[0]["link"],
                "instance": instance,
                "used_ip": used_ip,
            })
        
        time.sleep(1.5)  # 1.5秒间隔
    
    return quotes_output

if __name__ == "__main__":
    # 测试：打印所有能抓到的推文
    quotes = fetch_all_quotes(max_people=10, use_doh=True)
    print(f"Got quotes from {len(quotes)} people:\n")
    for q in quotes:
        print(f"• {q['name']}（{q['title']}）:")
        print(f'  "{q["quote"]}"')
        print(f"  via: {q['instance']} | {q['link']}")
        print()
