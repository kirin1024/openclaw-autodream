# 🌙 AutoDream for OpenClaw

**Automatic Memory Maintenance — Let Your AI Agent Truly "Remember" You**

Inspired by the [Claude Code](https://claude.com) Dream Machine. A restricted sub-Agent automatically analyzes all Agent conversations every night, extracts key decisions and preferences, and generates change proposals for your approval.

> ✨ From 11 manual steps to 1 command — 30 seconds to install.

**[🇺🇸 English](#english)** | **[🇨🇳 中文](#中文)**

---

# 🇺🇸 English

## Core Features

| Feature | Description |
|---------|-------------|
| **4-Phase Pipeline** | ORIENT → GATHER → CONSOLIDATE → PRUNE, inspired by [dream-skill](https://github.com/grandamenium/dream-skill) |
| **Grep Pattern Matching** | 8 signal types auto-detected (user correction / preference change / important decision / repetition / config change / **external resources** / **file creation** / **important tasks**), 10x more efficient than full-text reading |
| **Staging Area** | AutoDream only writes proposals to `pending-changes/`. The main Agent executes after your approval — no accidental memory corruption |
| **Multi-Agent Scanning** | Scans all Agent sessions (main, sub-agents, etc.), not just the primary Agent |
| **Accumulative Trigger** | Heartbeat monitors conversation turns; auto-triggers when threshold is reached. Also force-triggers at 3:00 AM |
| **Dashboard Visualization** | Interactive HTML dashboard with 5 health dimensions (freshness / coverage / connectivity / efficiency / reachability); **multi-Agent view** — each Agent gets its own health score, card, and summary table |
| **One-Command Install** | Inspired by [dream-skill](https://github.com/grandamenium/dream-skill)'s install.sh — setup in 30 seconds |
| **Semantic Analysis Mode** | New `semantic` output mode sends raw conversation transcripts to the auto-dream Agent, letting the LLM judge semantic importance — filling the blind spots of grep keyword matching. **100 lines per file for semantic mode, 30 lines for others** |

## Quick Start

> install.sh is idempotent — safe to re-run.

```bash
# Clone to skills directory
git clone https://github.com/kirin1024/openclaw-autodream ~/.openclaw/workspace/skills/openclaw-autodream

# Run installer
bash ~/.openclaw/workspace/skills/openclaw-autodream/install.sh

# Restart Gateway
openclaw gateway restart
```

install.sh automatically:
1. Creates directory structure
2. Writes all core files
3. Configures `openclaw.json` (adds auto-dream Agent)
4. Configures macOS `launchd` scheduled task (daily at 3:00 AM)
5. Prints 2 steps that need manual confirmation

**Idempotent design**: detects existing installation and skips — safe to re-run.

## Architecture

```
┌──────────────────────────────────────────────────────┐
│  Trigger A: Daily at 3:00 AM (launchd)               │
│  Trigger B: Heartbeat detects cumulative turns ≥ 30  │
├──────────────────────────────────────────────────────┤
│  Phase 1: ORIENT — Read MEMORY.md + topic files      │
│  Phase 2: GATHER — grep signals + semantic + full    │
│     ├─ 8 signals: correction/pref/decision/          │
│     │   repetition/config/resources/file-creation/    │
│     │   important-tasks                               │
│     ├─ Semantic mode: LLM judges importance (100 ln) │
│     ├─ Other modes: 30 lines per file default        │
│     └─ Conversation depth scoring                    │
│  Phase 3: CONSOLIDATE — Generate proposals (staging) │
│     ├─ Each with source evidence                     │
│     └─ Confidence: high / medium / low               │
│  Phase 4: PRUNE — Mark expired entries for archive   │
├──────────────────────────────────────────────────────┤
│  Output:                                             │
│  ├─ pending-changes/YYYY-MM-DD.md (proposals)        │
│  ├─ kairos-dream-YYYY-MM-DD.md (analysis report)     │
│  ├─ dream-state.json (state tracking)                │
│  └─ dream-dashboard.html (visualization)             │
├──────────────────────────────────────────────────────┤
│  On your next message:                               │
│  Main Agent checks pending-changes → shows summary   │
│  → You confirm → Execute → Delete pending files      │
└──────────────────────────────────────────────────────┘
```

## Reminder Mechanism

After AutoDream generates `pending-changes/*.md`, it **does not proactively message you across channels**. The reminder strategy is chosen during installation:

1. **Immediate reminder in terminal** after manual trigger
2. **macOS local notification** after daily scheduled run
3. **Immediate terminal + notification** when pending is generated
4. **Check on next user message** — main Agent scans pending first (Recommended)

> **Option 4** is recommended. It works across all channels (Web / Telegram / Discord / Signal / Feishu) without dependency on any specific messaging platform.

If you choose **4**, the installer will auto-patch AGENTS.md with pending-changes check logic, including:
- **Session Start check**: Check pending on every new session
- **Every Turn check + date comparison**: On every message, compare current date with last check date (auto-trigger on new day)
- **last_pending_check_date**: Stored in dream-state.json, ensures cross-day sessions work correctly

### Cross-Day Session Support

AutoDream supports cross-Agent memory distribution: after scanning all Agent sessions, it automatically routes change proposals to each Agent's `memory/pending-changes/` directory based on the source. Each Agent confirms and writes to its own memory files independently.

The installer auto-creates `MEMORY.md` templates for all existing sub-Agent workspaces.

## Comparison with Open Source Projects

### dream-skill

| Feature | dream-skill | AutoDream for OpenClaw |
|---------|------------|------------------------|
| Trigger | Stop hook | launchd + Heartbeat accumulative |
| Pipeline | 4 phases | ✅ 4 phases (same) |
| Grep matching | ✅ 5 signals | ✅ (adapted, 8 types) |
| Staging mode | ❌ Direct write | ✅ Safe |
| Multi-Agent | ❌ Single project | ✅ All agents |
| Cron filtering | ❌ None | ✅ |
| Dashboard | ❌ None | ✅ |
| Installation | git clone + bash install.sh | install.sh one-click |

### openclaw-auto-dream

| Feature | openclaw-auto-dream | AutoDream for OpenClaw |
|---------|---------------------|------------------------|
| Memory scoring | importance = base × recency × refs/8 | ✅ Fixed negative recency bug |
| Health monitoring | ✅ 5 dimensions | ✅ (adapted) |
| Staging mode | ❌ Direct write | ✅ Safe |
| Multi-Agent | ❌ | ✅ |
| Dream log | ✅ dream-log.md | ✅ kairos-dream report |
| Installation | ClawHub one-liner | ✅ install.sh one-click |

## Customization

```bash
# View trigger config
cat ~/.openclaw/workspace/memory/dream-state.json

# Change cumulative threshold (default: 30 turns)
# Edit cumulative_threshold in dream-state.json

# Change trigger time (default: 3:00 AM)
# Edit ~/Library/LaunchAgents/com.openclaw.auto-dream.plist

# Change scan scope
# Edit EXCLUDE_AGENTS / SKIP_KEYWORDS in parse-sessions.py

# View Dashboard
open ~/.openclaw/workspace/memory/dream-dashboard.html
```

## Security Guarantees

- AutoDream **can never** execute commands, browse the web, or send messages
- AutoDream **can never** directly update topic files (staging area only)
- AutoDream's own session **is always excluded** (prevents self-reference loops)
- Cron/auto tasks **are always filtered** (reduces noise)
- All changes require **main Agent review + user confirmation** before execution
- Every proposal includes **source evidence** for verification
- Every proposal includes **confidence rating** for judgment
- **Never records sensitive credentials**: passwords, tokens, API keys, SSH private keys, full public keys, cookies, sessions, recovery codes, verification codes, or security answers — even if they appear in conversations

## Session Reset Compatibility

When OpenClaw compacts a session's context, it saves the old conversation as `.jsonl.reset.{timestamp}` files. AutoDream scans these by default to prevent information loss:

- **Time window**: only scans reset files with timestamps within 24 hours
- **Limit**: max 20 reset files per Agent
- **Depth**: reads last 30 lines per reset file

If AutoDream seems to have missed some conversations (e.g., discussed at night but not found in the morning), it's likely because the session was reset. The reset file scanning automatically captures these backups.

## Session Health Check (v4.0)

**New in v4.0**: AutoDream now includes a Session Health Check to prevent context overflow issues.

### Problem

The auto-dream agent can experience context overflow after long-term running:

- Scheduled task fails (SIGTERM) after ~7-10 days
- Manual trigger reports "Context overflow: prompt too large"
- Root cause: Each trigger passes the full session history to LLM (~5MB per run, accumulating over weeks)

### Solution

**Phase X: Session Health Check** runs **before** triggering the auto-dream agent:

1. **Run before trigger**: Check auto-dream session size (excluding .reset.* files)
2. **Threshold exceeded (>5MB)**:
   - Generate `dream-continuity.md` with key conclusions from previous run
   - Create `.reset.*` marker file to trigger OpenClaw gateway session compaction
   - Re-read continuity and append to task prompt
3. **Continue normal flow**: Agent starts fresh with continuity context

### Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| Session Size Threshold | 5000 KB | Triggers reset when exceeded. Override with `SESSION_SIZE_THRESHOLD` env var |
| Continuity File Path | `~/.openclaw/workspace-auto-dream/dream-continuity.md` | Override with `CONTINUITY_FILE` var |

### Testing

Local test (2026-04-12):
- Simulated large session (fake_large.jsonl 5.9MB)
- Script detected 6000KB > 5000KB
- Continuity file generated correctly
- .reset.* marker file created
- Gateway auto-compacted session (5.9MB → 453KB)
- auto-dream agent completed normally (<1 min, previously context overflow)

## Related Projects

- [Claude Code](https://github.com/anthropics/claude-code) — Original Dream Machine inspiration
- [dream-skill](https://github.com/grandamenium/dream-skill) — 4-phase pipeline, grep pattern matching, install script design
- [openclaw-auto-dream](https://github.com/LeoYeAI/openclaw-auto-dream) — 5-layer memory system, health scoring, dashboard
- [OpenClaw](https://github.com/openclaw/openclaw) — Agent framework

## License

MIT-0


---

# 🇨🇳 中文

## 🇨🇳 核心特性

| 特性 | 说明 |
|------|------|
| **4 阶段流程** | ORIENT → GATHER → CONSOLIDATE → PRUNE，借鉴自 [dream-skill](https://github.com/grandamenium/dream-skill) |
| **grep 模式匹配** | 8 类信号自动识别（用户纠正/偏好变更/重要决策/重复模式/配置变更/**外部资源**/**文件创建**/**重要任务**），效率比全文读取高 10 倍 |
| **暂存区模式** | AutoDream 只写提案到 `pending-changes/`，主 Agent 审核后才执行，避免错误写入污染记忆 |
| **全 Agent 扫描** | 扫描所有 Agent 的 session（main、子 Agent 等），不只是主 Agent |
| **累积触发** | Heartbeat 检测对话轮数，达到阈值自动触发；凌晨 3:00 也强制触发 |
| **Dashboard 可视化** | 交互式 HTML 仪表板，5 维健康指标（新鲜度/覆盖度/连通度/效率/可达性）；**支持多 Agent 视图**，每个 Agent 独立健康评分、卡片和概览表格 |
| **install.sh 一键安装** | 借鉴 [dream-skill](https://github.com/grandamenium/dream-skill) 的 install.sh 设计，30 秒完成 |
| **语义分析模式** | 新增 `semantic` 输出模式，输出完整对话原文给 auto-dream Agent，让 LLM 自行判断语义重要性，弥补 grep 关键词匹配的盲区；**semantic 每文件 100 行，其余模式 30 行** |

## 📦 快速安装

> install.sh 幂等，可重复运行。

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
│     ├─ 8 类信号：纠正/偏好/决策/重复/配置/资源/文件创建/重要任务 │
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

如果选择 **4**，安装脚本会尝试自动为主 Agent 接入 `pending-changes` 检查逻辑，包括：
- **Session Start 检查**：每次新建 session 时检查 pending
- **Every Turn 检查 + 日期比对**：每次收到消息时，检查当前日期是否与上次不同（跨天自动触发）
- **last_pending_check_date**：dream-state.json 中记录上次检查日期，确保跨天 session 也能正确触发

### 跨天 session 支持

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

| 特性 | dream-skill | AutoDream for OpenClaw |
|------|------------|------------------------|
| 触发方式 | Stop hook | launchd 定时 + Heartbeat 累积触发 |
| 流程 | 4 阶段 | ✅ 4 阶段（同） |
| grep 模式匹配 | ✅ 5 类信号 | ✅ 同（借鉴，8 类） |
| 暂存区模式 | ❌ 直接写 | ✅ 安全 |
| 多 Agent 支持 | ❌ 单项目 | ✅ 全 Agent 扫描 |
| Cron 过滤 | ❌ 无 | ✅ |
| 可视化 Dashboard | ❌ 无 | ✅ |
| 安装方式 | git clone + bash install.sh | install.sh 一键安装 |

### openclaw-auto-dream

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

## Session 健康检查机制 (v4.0)

**v4.0 新增**：AutoDream 现已内置 Session 健康检查机制，解决长期运行的 context overflow 问题。

### 问题描述

auto-dream 子 Agent 长期运行后会出现 context overflow：

- 凌晨定时任务失败（SIGTERM）
- 手动触发后 agent 报错 "Context overflow: prompt too large"
- 每月约 7-10 天后 session 积累到瓶颈

**根本原因**：每次 trigger 都会把完整 session 历史塞给 LLM，每次约增长 5MB，累积几周后超出上下文窗口。

### 解决方案

**Phase X：Session 健康检查** 在触发 auto-dream agent **之前**执行：

1. **运行前检查**：统计 auto-dream session 大小（不含 .reset.* 文件）
2. **超过阈值（默认 5MB）**：
   - 生成 `dream-continuity.md`，记录上次运行关键结论
   - 创建 `.reset.*` 标记文件，触发 OpenClaw gateway session compaction
   - 重新读取 continuity 并追加到任务 prompt
3. **继续正常流程**：Agent 以干净 session + continuity 上下文启动

### 配置参数

| 参数 | 默认值 | 说明 |
|------|-------|------|
| Session 大小阈值 | 5000 KB | 超过此大小触发 reset，可通过环境变量 SESSION_SIZE_THRESHOLD 覆盖 |
| continuity 文件路径 | ~/.openclaw/workspace-auto-dream/dream-continuity.md | 可通过 CONTINUITY_FILE 变量覆盖 |

### 测试验证

本地测试（2026-04-12）：
- 模拟超大 session（fake_large.jsonl 5.9MB）
- 触发脚本检测到 6000KB > 5000KB
- continuity 文件正确生成
- .reset.* 标记文件创建
- Gateway 自动压缩 session（5.9MB → 453KB）
- auto-dream agent 正常完成（不到1分钟，之前 context overflow 卡死）

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
