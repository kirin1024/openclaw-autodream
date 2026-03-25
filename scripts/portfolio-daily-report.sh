#!/bin/bash
# 持仓收盘价获取定时任务
# 调度大金主获取各持仓标的的收盘价，计算盈亏，推送报表

# 触发大金主执行
openclaw run --agent invest-advisor --task "
请执行以下任务：
1. 读取 ~/.openclaw/workspace/memory/portfolio.json 获取持仓列表
2. 查询以下市场的收盘价：
   - A股ETF（159934, 159819, 512890, 513010, 159941, 159770, 513010, 510050）
   - 港股（1810.HK, 9988.HK）
   - 美股（BABA, GLD, NVDA, SPY）
3. 计算每只标的的当日盈亏
4. 按分类汇总（A股ETF、港股、美股）
5. 生成报表发送到飞书给我

输出格式：
## 今日持仓报表
- A股ETF：总盈亏 XXX元
- 港股：总盈亏 XXX港币
- 美股：总盈亏 XXX美元
- 总计：XXX元（折算人民币）
"
