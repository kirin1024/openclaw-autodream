---
name: autodream
description: "Enable AutoDream — OpenClaw Automatic Memory Maintenance. Periodically reads all Agent conversation records, uses a 4-phase pipeline (ORIENT→GATHER→CONSOLIDATE→PRUNE) + grep pattern matching to extract key decisions, preferences, and project progress, writes to staging area for user confirmation. Use cases: (1) Set up automatic memory organization, (2) Install Claude Code-style dream mechanism, (3) Enable cross-session memory. Trigger: 'install autodream', 'set up auto memory', 'enable dream', 'Claude Code memory automation'."
---

# AutoDream — Automatic Memory Maintenance (4-Phase Pipeline + Staging Area)

Inspired by Claude Code's Dream Machine. A restricted sub-Agent analyzes all conversations daily using a 4-phase pipeline, generating change proposals. The main Agent reviews and executes upon your next interaction.

## Core Architecture

```
Daily at 3:00 AM (or accumulative trigger):
  launchd / Heartbeat → trigger-auto-dream.sh v3
  ├─ Phase 1 ORIENT: Read existing memory state
  ├─ Phase 2 GATHER: grep pattern matching + full conversation
  ├─ Phase 3 CONSOLIDATE: Generate change proposals (staging area)
  └─ Phase 4 PRUNE: Mark expired entries

On your next message:
  Main Agent checks pending-changes → Shows summary → You confirm → Executes
```

## Key Design

- **4-Phase Pipeline**: ORIENT→GATHER→CONSOLIDATE→PRUNE, inspired by dream-skill
- **Grep Pattern Matching**: 8 signal types (user correction/preference change/important decision/repetition/config change/external resources/file creation/important tasks), 10x more efficient than full-text reading
- **Staging Area**: auto-dream only writes proposals, doesn't directly modify topic files. Main Agent + user confirms before execution
- **Multi-Agent Scanning**: Reads all Agent sessions (main, sub-agents, etc.), not just main
- **Self-Exclusion**: auto-dream's own session is excluded to prevent self-reference loops
- **Filter Automation**: Cron tasks, mac load records, heartbeats filtered to reduce noise
- **Source Evidence**: Each proposal includes original conversation snippets for verification
- **Accumulative Trigger**: Heartbeat monitors conversation turns, auto-triggers when threshold reached
- **Conversation Depth Scoring**: Average message length × user turns, distinguishes chat from deep discussion

## Prerequisites

- OpenClaw gateway is running
- At least one Agent configured (main Agent)
- Python 3 installed on system

## Installation

### Option: Install via install.sh (Recommended)

```bash
# Clone repo to skills directory
git clone https://github.com/kirin1024/openclaw-autodream ~/.openclaw/workspace/skills/autodream

# Run install script
bash ~/.openclaw/workspace/skills/autodream/install.sh

# Restart Gateway
openclaw gateway restart
```

The script automatically completes all configuration (directories, files, openclaw.json, launchd). After completion, it prints 2 steps requiring manual confirmation.

**install.sh auto-detects already installed components and skips** — safe to re-run.

If you're a developer wanting to understand each step, manually execute the following steps.

### Step 1: Create AutoDream Sub-Agent

Add to `~/.openclaw/openclaw.json` in `agents.list`:

