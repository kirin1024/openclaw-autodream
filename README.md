# 🌙 AutoDream for OpenClaw

**自动记忆维护 —— 让你的 AI Agent 真正"记住"你**

灵感来自 [Claude Code](https://claude.com) 的 Dream Machine 机制。受限子 Agent 每天凌晨自动分析所有 Agent 的对话，提取关键决策和偏好，生成变更提案等待你确认后执行。

> ✨ 从 11 步手动安装到 1 条命令，30 秒完成。

## 🎯 核心特性

| 特性 | 说明 |
|------|------|
| **4 阶段流程** | ORIENT → GATHER → CONSOLIDATE → PRUNE，借鉴自 [dream-skill](https://github.com/grandamenium/dream-skill) |
| **grep 模式匹配** | 7 类信号自动识别（用户纠正/偏好变更/重要决策/重复模式/配置变更/**外部资源**/**文件创建**），效率比全文读取高 10 倍 |
| **暂存区模式** | AutoDream 只写提案到 `pending-changes/`，主 Agent 审核后才执行，避免错误写入污染记忆 |
| **全 Agent 扫描** | 扫描所有 Agent 的 session（main、子 Agent 等），不只是主 Agent |
| **累积触发** | Heartbeat 检测对话轮数，达到阈值自动触发；凌晨 3:00 也强制触发 |
| **Dashboard 可视化** | 交互式 HTML 仪表板，5 维健康指标（新鲜度/覆盖度/连通度/效率/可达性） |
| **install.sh 一键安装** | 借鉴 [dream-skill](https://github.com/grandamenium/dream-skill) 的 install.sh 设计，30 秒完成 |
| **语义分析模式** | 新增 `semantic` 输出模式，输出完整对话原文给 auto-dream Agent，让 LLM 自行判断语义重要性，弥补 grep 关键词匹配的盲区；**semantic 每文件 100 行，其余模式 30 行** |

## 📦 快速安装

> install.sh 幂等，可重复运行。

### 从源码安装

```bash
# 克隆仓库到 skills 目录
git clone https://github.com/kirin1024/openclaw-autodream ~/.openclaw/workspace/skills/openclaw-autodream

# 运行安装脚本
bash ~/.openclaw/workspace/skills/openclaw-autodream/install.sh

# 重启 Gateway
openclaw gateway restart
```

install.sh 会自动完成：
1. 创建目录结构
2. 写入所有核心文件
3. 配置 `openclaw.json`（追加 auto-dream Agent）
4. 配置 macOS `launchd` 定时任务（每天 3:00）
5. 打印需要手动确认的 2 步

**幂等设计**：检测到已安装就跳过，可重复运行。

## 🔧 架构

```
┌──────────────────────────────────────────────────────┐
│  触发方式 A：每天凌晨 3:00（launchd 定时）           │
│  触发方式 B：Heartbeat 检测到累积轮数 ≥ 30          │
├──────────────────────────────────────────────────────┤
│  Phase 1: ORIENT — 读取 MEMORY.md + topic 文件       │
│  Phase 2: GATHER — grep 信号 + 语义分析 + 完整对话  │
│     ├─ 7 类信号：纠正/偏好/决策/重复/配置/资源/文件创建 │
│     ├─ semantic 模式：LLM 自主判断语义重要性（100行） │
│     ├─ 其他模式：每文件默认 30 行                    │
│     └─ 对话深度评分                                  │
│  Phase 3: CONSOLIDATE — 生成变更提案（暂存区）       │
│     ├─ 每条附带来源证据                              │
│     └─ 标注可信度 high/medium/low                    │
│  Phase 4: PRUNE — 标记过期/需要归档的条目            │
├──────────────────────────────────────────────────────┤
│  输出：                                              │
│  ├─ pending-changes/YYYY-MM-DD.md（待审核提案）      │
│  ├─ kairos-dream-YYYY-MM-DD.md（分析报告）           │
│  ├─ dream-state.json（状态更新）                     │
│  └─ dream-dashboard.html（可视化仪表板）             │
├──────────────────────────────────────────────────────┤
│  你下次发消息时：                                    │
│  主 Agent 检查 pending-changes → 展示摘要            │
│  → 你确认 → 执行 → 删除 pending 文件                │
└──────────────────────────────────────────────────────┘
```

## 🔔 待确认提醒机制

AutoDream 生成 `pending-changes/*.md` 后，**不会默认直接跨渠道主动发消息**。
它的提醒方式由安装阶段选择：

1. **手动触发完，当前终端立即提醒**
2. **每天定时触发完成后提醒**（macOS 本地通知）
3. **一旦生成 pending，本轮立即提醒**（终端 + 本地通知）
4. **下一次用户发消息时，主 Agent 先检查 pending 再提醒**（推荐）

> 推荐使用 **4**。它不依赖飞书，适用于 Web / Telegram / Discord / Signal 等所有主会话渠道。

如果选择 **4**，安装脚本会尝试自动为主 Agent 接入 `pending-changes` 检查逻辑；之后用户下一次发消息时，主 Agent 会优先展示待确认摘要。

### 多 Agent 记忆分发

AutoDream 支持跨 Agent 的记忆分发：扫描所有 Agent 的 session 后，根据来源 Agent 自动将变更提案分发到对应 workspace 的 `memory/pending-changes/` 目录。各 Agent 确认后写入自己的 memory 文件，互不干扰。

安装时自动为所有已存在的子 Agent workspace 创建 `MEMORY.md` 模板。

```
~/.openclaw/workspace/
├── skills/autodream/
│   ├── SKILL.md          # Skill 描述（中文）
│   ├── install.sh        # 一键安装脚本
│   ├── README.md         # 本文件
│   └── scripts/
├── scripts/
│   ├── parse-sessions.py      # 会话解析 v3（3 种输出模式）
│   ├── trigger-auto-dream.sh  # 4 阶段触发脚本
│   └── generate-dashboard.py  # Dashboard 生成器
├── memory/
│   ├── dream-state.json       # 触发状态
│   ├── dream-dashboard.html   # 仪表板
│   ├── pending-changes/       # 待处理变更
│   └── kairos-dream-*.md      # 分析报告
└── ~/.openclaw/workspace-auto-dream/
    ├── auto-dream-task.md     # 4 阶段任务指令
    └── memory/pending-changes/ # AutoDream 的暂存区
```

## 🆚 与开源项目的对比

### dream-skill

借鉴了以下设计：

| 特性 | dream-skill | AutoDream for OpenClaw |
|------|------------|------------------------|
| 触发方式 | Stop hook | launchd 定时 + Heartbeat 累积触发 |
| 流程 | 4 阶段 | ✅ 4 阶段（同） |
| grep 模式匹配 | ✅ 5 类信号 | ✅ 同（借鉴） |
| 暂存区模式 | ❌ 直接写 | ✅ 安全 |
| 多 Agent 支持 | ❌ 单项目 | ✅ 全 Agent 扫描 |
| Cron 过滤 | ❌ 无 | ✅ |
| 可视化 Dashboard | ❌ 无 | ✅ |
| 安装方式 | git clone + bash install.sh | install.sh 一键安装 |

### openclaw-auto-dream

借鉴了以下设计：

| 特性 | openclaw-auto-dream | AutoDream for OpenClaw |
|------|---------------------|------------------------|
| 记忆评分 | importance = base × recency × refs/8 | ✅ 修复了 recency 为负的 bug |
| 健康监控 | ✅ 5 维指标 | ✅ 借鉴（新鲜度/覆盖度/连通度/效率/可达性） |
| 暂存区模式 | ❌ 直接写入 | ✅ 安全 |
| 多 Agent 支持 | ❌ | ✅ |
| 梦日志 | ✅ dream-log.md | ✅ kairos-dream 报告 |
| 安装方式 | ClawHub 一行命令 | ✅ install.sh 一键安装 |

## ⚙️ 自定义

```bash
# 查看触发配置
cat ~/.openclaw/workspace/memory/dream-state.json

# 修改累积阈值（默认 30 轮）
# 修改 dream-state.json 中的 cumulative_threshold

# 修改触发时间（默认 3:00）
# 修改 ~/Library/LaunchAgents/com.openclaw.auto-dream.plist

# 修改扫描范围
# 编辑 parse-sessions.py 中的 EXCLUDE_AGENTS / SKIP_KEYWORDS

# 查看 Dashboard
open ~/.openclaw/workspace/memory/dream-dashboard.html
```

## 🔒 安全保证

- AutoDream **永远不能**执行命令、浏览网页或发送消息
- AutoDream **永远不能**直接更新 topic 文件（仅限暂存区）
- AutoDream 自己的 session **始终被排除**（防止自引用循环）
- cron/自动任务**始终被过滤**（减少噪音）
- 所有变更需要**主 Agent 审核 + 用户确认**后才执行
- 每条提案包含**来源证据**，便于验证
- 每条提案包含**可信度标注**，辅助判断
- **绝不记录敏感凭证**：密码、Token、API Key、SSH 私钥、公钥全文、Cookie、Session、Recovery Code、验证码、账号密保答案等，哪怕它们在对话中出现过

## Session Reset 兼容

OpenClaw 在 Session 上下文过大时会执行 Session Compaction，将旧会话保存为 `.jsonl.reset.{时间戳}` 文件。AutoDream 默认会扫描这些 reset 文件，防止信息丢失：

- **时间窗口**：仅扫描 reset 时间戳在 24 小时内的文件
- **数量上限**：每个 Agent 最多扫描最新的 20 个 reset 文件
- **深度**：每个 reset 文件读取最近 30 行

如果发现 AutoDream 遗漏了某些对话（比如凌晨讨论过但早上找不到），很可能是因为 Session 被 reset 了。reset 文件扫描功能会自动捕获这些备份。

```bash
# 检查状态
bash ~/.openclaw/workspace/scripts/trigger-auto-dream.sh --check-only

# 手动触发（测试）
bash ~/.openclaw/workspace/scripts/trigger-auto-dream.sh

# 查看 Dashboard
open ~/.openclaw/workspace/memory/dream-dashboard.html
```

## 📚 相关项目

- [Claude Code](https://github.com/anthropics/claude-code) — Dream Machine 原始灵感来源
- [dream-skill](https://github.com/grandamenium/dream-skill) — 4 阶段流程、grep 模式匹配、安装脚本设计
- [openclaw-auto-dream](https://github.com/LeoYeAI/openclaw-auto-dream) — 5 层记忆系统、健康评分、可视化仪表板
- [OpenClaw](https://github.com/openclaw/openclaw) — Agent 框架

## 📄 License

MIT-0

---

> 🌙 *Memory is a hint, not truth.*
