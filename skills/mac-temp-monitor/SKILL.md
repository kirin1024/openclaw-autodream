# SKILL.md - Mac 能耗与温度监控

## 功能
- 定时记录 Mac CPU 负载、内存、温度、进程信息
- 生成可视化能耗统计图表
- 提供完整的能耗分析报告

## 触发条件
- 用户说"看下 mac 负载"、"mac 能耗统计"、"Mac 耗电"

## 使用方式

### 1. 安装依赖
```bash
# 安装温度监控工具
cd /tmp
git clone https://github.com/lavoiesl/osx-cpu-temp.git
cd osx-cpu-temp
make
sudo make install

# 验证
osx-cpu-temp -T -c
# 输出: 53.5
```

### 2. 创建监控脚本
在 `~/.openclaw/workspace/scripts/` 下创建 `record-mac-load.sh`：

```bash
#!/bin/bash
# Mac 负载 + 温度 + 进程数据记录脚本

DATA_FILE="$HOME/.openclaw/workspace/memory/mac-load-history.json"
MAX_RECORDS=48

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

TOP_OUTPUT=$(top -l 1)
LOAD_AVG=$(echo "$TOP_OUTPUT" | grep "Load Avg" | sed 's/.*Load Avg: //' | xargs)
CPU_IDLE=$(echo "$TOP_OUTPUT" | grep "CPU usage" | awk '{print $NF}' | tr -d '%')
MEM_USED=$(echo "$TOP_OUTPUT" | grep "PhysMem" | awk '{print $1}' | tr -d 'G')
MEM_TOTAL=$(echo "$TOP_OUTPUT" | grep "PhysMem" | sed 's/.*(\([^)]*\) wired.*/\1/' | tr -d 'M')

# 温度
CPU_TEMP=$(osx-cpu-temp -T -c 2>/dev/null | tr -d ' ')
AMBIENT_TEMP=$(osx-cpu-temp -T -a 2>/dev/null | tr -d ' ')

# Top 10 进程
TOP_PROCESSES=$(python3 << 'PYEOF'
import subprocess
result = subprocess.run(['top', '-l', '1', '-n', '10', '-o', 'cpu'], capture_output=True, text=True)
lines = result.stdout.split('\n')
processes = []
for line in lines[12:]:
    if line.strip() and line.strip()[0].isdigit():
        parts = line.split()
        if len(parts) >= 3:
            cmd = parts[1][:20]
            cpu = parts[2].replace('%', '')
            try:
                processes.append(f"{cmd}({float(cpu):.1f}%)")
            except:
                pass
        if len(processes) >= 10:
            break
print('|'.join(processes))
PYEOF
)

NEW_RECORD="{\"timestamp\":\"$TIMESTAMP\",\"load_avg\":\"$LOAD_AVG\",\"cpu_idle\":\"$CPU_IDLE\",\"mem_used_gb\":\"$MEM_USED\",\"mem_wired_mb\":\"$MEM_TOTAL\",\"cpu_temp\":\"$CPU_TEMP\",\"ambient_temp\":\"$AMBIENT_TEMP\",\"top_processes\":\"$TOP_PROCESSES\"}"

if [ ! -f "$DATA_FILE" ]; then
    echo "[]" > "$DATA_FILE"
fi

EXISTING=$(cat "$DATA_FILE")
if [ "$EXISTING" = "[]" ] || [ -z "$EXISTING" ]; then
    echo "[$NEW_RECORD]" > "$DATA_FILE"
else
    COUNT=$(echo "$EXISTING" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
    if [ "$COUNT" -ge "$MAX_RECORDS" ]; then
        echo "$EXISTING" | python3 -c "
import sys, json
data = json.load(sys.stdin)
data.pop(0)
data.append(json.loads('''$NEW_RECORD'''))
print(json.dumps(data, ensure_ascii=False))
" > "$DATA_FILE"
    else
        echo "$EXISTING" | python3 -c "
import sys, json
data = json.load(sys.stdin)
data.append(json.loads('''$NEW_RECORD'''))
print(json.dumps(data, ensure_ascii=False))
" > "$DATA_FILE"
    fi
fi

echo "记录完成: $TIMESTAMP"
```

```bash
chmod +x ~/.openclaw/workspace/scripts/record-mac-load.sh
```

### 3. 配置定时任务（可选）
每小时自动记录：
```bash
crontab -e
# 添加: 0 * * * * /Users/Alika/.openclaw/workspace/scripts/record-mac-load.sh
```

## 能耗查询输出格式

### 图表要求（5行，每行一张图）
1. CPU 负载 (Load Average)
2. 内存使用 (Wired GB)
3. CPU 温度 (°C)
4. 实时功耗 (W)
5. 累积耗电 (度)

### 文案总结要求
必须包括：
1. **过去24小时耗电**（从当前时间往前算24小时）
2. **CPU温度与能耗**（平均温度、平均功耗）
3. **整体运行情况**（平均负载、是否正常）
4. **高负载时间段**（列出具体时间段+负载+温度）
5. **高负载原因**（根据 top_processes 数据准确判断，不要模棱两可）

### 功耗估算参考（MacBook Pro 13" Intel）
| 状态 | CPU Load | 功耗 |
|------|----------|------|
| 空闲 | < 1 | 5-10W |
| 轻度 | 1-2 | 10-20W |
| 中度 | 2-3 | 20-35W |
| 重度 | > 3 | 35-50W |

### 温度参考
| 状态 | 温度 |
|------|------|
| 空闲 | 40-50°C |
| 轻度负载 | 50-65°C |
| 中度负载 | 65-80°C |
| 重度负载 | 80-95°C |

## 数据文件
- 位置：`~/.openclaw/workspace/memory/mac-load-history.json`
- 保留：最近 48 条（48小时）
- 字段：timestamp, load_avg, cpu_idle, mem_used_gb, mem_wired_mb, cpu_temp, ambient_temp, top_processes

## 示例输出
```
📊 Mac 能耗统计（03-13 11:01 → 03-14 11:01）

1. 过去24小时耗电：1.06 度

2. CPU温度与能耗
- 平均CPU温度：64.7°C
- 平均功耗：42.5 W（满载状态）

3. 整体运行情况
- 平均负载：10.76（偏高）
- 70% 时间处于高负载状态

4. 高负载时间段
- 03-13 20:00: Load=15.1, Temp=66.3°C
- 03-14 08:00: Load=18.1, Temp=72.6°C (峰值)

5. 高负载原因
- 下午时段：IDEA 编译、大型项目构建
- 早上峰值：多个项目同时编译 + 开发工具启动
```
