---
name: autodream
description: "启用 AutoDream —— OpenClaw 自动记忆维护。定期读取所有 Agent 的对话记录，用 4 阶段流程（ORIENT→GATHER→CONSOLIDATE→PRUNE）+ grep 模式匹配提取关键决策、偏好和项目进展，写入待审区供用户确认。适用场景：(1) 设置自动记忆整理，(2) 安装 Claude Code 风格的做梦机制，(3) 希望 Agent 跨会话记住对话内容。触发词：'安装 autodream'、'设置自动记忆'、'启用做梦'、'Claude Code 记忆自动化'。"
---

# AutoDream —— 自动记忆维护（4阶段流程 + 暂存区模式）

灵感来自 Claude Code 的做梦机制。受限子 Agent 每天凌晨用 4 阶段流程分析所有对话，生成变更提案。主 Agent 在你下次交互时审核并执行。

## 核心架构

```
每天凌晨 3:00（或累积触发）：
  launchd / Heartbeat → trigger-auto-dream.sh v3
  ├─ Phase 1 ORIENT：读取现有 memory 状态
  ├─ Phase 2 GATHER：grep 模式匹配 + 完整对话
  ├─ Phase 3 CONSOLIDATE：生成变更提案（暂存区）
  └─ Phase 4 PRUNE：标记过期条目

你下次发消息时：
  主 Agent 检查 pending-changes → 展示摘要 → 你确认 → 执行
```

## 关键设计

- **4 阶段流程**：借鉴 dream-skill 的 ORIENT→GATHER→CONSOLIDATE→PRUNE 模型
- **grep 模式匹配**：5 类信号（用户纠正、偏好变更、重要决策、重复模式、配置变更），效率比全文读取高 10 倍
- **暂存区模式**：auto-dream 只写提案，不直接改 topic 文件。主 Agent + 用户确认后再执行
- **全 Agent 扫描**：读取所有 Agent 的 session（main、qiwen、invest-advisor 等），不只是 main
- **排除自身**：auto-dream 自己的 session 被排除，防止自引用循环
- **过滤自动化任务**：cron 任务、mac 负载记录、heartbeat 等自动过滤，减少噪音
- **来源证据**：每条提案附带原始对话片段，便于验证
- **累积触发**：Heartbeat 检查对话轮数，达到阈值自动触发
- **对话深度评分**：平均消息长度 × 用户轮次，区分闲聊和深度讨论

## 前置条件

- OpenClaw gateway 正在运行
- 已配置至少一个 Agent（主 Agent）
- 系统有 Python 3

## 安装步骤（两种方式）

### 方式 A：一键安装（推荐，30 秒完成）

```bash
# 方式 A：一键安装（推荐，30 秒完成）
bash ~/.openclaw/workspace/skills/autodream/install.sh
```

脚本自动完成所有配置（目录、文件、openclaw.json、launchd），完成后打印需要手动确认的 2 步。

**install.sh 会自动检测已安装的组件并跳过**，可以重复运行。

### 方式 B：手动分步安装

如果你是开发者或想了解每个步骤，手动执行以下 11 步。

### 第 1 步：创建 AutoDream 子 Agent

在 `~/.openclaw/openclaw.json` 的 `agents.list` 中添加：

```json
{
  "id": "auto-dream",
  "name": "AutoDream",
  "workspace": "~/.openclaw/workspace-auto-dream",
  "model": "<你选择的模型>",
  "identity": {
    "name": "AutoDream",
    "emoji": "🌙"
  },
  "tools": {
    "allow": ["read", "edit", "write", "session_status"],
    "deny": [
      "exec", "browser", "process", "message", "subagents",
      "sessions_spawn", "sessions_send", "sessions_list",
      "sessions_history", "sessions_yield", "canvas", "pdf",
      "image", "image_generate", "web_search", "web_fetch",
      "tts", "feishu_doc", "feishu_wiki", "feishu_drive",
      "feishu_bitable", "feishu_chat", "feishu_app_scopes"
    ]
  }
}
```

> **⚠️ 重要**：如果一个工具同时出现在 allow 和 deny 中，**deny 优先**。请确保它们不重叠。

### 第 2 步：允许主 Agent 调度 AutoDream

在主 Agent 的配置中，将 `"auto-dream"` 添加到 `subagents.allowAgents`：

```json
"subagents": {
  "allowAgents": ["已有 Agent...", "auto-dream"]
}
```

### 第 3 步：创建目录结构

```bash
mkdir -p ~/.openclaw/workspace-auto-dream/memory/pending-changes
mkdir -p ~/.openclaw/workspace/scripts/logs
mkdir -p ~/.openclaw/workspace/memory/pending-changes
```

### 第 4 步：创建 AutoDream 任务文件