```json
{
  "id": "auto-dream",
  "name": "AutoDream",
  "workspace": "~/.openclaw/workspace-auto-dream",
  "model": "<your-model>",
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

> **⚠️ Important**: If a tool appears in both allow and deny, **deny wins**. Make sure they don't overlap.

### Step 2: Allow Main Agent to调度 AutoDream

In main Agent config, add `"auto-dream"` to `subagents.allowAgents`:

```json
"subagents": {
  "allowAgents": ["existing agents...", "auto-dream"]
}
```

### Step 3: Create Directory Structure

```bash
mkdir -p ~/.openclaw/workspace-auto-dream/memory/pending-changes
mkdir -p ~/.openclaw/workspace/scripts/logs
mkdir -p ~/.openclaw/workspace/memory/pending-changes
mkdir -p ~/.openclaw/workspace/memory/daily
```

### Step 4: Create AutoDream Task File

Save to `~/.openclaw/workspace-auto-dream/auto-dream-task.md`. See [auto-dream-task.md full content](https://github.com/kirin1024/openclaw-autodream/blob/main/auto-dream-task.md). The task file defines detailed 4-phase pipeline instructions.

### Step 5: Create Session Parser Script v3

Save to `~/.openclaw/workspace/scripts/parse-sessions.py`.

v3 new features:
- 3 output modes: transcript / scan / full
- GATHER pattern matching: 8 signal types auto-detected
- Session depth scoring: distinguishes chat from deep discussion
- JSON statistics output
- Semantic analysis mode: LLM judges semantic importance (100 lines per file)

### Step 6: Create Trigger Script v3

Save to `~/.openclaw/workspace/scripts/trigger-auto-dream.sh` and `chmod +x`.

v3 new features:
- 4-phase instruction injection (ORIENT/GATHER/CONSOLIDATE/PRUNE)
- Auto-update dream-state.json
- Copy kairos-dream report to main workspace
- Cross-day session support with date comparison

### Step 7: Create Dream State File

Save to `~/.openclaw/workspace/memory/dream-state.json`:

```json
{
  "last_dream_time": "2026-04-04T03:00:00+08:00",
  "last_dream_date": "2026-04-04",
  "last_pending_check_date": "2026-04-11",
  "cumulative_turns": 0,
  "cumulative_threshold": 30,
  "min_interval_hours": 6,
  "total_dream_cycles": 0,
  "health_score": null,
  "last_health_check": null
}
```

### Step 8: Configure Scheduled Task (macOS)

Create `~/Library/LaunchAgents/com.openclaw.auto-dream.plist`:

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
        <string>/Users/<username>/.openclaw/workspace/scripts/trigger-auto-dream.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/Users/<username>/.openclaw/workspace/scripts/logs/auto-dream.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/<username>/.openclaw/workspace/scripts/logs/auto-dream.err</string>
</dict>
</plist>
```

Load:

```bash
launchctl load ~/Library/LaunchAgents/com.openclaw.auto-dream.plist
```

### Step 9: Configure Heartbeat Accumulative Trigger

In main Agent's HEARTBEAT.md, add:

```markdown
### AutoDream Accumulative Trigger Check
- Check frequency: Every heartbeat
- Logic:
  1. Read `memory/dream-state.json` for last dream time and cumulative turns
  2. Use session_status to get current session total tokens
  3. If last dream > 6 hours ago AND cumulative turns ≥ 30:
     - Update dream-state.json
     - Spawn auto-dream agent (run trigger-auto-dream.sh)
     - Notify user
  4. If 3:00-5:00 AM and hasn't run today → Force trigger
```

### Step 10: Main Agent Start Check (Cross-Day Support)

In main Agent's AGENTS.md, add:

