#!/usr/bin/env python3
"""
B站视频字幕获取脚本
思路：调用B站字幕API尝试获取字幕
"""
import requests
import json
import sys
import os

# B站需要一些headers
HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': 'https://www.bilibili.com',
    'Origin': 'https://www.bilibili.com',
}

def get_subtitles(avid_or_bvid, cookie=None):
    """获取B站视频字幕"""
    
    # 将BV号转换为AV号
    if avid_or_bvid.startswith('BV'):
        # 先获取视频信息
        info_url = f"https://api.bilibili.com/x/web-interface/view?bvid={avid_or_bvid}"
        resp = requests.get(info_url, headers=HEADERS)
        data = resp.json()
        if data.get('code') != 0:
            print(f"获取视频信息失败: {data.get('message')}")
            return None
        aid = data['data']['aid']
        cid = data['data']['cid']
        title = data['data']['title']
    else:
        aid = avid_or_bvid.lstrip('av')
        # 获取cid
        info_url = f"https://api.bilibili.com/x/web-interface/view?aid={aid}"
        resp = requests.get(info_url, headers=HEADERS)
        data = resp.json()
        if data.get('code') != 0:
            print(f"获取视频信息失败: {data.get('message')}")
            return None
        cid = data['data']['cid']
        title = data['data']['title']
    
    print(f"视频: {title}")
    print(f"AV号: {aid}, CID: {cid}")
    
    # 构建请求headers
    req_headers = HEADERS.copy()
    if cookie:
        req_headers['Cookie'] = cookie
    
    # 获取字幕列表
    subtitle_url = f"https://api.bilibili.com/x/v2/subtitle?aid={aid}&cid={cid}"
    print(f"\n请求字幕URL: {subtitle_url}")
    
    resp = requests.get(subtitle_url, headers=req_headers)
    print(f"响应状态: {resp.status_code}")
    print(f"响应内容: {resp.text[:500] if resp.text else 'empty'}")
    
    if not resp.text:
        print("API返回空响应，可能需要登录Cookie")
        return None
        
    data = resp.json()
    
    if data.get('code') != 0:
        print(f"获取字幕失败: {data.get('message')}")
        return None
    
    subtitles = data.get('data', {})
    if not subtitles:
        print("没有找到字幕文件（视频可能没有上传字幕）")
        return None
    
    print(f"\n找到字幕: {subtitles.keys()}")
    
    # 尝试下载字幕文件
    subtitle_list = subtitles.get('subtitles', [])
    if subtitle_list:
        for sub in subtitle_list:
            print(f"\n字幕语言: {sub.get('lan')}, 文件: {sub.get('link')}")
            if sub.get('link'):
                # 下载字幕
                sub_url = "https:" + sub['link'] if sub['link'].startswith('//') else sub['link']
                sub_resp = requests.get(sub_url, headers=HEADERS)
                if sub_resp.status_code == 200:
                    # 保存字幕文件
                    save_path = f"/Users/Alika/.openclaw/workspace/pingpong/subtitles/{aid}_{sub['lan']}.json"
                    os.makedirs(os.path.dirname(save_path), exist_ok=True)
                    with open(save_path, 'w') as f:
                        f.write(sub_resp.text)
                    print(f"字幕已保存到: {save_path}")
                    return save_path
    
    return None

if __name__ == "__main__":
    # 测试视频: BV1RvSYB3EG9
    bvid = sys.argv[1] if len(sys.argv) > 1 else "BV1RvSYB3EG9"
    cookie = sys.argv[2] if len(sys.argv) > 2 else None
    print(f"正在查询: {bvid}\n")
    get_subtitles(bvid, cookie)
