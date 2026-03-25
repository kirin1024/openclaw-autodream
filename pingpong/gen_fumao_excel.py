#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pandas as pd

# 从Jira页面提取的数据
# 过滤器: 福贸_26.0316 (filter=14747)
# JQL: project = FLOWMORE AND 期望上线版本 = 26.0316

data = [
    {
        "需求类型（优先级）": "P0",
        "需求标题": "福贸注册流程接入制裁IP拦截",
        "跟进人": "陈燕",
        "状态": "",
        "测试安排": "",
        "本期占用估时(d)": "",
        "发布版本": "26.0316",
        "开发版本": "26.0316",
        "备注": "http://jira.pingpongx.com/browse/FLOWMORE-13262"
    },
    {
        "需求类型（优先级）": "P1",
        "需求标题": "【网商跨境通 -1688 直采】增加开户主体类型",
        "跟进人": "周腾",
        "状态": "",
        "测试安排": "",
        "本期占用估时(d)": "1",
        "发布版本": "26.0316",
        "开发版本": "26.0316",
        "备注": "http://jira.pingpongx.com/browse/FLOWMORE-13258"
    },
]

# 筛选规则：剔除跟进人为"无需前端"和"需求待定"的行，只保留有具体人名的需求
filtered_data = [row for row in data if row["跟进人"] and row["跟进人"] not in ["无需前端", "需求待定"]]

print(f"筛选前进度: {len(data)} 条")
print(f"筛选后进度: {len(filtered_data)} 条")

# 按跟进人名字排序
filtered_data.sort(key=lambda x: x["跟进人"])

# 创建DataFrame
df = pd.DataFrame(filtered_data)

# 输出路径
output_path = "/Users/chenyan/.openclaw/workspace/pingpong/福贸需求清单_26.0316.xlsx"

# 保存为Excel
df.to_excel(output_path, index=False, engine='openpyxl')

print(f"已生成Excel: {output_path}")
print(f"共 {len(filtered_data)} 条需求")

# 按跟进人统计
from collections import Counter
counter = Counter([row["跟进人"] for row in filtered_data])
print("\n按跟进人分组统计:")
for name, count in counter.items():
    print(f"  {name}: {count} 条")