```markdown
### AutoDream pending-changes check (Session Start & Every Turn)
- Run `ls memory/pending-changes/*.md 2>/dev/null` to check
- If pending `.md` files exist, read the newest one first
- Summarize the pending changes briefly
- Ask the user whether to confirm / reject / defer them
- Do this **before** handling the user's actual request

### Every Turn (every message, including ongoing sessions)
Before replying to any user message:

1. **AutoDream pending-changes check** (with date-based trigger):
   - Read `dream-state.json` to get `last_pending_check_date`
   - Compare with current date (YYYY-MM-DD format)
   - **Trigger check if**: first check ever OR date changed (new day)
   - Run `ls memory/pending-changes/*.md 2>/dev/null` to check
   - Update `last_pending_check_date` after check
```

### Step 11: Restart Gateway and Test

```bash
openclaw gateway restart
bash ~/.openclaw/workspace/scripts/trigger-auto-dream.sh
```

## Operation Flow

```
┌──────────────────────────────────────────────────────┐
│  Trigger A: Daily at 3:00 AM                        │
│  Trigger B: Heartbeat detects cumulative turns ≥ 30  │
├──────────────────────────────────────────────────────┤
│  Phase 1: ORIENT — Read MEMORY.md + topic files      │
│  Phase 2: GATHER — grep signals + semantic + full    │
│     ├─ 8 signals: correction/pref/decision/          │
│     │   repetition/config/resources/file-creation/    │
│     │   important-tasks                               │
│     ├─ Semantic mode: LLM judges importance (100 ln)  │
│     └─ Other modes: 30 lines per file default         │
│  Phase 3: CONSOLIDATE — Generate proposals (staging) │
│     ├─ Each with source evidence                     │
│     └─ Confidence: high / medium / low               │
│  Phase 4: PRUNE — Mark expired entries for archive   │
├──────────────────────────────────────────────────────┤
│  Output:                                             │
│  ├─ pending-changes/YYYY-MM-DD.md (proposals)         │
│  ├─ kairos-dream-YYYY-MM-DD.md (analysis report)      │
│  ├─ dream-state.json (state tracking)                │
│  └─ dream-dashboard.html (visualization)             │
├──────────────────────────────────────────────────────┤
│  On your next message:                               │
│  Main Agent checks pending-changes → shows summary   │
│  → You confirm → Execute → Delete pending files      │
└──────────────────────────────────────────────────────┘
```

## GATHER Signal Patterns

| Type | Pattern Examples | Description |
|------|-----------------|-------------|
| User Correction | actually, wrong, I said, I meant | Highest priority |
| Preference Change | from now on, I prefer, always use | User expresses preference |
| Important Decision | decided, switch to, let's go with | Key choices |
| Repetition Pattern | again, every time, keeps happening | Needs consolidation |
| Config Change | model switch, config change, upgrade | Technical changes |
| External Resources | feishu.cn/docx, github.com, jira | Created external resources |
| File Creation | Successfully wrote, created file | Generated local files |
| Important Tasks | remember this, don't forget, remind me | Explicit memory requests |

## Customization

- **Schedule**: Edit plist's `StartCalendarInterval`
- **Accumulative Threshold**: Edit `cumulative_threshold` in `dream-state.json`
- **Min Interval**: Edit `min_interval_hours` in `dream-state.json`
- **Model**: Edit auto-dream Agent's `model` field
- **Exclude Agents**: Edit `EXCLUDE_AGENTS` in `parse-sessions.py`
- **Filter Keywords**: Edit `SKIP_KEYWORDS` in `parse-sessions.py`
- **Signal Patterns**: Edit `SIGNAL_PATTERNS` in `parse-sessions.py`
- **Max Lines Per File**: Edit `MAX_LINES_PER_FILE`

## Security Guarantees

- auto-dream **can never** execute commands, browse web, or send messages
- auto-dream **can never** directly update topic files (staging area only)
- auto-dream's own session **is always excluded** (prevents self-reference loops)
- Cron/auto tasks **are always filtered** (reduces noise)
- All changes require **main Agent review + user confirmation** before execution
- Every proposal includes **source evidence** for verification
- Every proposal includes **confidence rating** for judgment

## Cross-Day Session Support (v3.1)

AutoDream now supports cross-day sessions with date-based trigger:

- **Session Start check**: Check pending on every new session
- **Every Turn check + date comparison**: On every message, compare current date with last check date (auto-trigger on new day)
- **last_pending_check_date**: Stored in dream-state.json, ensures cross-day sessions work correctly

This fixes the issue where pending changes could be "forgotten" if user continues an existing session across days.

## Session Health Check Mechanism (v4.0)

**New in v4.0**: AutoDream now includes a Session Health Check to prevent context overflow issues.

### Problem

The auto-dream agent can experience context overflow after long-term running:

- Scheduled task fails (SIGTERM) after ~7-10 days
- Manual trigger reports "Context overflow: prompt too large"
- Root cause: Each trigger passes the full session history to LLM (~5MB per run, accumulating over weeks)

### Solution

Phase X: Session Health Check runs **before** triggering the auto-dream agent:

1. **Run before trigger**: Check auto-dream session size (excluding .reset.* files)
2. **Threshold exceeded (>5MB)**:
   - Generate `dream-continuity.md` with key conclusions from previous run
   - Create `.reset.*` marker file to trigger OpenClaw gateway session compaction
   - Re-read continuity and append to task prompt
3. **Continue normal flow**: Agent starts fresh with continuity context

### Continuity File

Generated at `~/.openclaw/workspace-auto-dream/dream-continuity.md`:

```markdown
# Dream Continuity — Last State

> ⚠️ 此文件由 trigger-auto-dream.sh 自动生成。Reset 后 auto-dream Agent 读此文件恢复关键上下文。

## 上次运行信息
- 最后成功运行: {timestamp}
- 总运行次数: {count}
- Session 大小触发 reset: {size}KB
- Reset 日期: {date}

## 重要结论（从上次 pending-changes 提取）
暂无（如果 pending 文件为空或只有低可信度变更）

## 注意事项
- 本文件在每次 session reset 后由 trigger-auto-dream.sh 自动生成
- auto-dream Agent 启动时应首先读取并参考此文件
```

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

## Troubleshooting

- **No pending-changes generated**: Check `~/.openclaw/workspace/scripts/logs/auto-dream.log`
- **Session parsing failed**: Run `python3 parse-sessions.py` separately to verify
- **Tools denied**: If a tool is in both allow and deny, deny wins — separate them
- **Cron not filtered**: Check `SKIP_KEYWORDS` in `parse-sessions.py`
- **Agents not scanned**: Check `EXCLUDE_AGENTS` in `parse-sessions.py`
- **Accumulative trigger not working**: Check threshold and interval in `dream-state.json`
- **Cross-day check not working**: Ensure `last_pending_check_date` field exists in dream-state.json

## Related Links

- GitHub: https://github.com/kirin1024/openclaw-autodream
- OpenClaw Docs: https://docs.openclaw.ai
- ClawHub: https://clawhub.ai