保存到 `~/.openclaw/workspace-auto-dream/auto-dream-task.md`。见 [auto-dream-task.md 的完整内容](https://github.com/你的仓库)。任务文件定义了 4 阶段流程的详细指令。

### 第 5 步：创建会话解析脚本 v3

保存到 `~/.openclaw/workspace/scripts/parse-sessions.py`。

v3 新增功能：
- 3 种输出模式：transcript / scan / full
- GATHER 模式匹配：5 类信号模式自动识别
- 会话深度评分：区分闲聊和深度讨论
- JSON 统计输出

### 第 6 步：创建触发脚本 v3

保存到 `~/.openclaw/workspace/scripts/trigger-auto-dream.sh` 并 `chmod +x`。

v3 新增功能：
- 4 阶段指令注入（ORIENT/GATHER/CONSOLIDATE/PRUNE）
- 自动更新 dream-state.json
- 拷贝 kairos-dream 报告到主 workspace

### 第 7 步：创建 Dream 状态文件

保存到 `~/.openclaw/workspace/memory/dream-state.json`：

```json
{
  "last_dream_time": "2026-04-04T03:00:00+08:00",
  "last_dream_date": "2026-04-04",
  "cumulative_turns": 0,
  "cumulative_threshold": 30,
  "min_interval_hours": 6,
  "total_dream_cycles": 0,
  "health_score": null,
  "last_health_check": null
}
```

### 第 8 步：配置定时任务（macOS）

创建 `~/Library/LaunchAgents/com.openclaw.auto-dream.plist`：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.openclaw.auto-dream</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>/Users/你的用户名/.openclaw/workspace/scripts/trigger-auto-dream.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/Users/你的用户名/.openclaw/workspace/scripts/logs/auto-dream.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/你的用户名/.openclaw/workspace/scripts/logs/auto-dream.err</string>
</dict>
</plist>
```

加载：

```bash
launchctl load ~/Library/LaunchAgents/com.openclaw.auto-dream.plist
```

### 第 9 步：配置 Heartbeat 累积触发

在主 Agent 的 HEARTBEAT.md 中添加：

```markdown
### AutoDream 累积触发检查
- 检查频率：每次心跳
- 逻辑：
  1. 读取 `memory/dream-state.json` 获取上次 dream 时间和累积轮数
  2. 用 session_status 获取当前 session 的 total token
  3. 如果距上次 dream 超过 6 小时 且 累积轮数 ≥ 30：
     - 更新 dream-state.json
     - spawn auto-dream agent（运行 trigger-auto-dream.sh）
     - 通知用户
  4. 如果凌晨 3:00-5:00 且今天还没跑过 → 强制触发
```

### 第 10 步：主 Agent 启动检查

在主 Agent 的 AGENTS.md 中添加：

```markdown
## AutoDream 启动检查

每次会话开始时，检查 `memory/pending-changes/` 目录：
1. 列出所有 `.md` 文件
2. 如有内容，读取并向用户展示待处理变更摘要
3. 请用户确认要执行哪些变更
4. 执行确认的变更后，删除该 pending 文件
```

### 第 11 步：重启 Gateway 并测试

```bash
openclaw gateway restart
bash ~/.openclaw/workspace/scripts/trigger-auto-dream.sh
```

## 运行流程

```
┌──────────────────────────────────────────────────────┐
│  触发方式 A：每天凌晨 3:00                           │
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
│  └─ dream-state.json（状态更新）                     │
├──────────────────────────────────────────────────────┤
│  你下次发消息时：                                    │
│  主 Agent 检查 pending-changes → 展示摘要            │
│  → 你确认 → 执行 → 删除 pending 文件                │
└──────────────────────────────────────────────────────┘
```

## GATHER 信号模式

| 类型 | 模式示例 | 说明 |
|------|---------|------|
| 用户纠正 | actually, 不对, 错了, I said, I meant | 最高优先级 |
| 偏好变更 | 以后, 从现在开始, I prefer, always use | 用户表达偏好 |
| 重要决策 | 决定了, 就用, switch to, let's go with | 关键选择 |
| 重复模式 | 又忘了, 每次, again, every time | 需要固化 |
| 配置变更 | 模型切换, 改配置, upgrade | 技术变更 |

## 自定义

- **定时**: 编辑 plist 中的 `StartCalendarInterval`
- **累积阈值**: 编辑 `dream-state.json` 中的 `cumulative_threshold`
- **最小间隔**: 编辑 `dream-state.json` 中的 `min_interval_hours`
- **模型**: 编辑 auto-dream Agent 的 `model` 字段
- **排除 Agent**: 编辑 `parse-sessions.py` 中的 `EXCLUDE_AGENTS`
- **过滤关键词**: 编辑 `parse-sessions.py` 中的 `SKIP_KEYWORDS`
- **信号模式**: 编辑 `parse-sessions.py` 中的 `SIGNAL_PATTERNS`
- **每文件最大行数**: 编辑 `MAX_LINES_PER_FILE`

## 安全保证

- auto-dream **永远不能**执行命令、浏览网页或发送消息
- auto-dream **永远不能**直接更新 topic 文件（仅限暂存区）
- auto-dream 自己的 session **始终被排除**（防止自引用循环）
- cron/自动任务**始终被过滤**（减少噪音）
- 所有变更需要**主 Agent 审核 + 用户确认**后才执行
- 每条提案包含**来源证据**，便于验证
- 每条提案包含**可信度标注**，辅助判断

## 故障排查

- **没有生成 pending-changes**: 检查 `~/.openclaw/workspace/scripts/logs/auto-dream.log`
- **会话解析失败**: 单独运行 `python3 parse-sessions.py` 验证
- **工具被拒绝**: 如果一个工具同时在 allow 和 deny 中，deny 优先 —— 请分开设置
- **cron 没被过滤**: 检查 `parse-sessions.py` 中的 `SKIP_KEYWORDS`
- **Agent 没被扫描**: 检查 `parse-sessions.py` 中的 `EXCLUDE_AGENTS`
- **累积触发没生效**: 检查 `dream-state.json` 的阈值和间隔设置
