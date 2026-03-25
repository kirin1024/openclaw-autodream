scrapling-tool - scrapling 集成工具
触发条件
当用户需要抓取静态网页、进行反检测爬取、或使用 AI 智能解析页面时使用。
功能描述
集成 Python scrapling 库，提供：
1. 静态页面抓取 \- 使用 lxml 高效解析
2. 反检测能力 \- 内置指纹定制，降低被反爬拦截
3. AI 智能解析 \- LLM 自动分析页面结构并提取目标信息
文件结构
```PLAINTEXT
scrapling-tool/
├── SKILL.md      # 本文档
├── install.py    # 安装脚本（检测/安装 scrapling）
└── fetch.py      # 抓取工具脚本
```
快速开始
第1步：安装 scrapling
```PLAINTEXT
python3 ~/.openclaw/workspace/skills/scrapling-tool/install.py
```
脚本会自动：
\- 检测是否已安装
\- 如未安装，创建虚拟环境（推荐）或全局安装
\- 安装 scrapling\[fetchers,ai\]
\- 验证安装成功
第2步：使用抓取功能
方式1：普通抓取
```PLAINTEXT
# 使用虚拟环境中的 Python
~/.scrapling-venv/bin/python ~/.openclaw/workspace/skills/scrapling-tool/fetch.py <URL>
```
方式2：带 CSS 选择器
```PLAINTEXT
~/.scrapling-venv/bin/python ~/.openclaw/workspace/skills/scrapling-tool/fetch.py <URL> -s ".product-title"
```
方式3：AI 智能解析
```PLAINTEXT
~/.scrapling-venv/bin/python ~/.openclaw/workspace/skills/scrapling-tool/fetch.py <URL> --ai "提取所有产品价格"
```
使用示例
示例1：抓取基金净值（静态页面）
```PLAINTEXT
~/.scrapling-venv/bin/python ~/.openclaw/workspace/skills/scrapling-tool/fetch.py \
    "https://fund.eastmoney.com/161226.html"
```
示例2：提取特定内容
```PLAINTEXT
# 提取页面标题
~/.scrapling-venv/bin/python ~/.openclaw/workspace/skills/scrapling-tool/fetch.py \
    "https://example.com" \
    -s "h1"
```
示例3：AI 解析页面
```PLAINTEXT
# 提取页面所有链接
~/.scrapling-venv/bin/python ~/.openclaw/workspace/skills/scrapling-tool/fetch.py \
    "https://example.com" \
    --ai "提取页面所有链接"
```
技术原理
scrapling 核心优势
能力
说明
lxml 解析
高性能 HTML/XML 解析，比正则快 10 倍\+
反检测
内置指纹随机化，降低被识别为爬虫
AI 解析
基于 LLM 自动理解页面结构
Playwright
底层使用 Playwright，支持 JS 渲染
与 OpenClaw 现有工具对比
工具
适用场景
速度
反检测
web\_fetch
简单静态页面
快
弱
scrapling
静态页面 \+ 反检测
快
中等
browser
动态页面/登录
慢
弱
在 Agent 对话中使用
在 Agent 任务中可以这样调用：
```PLAINTEXT
# 检测并安装（首次使用）
exec(command="python3 ~/.openclaw/workspace/skills/scrapling-tool/install.py")

# 抓取页面
exec(command="~/.scrapling-venv/bin/python ~/.openclaw/workspace/skills/scrapling-tool/fetch.py 'https://fund.eastmoney.com/161226.html'")
```
注意事项
1. 首次使用需安装 \- [install.py](http://install.py/) 会创建虚拟环境 \~/.scrapling\-venv
2. AI 功能需要 API \- 首次使用可能需要配置 LLM API
3. 反检测不是万能 \- 过于频繁仍可能被封，建议遵守 robots.txt
4. 动态页面 \- 需要 JS 渲染的页面仍建议用 browser 工具
故障排查
安装失败
\- 检查 Python 版本（需 3.8\+）
\- 检查网络连接
\- 尝试手动安装：pip3 install scrapling\[fetchers,ai\]
抓取失败
\- 检查 URL 是否正确
\- 检查目标网站是否可访问
\- 尝试增加超时时间
AI 解析失败
\- 检查是否安装了 ai 扩展
\- 检查 LLM API 配置
\- 尝试简化需求描述
