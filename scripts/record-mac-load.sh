#!/bin/bash
# Mac 负载 + 温度 + 进程数据记录脚本

DATA_FILE="$HOME/.openclaw/workspace/memory/mac-load-history.json"
MAX_RECORDS=48

# 获取当前时间
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# 获取系统状态 - 使用 Python 更可靠地解析
SYSTEM_INFO=$(python3 << 'PYEOF'
import subprocess
import re
import os

# top 命令
top_result = subprocess.run(['top', '-l', '1', '-n', '5'], capture_output=True, text=True)
top_output = top_result.stdout

# 解析 Load Avg
load_avg = ""
for line in top_output.split('\n'):
    if 'Load Avg' in line:
        match = re.search(r'Load Avg: ([\d., ]+)', line)
        if match:
            load_avg = match.group(1).strip()
        break

# 解析 CPU usage
cpu_idle = ""
for line in top_output.split('\n'):
    if 'CPU usage' in line:
        # 格式: "CPU usage: 3.23% user, 2.12% sys, 94.64% idle"
        match = re.search(r'([\d.]+)%\s+idle', line)
        if match:
            cpu_idle = match.group(1)
        break

# 解析内存 - PhysMem: 9126M used (...), 2389M wired
mem_used_gb = ""
mem_wired_mb = ""
for line in top_output.split('\n'):
    if 'PhysMem' in line:
        # 格式: "PhysMem: 9126M used (...), 2389M wired"
        # 或: "PhysMem: 12.50G used (...), 2389M wired"
        match = re.search(r'PhysMem:\s+([\d.]+)([GM])\s+used', line)
        if match:
            val = float(match.group(1))
            unit = match.group(2)
            if unit == 'G':
                mem_used_gb = str(round(val, 1))
            else:  # M
                mem_used_gb = str(round(val / 1024, 1))
        # wired memory  
        match2 = re.search(r'([\d]+)M\s+wired', line)
        if match2:
            mem_wired_mb = match2.group(1)
        break

print(f"{load_avg}|{cpu_idle}|{mem_used_gb}|{mem_wired_mb}")
PYEOF
)

LOAD_AVG=$(echo "$SYSTEM_INFO" | cut -d'|' -f1)
CPU_IDLE=$(echo "$SYSTEM_INFO" | cut -d'|' -f2)
MEM_USED=$(echo "$SYSTEM_INFO" | cut -d'|' -f3)
MEM_TOTAL=$(echo "$SYSTEM_INFO" | cut -d'|' -f4)

# 获取温度（CPU/环境温度）
CPU_TEMP=$(osx-cpu-temp -T -c 2>/dev/null | tr -d ' ')
AMBIENT_TEMP=$(osx-cpu-temp -T -a 2>/dev/null | tr -d ' ')

# 获取 top 10 高占用进程
TOP_PROCESSES=$(python3 << 'PYEOF'
import subprocess
import re

result = subprocess.run(['top', '-l', '1', '-n', '10', '-o', 'cpu'], capture_output=True, text=True)
lines = result.stdout.split('\n')

processes = []
for line in lines[12:]:
    if re.match(r'^\s*\d+', line):
        parts = line.split()
        if len(parts) >= 3:
            pid = parts[0]
            cpu = parts[2].replace('%', '').replace('.', '', 1)
            cmd = parts[1][:20]
            try:
                cpu_val = float(cpu)
                processes.append(f"{cmd}({cpu_val:.1f}%)")
            except:
                pass
    if len(processes) >= 10:
        break

print('|'.join(processes))
PYEOF
)

# 构建新记录
NEW_RECORD="{\"timestamp\":\"$TIMESTAMP\",\"load_avg\":\"$LOAD_AVG\",\"cpu_idle\":\"$CPU_IDLE\",\"mem_used_gb\":\"$MEM_USED\",\"mem_wired_mb\":\"$MEM_TOTAL\",\"cpu_temp\":\"$CPU_TEMP\",\"ambient_temp\":\"$AMBIENT_TEMP\",\"top_processes\":\"$TOP_PROCESSES\"}"

# 读取现有数据（JSONL 格式）
if [ ! -f "$DATA_FILE" ]; then
    touch "$DATA_FILE"
fi

# 读取现有记录并转换格式
RECORDS=$(python3 -c "
import sys, json

records = []
try:
    with open('$DATA_FILE', 'r') as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    records.append(json.loads(line))
                except:
                    pass
except:
    pass

# 保留最近 MAX_RECORDS 条
if len(records) >= $MAX_RECORDS:
    records = records[-(($MAX_RECORDS-1)):]

# 添加新记录
records.append(json.loads('''$NEW_RECORD'''))

# 输出 JSONL 格式
for r in records:
    print(json.dumps(r, ensure_ascii=False))
")

echo "$RECORDS" > "$DATA_FILE"

echo "记录完成: $TIMESTAMP"
