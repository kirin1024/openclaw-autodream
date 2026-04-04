# 🌙 AutoDream for OpenClaw

**自动记忆维护 —— 让你的 AI Agent 真正"记住"你**

灵感来自 [Claude Code](https://claude.com) 的 Dream Machine 机制。受限子 Agent 每天凌晨自动分析所有 Agent 的对话，提取关键决策和偏好，生成变更提案等待你确认后执行。

> ✨ 从 11 步手动安装到 1 条命令，30 秒完成。

## 🎯 核心特性

| 特性 | 说明 |
|------|------|
| **4 阶段流程** | ORIENT → GATHER → CONSOLIDATE → PRUNE，借鉴自 [dream-skill](https://github.com/grandamenium/dream-skill) |
| **grep 模式匹配** | 5 类信号自动识别（用户纠正/偏好变更/重要决策/重复模式/配置变更），效率比全文读取高 10 倍 |
| **暂存区模式** | AutoDream 只写提案到 `pending-changes/`，主 Agent 审核后才执行，避免错误写入污染记忆 |
| **全 Agent 扫描** | 扫描所有 Agent 的 session（main、子 Agent 等），不只是主 Agent |
| **累积触发** | Heartbeat 检测对话轮数，达到阈值自动触发；凌晨 3:00 也强制触发 |
| **Dashboard 可视化** | 交互式 HTML 仪表板，5 维健康指标（新鲜度/覆盖度/连通度/效率/可达性） |
| **install.sh 一键安装** | 借鉴 [dream-skill](https://github.com/grandamenium/dream-skill) 的 install.sh 设计，30 秒完成 |
| **工具集严格限制** | AutoDream 只能 read/write/edit，不能执行命令、访问浏览器或发送消息 |

## 📦 快速安装

> 二选一即可，install.sh 幂等，可重复运行。

### 方式 A：从 ClawHub 安装（推荐）

```bash
# 第 1 步：下载 Skill 到本地
openclaw skills install autodream

# 第 2 步：运行安装脚本（自动配置 Agent、定时任务等）
bash ~/.openclaw/workspace/skills/autodream/install.sh

# 第 3 步：重启 Gateway
openclaw gateway restart
```

### 方式 B：从源码安装

```bash
# 克隆仓库到 skills 目录
git clone https://github.com/kirin1024/openclaw-skills ~/.openclaw/workspace/skills/openclaw-skills

# 运行安装脚本
bash ~/.openclaw/workspace/skills/openclaw-skills/autodream/install.sh

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
│  Phase 2: GATHER — grep 模式匹配 + 完整对话          │
│     ├─ 5 类信号：用户纠正/偏好/决策/重复/配置        │
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

## 📁 文件结构

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
| 安装方式 | git clone + bash install.sh | 一键安装 |

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

## 🧪 验证安装

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
