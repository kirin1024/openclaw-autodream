# SKILL.md - AI杠杆玩家早报

> 自动生成并发送「AI杠杆玩家早报」，包含AI新闻、塔尖人物金句、全球及中国AI创业案例

## 功能概述

每天自动抓取：
1. **AI极简资讯** - 10条当日AI/科技新闻（Tavily搜索）
2. **塔尖人物金句** - 从29人名单中筛选当日有发内容的人，最多15人
3. **全球搞钱前哨** - 国外AI创业/投资案例（indiehackers等）
4. **中国大陆实操** - 国内AI创业/投资案例

## 前置要求

- Python 3.10+
- `pip install tavily-python`
- 环境变量 `TAVILY_API_KEY` 已配置

## 工具链

- **Tavily Search** - 新闻搜索、金句搜索、案例搜索
- **Tavily Extract** - 深度抓取原文详情
- **飞书 message** - 发送播报到指定群

## 工作流程

```
每天触发（手动或cron）
  ↓
Step 1: fetch_news.py
  └─ Tavily搜索当日AI新闻 → 取前10条
  ↓
Step 2: fetch_quotes.py
  └─ 对leaders名单分组，当日有内容的提炼金句 → 最多15人
  ↓
Step 3: fetch_cases.py
  └─ Tavily搜索全球+中国案例 → 各3条
  ↓
Step 4: generate_report.py
  └─ 按template.md模板组装完整日报
  ↓
Step 5: 发送飞书群
  └─ message(action=send, channel=feishu, target=目标群)
```

## 使用方式

### 手动触发（测试）

```bash
cd ~/.openclaw/workspace/skills/ai-daily-report/scripts
source ~/openclaw/venv/bin/activate
python generate_report.py
```

### 查看生成结果

```bash
cd ~/.openclaw/workspace/skills/ai-daily-report/scripts
source ~/openclaw/venv/bin/activate
python -c "
from generate_report import generate_daily_report
report, stats = generate_daily_report()
print(report)
print('统计:', stats)
"
```

### Cron 定时发送（每天早8点）

在 OpenClaw 中配置 cron 任务：

```yaml
cron:
  - name: "AI杠杆玩家早报"
    when: "0 8 * * 1-5"  # 周一至周五早8点
    task: |
      cd ~/.openclaw/workspace/skills/ai-daily-report/scripts
      python generate_report.py
      # 输出自动发送至飞书群
```

## 配置文件

| 文件 | 说明 |
|------|------|
| `config/leaders.json` | 29人完整名单，包含tier/keywords/平台ID |
| `config/sources.json` | 新闻源和搜索Query配置 |
| `config/template.md` | 播报格式模板（emoji+结构） |

## 人物名单（29人）

### 第一梯队：Transformer奠基者
Ashish Vaswani, Noam Shazeer, Alec Radford, John Schulman, Percy Liang

### 第二梯队：AI公司研发核心
Ilya Sutskever, Andrej Karpathy, Durk Kingma, Lilian Weng, Jan Leike, Riley Goodside, Yi Wu, Jared Kaplan, Amanda Askell, Dario Amodei, Jeff Dean, Oriol Vinyals, Koray Kavukcuoglu, Demis Hassabis

### 第三梯队：实战派/VC/思想领袖
Yann LeCun, Thomas Silex, Soumith Chintala, Jim Fan, Simon Willison, Chip Huyen, Samuel Albanie, Marc Andreessen, Sam Altman, Elon Musk

## 输出示例

```
🚀 AI杠杆玩家早报 | 2026年3月21日 周六

一、AI极简资讯（今日10大风向）

1. OpenAI发布GPT-5.4：最强全能模型 ⭐⭐⭐⭐⭐
集成推理、编码、Agent能力... (https://...)

---

二、塔尖人物金句

• Ilya Sutskever（AI安全/AGI）：
"我们没有退缩是极好的..."
潜台词：AI安全派和商业派需要联手

---

三、全球搞钱前哨 🌍
...

四、中国大陆搞钱实操 🇨🇳
...

---
📮 来源：AI杠杆玩家早报 | 仅供内部参考
```

## 注意事项

- 金句搜索：每天随机选择当日有发内容的1-2人提取
- 新闻去重：按URL去重，避免重复
- 发送失败：记录日志，人工补偿
