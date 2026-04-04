#!/bin/bash
#===============================================================================
# AutoDream install.sh — 一键安装脚本
# 参考 dream-skill 的 install.sh 设计
# 用法: bash <(curl -Ls https://你的脚本URL)  # 远程
#       或者: bash install.sh                  # 本地
#===============================================================================
set -e

SCRIPT_VERSION="3.0"
HOME_DIR="${HOME}"
OPENCLAW_DIR="${HOME_DIR}/.openclaw"
WORKSPACE_MAIN="${OPENCLAW_DIR}/workspace"
WORKSPACE_AUTO_DREAM="${OPENCLAW_DIR}/workspace-auto-dream"
SKILL_DIR="${WORKSPACE_MAIN}/skills/autodream"
SCRIPTS_DIR="${WORKSPACE_MAIN}/scripts"
LOG_DIR="${SCRIPTS_DIR}/logs"
MEMORY_DIR="${WORKSPACE_MAIN}/memory"
MEMORY_PENDING="${MEMORY_DIR}/pending-changes"
OPENCLAW_JSON="${OPENCLAW_DIR}/openclaw.json"
LAUNCHD_PLIST="${HOME_DIR}/Library/LaunchAgents/com.openclaw.auto-dream.plist"

# 颜色输出
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[ OK ]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERR]${NC} $1"; }
step()    { echo -e "${CYAN}[STEP]${NC} ${BOLD}$1${NC}"; }

echo ""
echo -e "${BOLD}🌙 AutoDream v${SCRIPT_VERSION} 安装向导${NC}"
echo "========================================"
echo ""

#===============================================================================
# 前置检查
#===============================================================================
step "1. 前置检查"

# 检查 OpenClaw 是否安装
if [ ! -d "$OPENCLAW_DIR" ]; then
    error "未找到 OpenClaw 目录: $OPENCLAW_DIR"
    error "请先安装 OpenClaw: https://docs.openclaw.ai"
    exit 1
fi
success "OpenClaw 目录存在"

# 检查 gateway 版本
if command -v openclaw &>/dev/null; then
    VERSION=$(openclaw --version 2>/dev/null | head -1 || echo "unknown")
    success "OpenClaw CLI: $VERSION"
else
    warn "未找到 openclaw 命令（可能不在 PATH 中），跳过版本检查"
fi

#===============================================================================
# 第 2 步：创建目录结构
#===============================================================================
step "2. 创建目录结构"
mkdir -p "$WORKSPACE_AUTO_DREAM/memory/pending-changes"
mkdir -p "$SCRIPTS_DIR/logs"
mkdir -p "$MEMORY_PENDING"
mkdir -p "$SKILL_DIR"
echo "  $WORKSPACE_AUTO_DREAM/memory/pending-changes/"
echo "  $SCRIPTS_DIR/logs/"
echo "  $MEMORY_PENDING/"
echo "  $SKILL_DIR/"
success "目录结构创建完成"

#===============================================================================
# 第 3 步：写入核心文件
#===============================================================================
step "3. 写入核心文件"

# --- auto-dream-task.md ---
cat > "$WORKSPACE_AUTO_DREAM/auto-dream-task.md" << 'TASK_EOF'
# AutoDream 任务：夜间记忆整理（4阶段流程 + 暂存区模式）

## 你的角色

你是 AutoDream，一个受限的记忆整理子 Agent。你的工具：read、write、edit、session_status。

**重要**：你在暂存区模式下工作。你不直接更新 topic 文件，只把变更提案写到 `memory/pending-changes/`。

## 输入数据

你会收到 MEMORY.md、topic 文件摘要、信号模式匹配结果、完整对话记录、已有的 pending-changes，以及两项显式日期：
- **RUN_DATE**：本次运行日期（脚本实际执行的日期）
- **CONTENT_DATE**：本次归整内容所属日期（用于命名输出文件）

按 4 阶段流程处理。

---

## Phase 1: ORIENT — 了解现状

读取收到的 MEMORY.md 和 topic 文件摘要，建立以下认知：
- 有多少个 topic 文件，各覆盖什么主题
- 哪些 topic 文件最近被更新过（3天内）
- 哪些条目可能过期（超过30天未提及）
- 现有记忆中有没有矛盾点（同一件事有两种说法）

输出：简要描述现有 memory 的概况。

---

## Phase 2: GATHER — 提取信号

你收到两类数据：
1. **信号模式匹配结果**：已经用 grep 过滤过的高概率信号（用户纠正、偏好变更、重要决策、重复模式、配置变更）
2. **完整对话记录**：所有 Agent 的对话原文

从这两类数据中提取：
- **用户明确表达的新偏好/决策**（可信度 high）
- **从上下文推断的重要变更**（可信度 medium）
- **从模式中猜测的规律**（可信度 low）
- **与现有记忆的矛盾**

注意：
- 优先使用信号模式匹配结果（已经被 grep 预筛选过）
- 对话原文作为补充验证，不逐条分析
- 跳过 cron 任务、mac-load 记录、heartbeat 等自动内容

---

## Phase 3: CONSOLIDATE — 生成变更提案

把发现写入 `memory/pending-changes/CONTENT_DATE.md`。

**命名规则（方案 B，必须严格遵守）**：
- 文件名使用 **CONTENT_DATE**，不是 RUN_DATE
- 例子：如果脚本在 `2026-04-05 03:00` 运行，但归整的是 `2026-04-04` 的内容，那么必须写入 `memory/pending-changes/2026-04-04.md`
- 如果同一次运行还要生成分析报告，报告文件也使用同一个 **CONTENT_DATE**

每条提案格式：

```markdown
## 变更 N：[简要描述]
- **目标文件**: `memory/xxx.md`
- **类型**: create | update | append
- **可信度**: high | medium | low
- **来源**: Agent 名称，会话时间
- **摘要**: 变了什么，为什么变
- **来源证据**: [原始对话片段，用于验证]
- **提议内容**:
  ```
  [要添加/修改的具体内容]
  ```
```

规则：
- 不创建重复条目（对比已有的 pending-changes）
- 相对日期转绝对日期（"昨天" → "2026-04-03"）
- 消除矛盾：如果新信息与旧记忆冲突，新信息优先，旧记忆标注"已被更新"
- 所有条目必须附带来源证据

---

## Phase 4: PRUNE — 标记归档

检查 topic 文件中：
- 超过 30 天未在任何对话中提及的条目 → 标记为"建议归档"
- 超过 90 天且引用次数低的条目 → 标记为"建议删除"
- 注意：⚠️ PERMANENT 和 📌 PIN 标记的条目完全免疫归档

将归档提案也写入 `CONTENT_DATE` 对应的 pending-changes 文件。

---

## 输出要求

1. **变更提案**：写入 `memory/pending-changes/CONTENT_DATE.md`
2. **分析报告**：写入 `memory/kairos-dream-CONTENT_DATE.md`，包含：
   - ORIENT 总结
   - GATHER 发现的信号数
   - CONSOLIDATE 生成的变更数
   - PRUNE 标记的归档条目
   - 对话深度评分（平均消息长度 × 用户轮次）

---

## 安全规则

1. **绝不直接写 topic 文件** —— 只写 `memory/pending-changes/` 和 `memory/kairos-dream-*.md`
2. **绝不删除或重命名文件**
3. **拿不准就标 low**
4. **发现矛盾** → 标注为"需要用户确认"
5. **仅追加**到 pending-changes，不覆盖
6. **过滤 cron 噪音** —— 跳过自动化任务
7. **排除自身** —— 不分析 auto-dream 的 session
8. **禁止记录敏感凭证** —— 不得写入密码、Token、API Key、SSH 私钥、公钥全文、Cookie、Session、Recovery Code、验证码、账号密保答案，哪怕用户在对话中明文发送过
9. **禁止记录远程写权限能力** —— 不得把“这台机器可以 push/publish/deploy/发消息/改线上配置/拥有某平台写权限”这类环境能力写入 pending-changes、kairos 报告或任何 memory 提案
10. **允许保留的最小事实** —— 只可记录非敏感事实，例如“存在某个仓库/项目”或“使用 GitHub 协作”；但不得记录认证方式、是否已登录、是否具备写权限、凭证位置、凭证是否可用
11. **发现敏感信息时的处理** —— 直接忽略，不摘录、不总结、不改写、不做来源证据引用；如果某条提案依赖敏感信息才能成立，则整条提案放弃
TASK_EOF
echo "  auto-dream-task.md"
success "写入 auto-dream-task.md"

# --- parse-sessions.py ---
cat > "$SCRIPTS_DIR/parse-sessions.py" << 'PARSE_EOF'
#!/usr/bin/env python3
"""
AutoDream Session Parser v3 - 4阶段分析流程 + grep模式匹配
用法: python3 parse-sessions.py [agents_dir] [output_file] [mode]
  mode: transcript (默认) | scan | full
"""
import json, os, sys, re
from datetime import datetime, timedelta
from pathlib import Path

AGENTS_DIR = os.path.expanduser("~/.openclaw/agents")
EXCLUDE_AGENTS = {"auto-dream"}
MAX_LINES_PER_FILE = 20
MIN_TEXT_LENGTH = 5
SKIP_PREFIXES = ("[cron:",)
SKIP_KEYWORDS = (
    "mac-load", "mac 负载记录", "mac 负载数据",
    "HEARTBEAT_", "<<<BEGIN_OPENCLAW_INTERNAL_CONTEXT>>>",
    "<final>", "</final>",
)
SIGNAL_PATTERNS = {
    "用户纠正": [r"实际上",r"不对",r"错了",r"不是这样的",r"我说的",r"actually",r"no,\s",r"wrong",r"incorrect",r"I said",r"I meant"],
    "偏好变更": [r"以后",r"从现在开始",r"我希望",r"我喜欢",r"不要",r"I prefer",r"always use",r"never use",r"from now on",r"going forward"],
    "重要决策": [r"决定了",r"就用",r"切换到",r"改成",r"确认用",r"let's go with",r"switch to",r"the plan is",r"we're using",r"decision"],
    "重复模式": [r"又忘了",r"每次",r"总是",r"again",r"every time",r"keep forgetting",r"as usual",r"same as before"],
    "配置变更": [r"模型.*切换",r"改.*配置",r"更新.*版本",r"升级",r"model.*switch",r"config.*change",r"upgrade"],
}

def should_skip(text):
    if text.startswith("[cron:"): return True
    for kw in SKIP_KEYWORDS:
        if kw.lower() in text.lower(): return True
    return False

def extract_messages(jsonl_path, max_lines=MAX_LINES_PER_FILE):
    messages = []; user_count = 0; total_chars = 0
    try:
        with open(jsonl_path, "r", encoding="utf-8") as f:
            lines = f.readlines()
        for line in lines[-max_lines:]:
            try:
                obj = json.loads(line.strip())
                if obj.get("type") != "message": continue
                msg = obj.get("message", {})
                if not isinstance(msg, dict): continue
                role = msg.get("role", "?"); content = msg.get("content", "")
                text_parts = []
                if isinstance(content, list):
                    for c in content:
                        if isinstance(c, dict) and c.get("type") == "text":
                            text = c.get("text", "").strip()
                            if len(text) >= MIN_TEXT_LENGTH: text_parts.append(text[:300])
                elif isinstance(content, str) and len(content) >= MIN_TEXT_LENGTH:
                    text_parts.append(content[:300])
                if text_parts:
                    role_label = "USER" if role == "user" else role.upper()
                    for text in text_parts:
                        if should_skip(text): continue
                        messages.append({"role": role_label, "text": text.replace("\n", " "), "length": len(text)})
                        if role == "user": user_count += 1
                        total_chars += len(text)
            except (json.JSONDecodeError, KeyError): continue
    except Exception as e: print(f"  ⚠️ 读取出错: {e}", file=sys.stderr)
    return messages, user_count, total_chars

def scan_patterns(messages):
    findings = []
    for msg in messages:
        text = msg["text"]
        for category, patterns in SIGNAL_PATTERNS.items():
            for pattern in patterns:
                if re.search(pattern, text, re.IGNORECASE):
                    findings.append({"category": category, "pattern": pattern, "role": msg["role"], "text": text[:200], "length": msg["length"]})
                    break
    return findings

def main():
    agents_dir = sys.argv[1] if len(sys.argv) > 1 else AGENTS_DIR
    output_file = sys.argv[2] if len(sys.argv) > 2 else None
    mode = sys.argv[3] if len(sys.argv) > 3 else "transcript"
    cutoff = datetime.now() - timedelta(hours=24)
    cutoff_str = cutoff.strftime("%Y-%m-%d %H:%M")
    all_conversations = []; all_findings = []; session_stats = []
    for agent_name in sorted(os.listdir(agents_dir)):
        agent_path = os.path.join(agents_dir, agent_name)
        sessions_path = os.path.join(agent_path, "sessions")
        if not os.path.isdir(sessions_path): continue
        if agent_name in EXCLUDE_AGENTS: continue
        agent_msgs = []; agent_findings = []; agent_files = 0; total_user_turns = 0; total_chars = 0
        for filename in sorted(os.listdir(sessions_path)):
            if not filename.endswith(".jsonl"): continue
            filepath = os.path.join(sessions_path, filename)
            if datetime.fromtimestamp(os.path.getmtime(filepath)) < cutoff: continue
            msgs, user_turns, chars = extract_messages(filepath)
            if msgs:
                agent_msgs.extend(msgs); agent_findings.extend(scan_patterns(msgs))
                agent_files += 1; total_user_turns += user_turns; total_chars += chars
        if agent_msgs:
            depth = round(total_chars / max(1, len(agent_msgs)), 1)
            session_stats.append({"agent": agent_name, "files": agent_files, "messages": len(agent_msgs), "user_turns": total_user_turns, "chars": total_chars, "findings": len(agent_findings), "depth_score": depth})
            section = f"## 📂 Agent: {agent_name} ({agent_files} 文件, {len(agent_msgs)} 条消息, {total_user_turns} 用户轮次)\n\n"
            section += "\n".join(f"[{m['role']}] {m['text']}" for m in agent_msgs)
            all_conversations.append(section)
            for f in agent_findings: f["agent"] = agent_name
            all_findings.extend(agent_findings)
    total_messages = sum(s["messages"] for s in session_stats)
    total_turns = sum(s["user_turns"] for s in session_stats)
    total_findings = len(all_findings)
    if mode == "transcript":
        output = f"# 📝 会话记录（最近 24 小时，自 {cutoff_str}）\n\n**Agent 数**: {len(session_stats)} | **消息数**: {total_messages} | **用户轮次**: {total_turns}\n\n" + "\n\n".join(all_conversations)
    elif mode == "scan":
        output = f"# 🔍 GATHER — 信号模式匹配结果（最近 24 小时）\n\n**总信号数**: {total_findings}\n\n"
        by_cat = {}
        for f in all_findings: by_cat.setdefault(f["category"], []).append(f)
        for cat, items in by_cat.items():
            output += f"### {cat} ({len(items)} 条)\n\n" + "\n".join(f"- **[{item['agent']}]** [{item['role']}] {item['text']}" for item in items[:10]) + "\n\n"
    elif mode == "full":
        output = f"# 📝 AutoDream 完整分析（最近 24 小时）\n\n**Agent 数**: {len(session_stats)} | **消息数**: {total_messages} | **用户轮次**: {total_turns} | **信号数**: {total_findings}\n\n"
        output += "## 📊 会话统计\n\n| Agent | 文件 | 消息 | 用户轮次 | 平均深度 | 信号数 |\n|-------|------|------|---------|---------|--------|\n"
        for s in session_stats: output += f"| {s['agent']} | {s['files']} | {s['messages']} | {s['user_turns']} | {s['depth_score']} | {s['findings']} |\n"
        output += "\n## 🔍 GATHER 信号\n\n"
        by_cat = {}
        for f in all_findings: by_cat.setdefault(f["category"], []).append(f)
        for cat, items in by_cat.items():
            output += f"### {cat} ({len(items)} 条)\n\n" + "\n".join(f"- **[{item['agent']}]** [{item['role']}] {item['text']}" for item in items[:10]) + "\n\n"
        output += "---\n\n## 📝 对话原文\n\n" + "\n\n".join(all_conversations)
    if output_file:
        with open(output_file, "w", encoding="utf-8") as f: f.write(output)
    else: print(output)
    stats = {"agents": len(session_stats), "messages": total_messages, "user_turns": total_turns, "findings": total_findings, "session_stats": session_stats}
    print(json.dumps(stats, ensure_ascii=False), file=sys.stderr)

if __name__ == "__main__": main()
PARSE_EOF
chmod +x "$SCRIPTS_DIR/parse-sessions.py"
echo "  parse-sessions.py"
success "写入 parse-sessions.py"

# --- trigger-auto-dream.sh ---
cat > "$SCRIPTS_DIR/trigger-auto-dream.sh" << 'TRIGGER_EOF'
#!/bin/bash
# AutoDream trigger script v3 — 4阶段流程 + grep模式匹配 + 累积触发
WORKSPACE_MAIN="$HOME/.openclaw/workspace"
WORKSPACE_AUTO_DREAM="$HOME/.openclaw/workspace-auto-dream"
LOG_DIR="$WORKSPACE_MAIN/scripts/logs"
LOG_FILE="$LOG_DIR/auto-dream.log"
SCRIPTS_DIR="$WORKSPACE_MAIN/scripts"
DREAM_STATE="$WORKSPACE_MAIN/memory/dream-state.json"
RUN_DATE=$(date '+%Y-%m-%d')
RUN_HOUR=$(date '+%H')
if [ "$RUN_HOUR" -lt 6 ]; then
    CONTENT_DATE=$(date -v-1d '+%Y-%m-%d')
else
    CONTENT_DATE="$RUN_DATE"
fi

mkdir -p "$LOG_DIR"
echo "🌙 [$(date '+%Y-%m-%d %H:%M:%S')] AutoDream triggered (v3) | run_date=$RUN_DATE content_date=$CONTENT_DATE" >> "$LOG_FILE"

# --- Phase 0: 累积触发检查 ---
if [ "$1" = "--check-only" ]; then
    if [ -f "$DREAM_STATE" ]; then
        LAST_TIME=$(python3 -c "import json; d=json.load(open('$DREAM_STATE')); print(d.get('last_dream_time',''))")
        THRESHOLD=$(python3 -c "import json; d=json.load(open('$DREAM_STATE')); print(d.get('cumulative_threshold', 30))")
    else
        LAST_TIME=""; THRESHOLD=30
    fi
    echo "✅ Dream state: last=$LAST_TIME threshold=$THRESHOLD"
    exit 0
fi

# --- Phase 1: ORIENT ---
echo "📍 Phase 1: ORIENT" >> "$LOG_FILE"
MEMORY_CONTENT=$(cat "$WORKSPACE_MAIN/MEMORY.md" 2>/dev/null || echo "(未找到)")
TOPIC_FILES=""
for f in "$WORKSPACE_MAIN"/memory/*.md; do
    [ -f "$f" ] && TOPIC_FILES+="--- $(basename $f) ---\n$(head -30 "$f")\n\n"
done

# --- Phase 2: GATHER ---
echo "🔍 Phase 2: GATHER" >> "$LOG_FILE"
TRANSCRIPT_FILE="/tmp/autodream-transcript-$(date '+%Y%m%d').md"
SCAN_FILE="/tmp/autodream-scan-$(date '+%Y%m%d').md"
STATS_FILE="/tmp/autodream-stats-$(date '+%Y%m%d').json"

python3 "$SCRIPTS_DIR/parse-sessions.py" ~/.openclaw/agents "$TRANSCRIPT_FILE" transcript 2>> "$LOG_FILE"
SESSION_TRANSCRIPT=$(cat "$TRANSCRIPT_FILE" 2>/dev/null || echo "(无会话)")
python3 "$SCRIPTS_DIR/parse-sessions.py" ~/.openclaw/agents "$SCAN_FILE" scan 2>> "$LOG_FILE"
SCAN_RESULTS=$(cat "$SCAN_FILE" 2>/dev/null || echo "(无信号)")
python3 "$SCRIPTS_DIR/parse-sessions.py" ~/.openclaw/agents "$STATS_FILE" full 2>/dev/null

EXISTING_PENDING=""
for f in "$WORKSPACE_AUTO_DREAM/memory/pending-changes"/*.md; do
    [ -f "$f" ] && EXISTING_PENDING+="--- $(basename $f) ---\n$(head -10 "$f")\n\n"
done

TASK_CONTENT=$(cat "$WORKSPACE_AUTO_DREAM/auto-dream-task.md")

FULL_TASK="${TASK_CONTENT}

---

## 本次运行元信息

- RUN_DATE: ${RUN_DATE}
- CONTENT_DATE: ${CONTENT_DATE}
- 命名规则：所有输出文件必须使用 CONTENT_DATE 命名；不要使用 RUN_DATE 命名 pending-changes 或 kairos-dream 文件。

---

## Phase 1: ORIENT — 当前 Memory 状态

### MEMORY.md（索引层）

${MEMORY_CONTENT}

### Topic 文件摘要

${TOPIC_FILES}

---

## Phase 2: GATHER — 信号模式匹配结果

${SCAN_RESULTS}

---

## Phase 2: GATHER — 完整对话记录

${SESSION_TRANSCRIPT}

---

## Phase 3: CONSOLIDATE — 已有的 Pending Changes（避免重复）

${EXISTING_PENDING}

---

## Phase 4: PRUNE & INDEX — 待归档检查

请检查 topic 文件中超过 30 天未引用的条目，生成归档提案。

---

## 输出要求

1. 用 4 阶段流程分析：ORIENT → GATHER → CONSOLIDATE → PRUNE
2. 每条变更提案包含来源证据，标注可信度：high/medium/low
3. 变更提案写到 memory/pending-changes/${CONTENT_DATE}.md
4. 分析报告写到 memory/kairos-dream-${CONTENT_DATE}.md"

# --- 触发 auto-dream Agent ---
openclaw agent --agent auto-dream --message "$FULL_TASK" --json >> "$LOG_FILE" 2>&1

# --- 拷贝结果 ---
if [ -f "$WORKSPACE_AUTO_DREAM/memory/pending-changes/$CONTENT_DATE.md" ]; then
    mkdir -p "$WORKSPACE_MAIN/memory/pending-changes"
    cp "$WORKSPACE_AUTO_DREAM/memory/pending-changes/$CONTENT_DATE.md" "$WORKSPACE_MAIN/memory/pending-changes/$CONTENT_DATE.md" 2>/dev/null
    CHANGES=$(grep -c "^## 变更" "$WORKSPACE_AUTO_DREAM/memory/pending-changes/$CONTENT_DATE.md" 2>/dev/null || echo "0")
    echo "📋 待处理变更: $CHANGES 条 | file=$CONTENT_DATE.md" >> "$LOG_FILE"
fi
if [ -f "$WORKSPACE_AUTO_DREAM/memory/kairos-dream-$CONTENT_DATE.md" ]; then
    cp "$WORKSPACE_AUTO_DREAM/memory/kairos-dream-$CONTENT_DATE.md" "$WORKSPACE_MAIN/memory/kairos-dream-$CONTENT_DATE.md" 2>/dev/null
fi

# --- 更新 dream-state.json ---
python3 -c "
import json, os
state_file = '$DREAM_STATE'
if os.path.exists(state_file):
    state = json.load(open(state_file))
else:
    state = {}
state['last_dream_time'] = '$(date '+%Y-%m-%dT%H:%M:%S+08:00')'
state['last_dream_date'] = '$CONTENT_DATE'
state['last_run_date'] = '$RUN_DATE'
state['cumulative_turns'] = 0
with open(state_file, 'w') as f:
    json.dump(state, f, ensure_ascii=False, indent=2)
" 2>/dev/null

# --- 生成 Dashboard ---
python3 "$SCRIPTS_DIR/generate-dashboard.py" 2>/dev/null || true

# --- 清理 ---
rm -f "$TRANSCRIPT_FILE" "$SCAN_FILE" "$STATS_FILE"
echo "✅ [$(date '+%Y-%m-%d %H:%M:%S')] AutoDream v3 完成" >> "$LOG_FILE"
TRIGGER_EOF
chmod +x "$SCRIPTS_DIR/trigger-auto-dream.sh"
echo "  trigger-auto-dream.sh"
success "写入 trigger-auto-dream.sh"

# --- generate-dashboard.py ---
cat > "$SCRIPTS_DIR/generate-dashboard.py" << 'DASH_EOF'
#!/usr/bin/env python3
"""AutoDream Dashboard Generator"""
import json, os
from datetime import datetime
from pathlib import Path

WORKSPACE = os.path.expanduser("~/.openclaw/workspace")
DREAM_STATE_FILE = f"{WORKSPACE}/memory/dream-state.json"
MEMORY_DIR = f"{WORKSPACE}/memory"
OUTPUT_FILE = f"{WORKSPACE}/memory/dream-dashboard.html"

def load_dream_state():
    if os.path.exists(DREAM_STATE_FILE):
        with open(DREAM_STATE_FILE) as f: return json.load(f)
    return {}

def load_memory_files():
    files = {}
    for f in Path(MEMORY_DIR).glob("*.md"):
        if f.name == "dream-dashboard.html": continue
        with open(f) as fp:
            content = fp.read()
            files[f.name] = {"lines": len(content.splitlines()), "words": len(content.split()), "preview": content[:200].replace("\n", " ")}
    pending_dir = f"{MEMORY_DIR}/pending-changes"
    pending_files = sorted(Path(pending_dir).glob("*.md")) if os.path.exists(pending_dir) else []
    return files, pending_files

def load_dream_logs():
    logs = []
    for f in sorted(Path(MEMORY_DIR).glob("kairos-dream-*.md")):
        with open(f) as fp:
            content = fp.read()
        logs.append({"date": f.name.replace("kairos-dream-","").replace(".md",""), "content": content, "preview": content[:300].replace("\n"," ")})
    return logs

def calculate_health_score(state, files):
    scores = {"freshness":0.0,"coverage":0.0,"coherence":0.0,"efficiency":0.5,"reachability":0.3}
    if not files: return scores, 0.0
    recent = sum(1 for f in files.values() if f["words"] > 100)
    scores["freshness"] = min(1.0, recent / max(1, len(files)))
    scores["coverage"] = sum(1 for f in files.values() if f["words"] > 50) / max(1, len(files))
    scores["coherence"] = sum(1 for f in files.values() if f["lines"] > 5) / max(1, len(files))
    if "MEMORY.md" in files:
        lines = files["MEMORY.md"]["lines"]
        scores["efficiency"] = max(0, 1.0 - (lines - 50) / 150.0)
    topic = [f for f in files if "/" in f or f.startswith("memory/")]
    scores["reachability"] = 0.7 if topic else 0.3
    health = (scores["freshness"]*0.25 + scores["coverage"]*0.25 + scores["coherence"]*0.20 + scores["efficiency"]*0.15 + scores["reachability"]*0.15) * 100
    return scores, health

def h(s):
    if not s: return ""
    return s.replace("&","&amp;").replace("<","&lt;").replace(">","&gt;").replace('"',"&quot;")

def bar(score, color, label):
    pct = round(score * 100)
    return ('<div class="health-item"><div class="health-name">'+label+'</div>'
            '<div class="health-bar-bg"><div class="health-bar-fill" style="width:'+str(pct)+'%;background:'+color+'"></div></div>'
            '<div class="health-val">'+str(pct)+'%</div></div>')

def main():
    state = load_dream_state()
    files, pending_files = load_memory_files()
    logs = load_dream_logs()
    health_scores, health = calculate_health_score(state, files)
    last_dream = state.get("last_dream_time", "从未")
    total_cycles = state.get("total_dream_cycles", 0)
    threshold = state.get("cumulative_threshold", 30)
    min_interval = state.get("min_interval_hours", 6)
    try:
        if "T" in str(last_dream):
            last_dt = datetime.fromisoformat(str(last_dream).replace("Z","+00:00"))
            hours_since = (datetime.now() - last_dt.replace(tzinfo=None)).total_seconds() / 3600
            hours_str = f"{hours_since:.1f} 小时前"
        else: hours_str = str(last_dream)
    except: hours_str = str(last_dream)
    if health >= 80: hc, hl = "#10B981", "优秀"
    elif health >= 60: hc, hl = "#F59E0B", "良好"
    elif health >= 40: hc, hl = "#EF4444", "一般"
    else: hc, hl = "#6B7280", "需整理"
    gauge_c = 2 * 3.14159 * 60; gauge_o = gauge_c * (1 - health / 100)
    pending_rows = ""; total_pending = 0
    for pf in pending_files:
        with open(pf) as f: content = f.read()
        changes = content.count("## 变更") + content.count("## Change")
        total_pending += changes
        date = pf.name.replace("pending-changes/","").replace(".md","")
        pending_rows += ("<tr onclick=\"t('p-"+date+"')\" style=\"cursor:pointer\">"
            "<td>📋 "+date+"</td><td><span class=\"badge\">"+str(changes)+" 条</span></td>"
            "<td><span class=\"toggle\">▶</span> "+h(content[:200])+"…</td></tr>"
            "<tr id=\"p-"+date+"\" class=\"detail\" style=\"display:none\">"
            "<td colspan=\"3\"><pre>"+h(content[:2000])+"</pre></td></tr>")
    pending_block = ""
    if pending_files:
        pending_block = ("<div class=\"card\"><h3>📋 待处理变更 <span class=\"badge\">"+str(total_pending)+" 条</span></h3>"
                        "<table><thead><tr><th>日期</th><th>条数</th><th>摘要</th></tr></thead>"
                        "<tbody>"+pending_rows+"</tbody></table></div>")
    log_rows = ""
    for log in logs[-10:]:
        date = log["date"]
        log_rows += ("<tr onclick=\"t('l-"+date+"')\" style=\"cursor:pointer\">"
            "<td>🌙 "+date+"</td><td>"+h(log["preview"][:80])+"…</td><td><span class=\"toggle\">▶</span></td></tr>"
            "<tr id=\"l-"+date+"\" class=\"detail\" style=\"display:none\">"
            "<td colspan=\"3\"><pre>"+h(log["content"][:2000])+"</pre></td></tr>")
    log_block = ""
    if logs:
        log_block = ("<div class=\"card\"><h3>🌙 最近 Dream 日志</h3>"
                     "<table><thead><tr><th>日期</th><th>摘要</th><th></th></tr></thead>"
                     "<tbody>"+log_rows+"</tbody></table></div>")
    file_rows = ""
    for name, info in sorted(files.items()):
        size_bar = min(100, info["words"] // 10)
        file_rows += ("<tr onclick=\"t('f-"+h(name)+"')\" style=\"cursor:pointer\">"
            "<td>📄 "+h(name)+"</td><td>"+str(info["lines"])+" 行</td><td>"+str(info["words"])+" 字</td>"
            "<td><div class=\"mini-bar\" style=\"width:"+str(size_bar)+"px\"></div></td><td><span class=\"toggle\">▶</span></td></tr>"
            "<tr id=\"f-"+h(name)+"\" class=\"detail\" style=\"display:none\">"
            "<td colspan=\"5\"><pre>"+h(info["preview"])+"</pre></td></tr>")
    fb = bar(health_scores["freshness"],"#10B981","新鲜度 Freshness")
    cb = bar(health_scores["coverage"],"#38bdf8","覆盖度 Coverage")
    cob = bar(health_scores["coherence"],"#8B5CF6","连通度 Coherence")
    eb = bar(health_scores["efficiency"],"#F59E0B","效率 Efficiency")
    rb = bar(health_scores["reachability"],"#EC4899","可达性 Reachability")
    html = ("<!DOCTYPE html><html lang='zh-CN'><head>"
            "<meta charset='UTF-8'><meta name='viewport' content='width=device-width,initial-scale=1.0'>"
            "<title>🌙 AutoDream Dashboard</title>"
            "<style>"
            "*{margin:0;padding:0;box-sizing:border-box}"
            "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#0f172a;color:#e2e8f0;padding:20px}"
            "h1{color:#e2e8f0;margin-bottom:20px;font-size:1.5rem}"
            "h3{color:#e2e8f0;font-size:1rem;margin-bottom:10px}"
            ".card{background:#1e293b;border-radius:12px;padding:20px;margin-bottom:16px;border:1px solid #334155}"
            ".flex{display:flex;gap:16px;flex-wrap:wrap}"
            ".stat{background:#0f172a;border-radius:8px;padding:16px;flex:1;min-width:140px}"
            ".stat-value{font-size:2rem;font-weight:700;color:#38bdf8}"
            ".stat-label{color:#64748b;font-size:.8rem;margin-top:4px}"
            ".badge{background:#38bdf8;color:#0f172a;padding:2px 8px;border-radius:12px;font-size:.75rem;font-weight:600}"
            ".gauge-wrap{text-align:center;padding:20px}"
            ".gauge{width:160px;height:160px}"
            ".gauge-bg{fill:none;stroke:#334155;stroke-width:12}"
            ".gauge-fill{fill:none;stroke-width:12;stroke-linecap:round;transform:rotate(-90deg);transform-origin:center;transition:stroke-dashoffset 1s ease}"
            ".gauge-text{text-anchor:middle;dominant-baseline:middle;fill:#e2e8f0;font-size:2rem;font-weight:700}"
            ".gauge-sub{text-anchor:middle;fill:#64748b;font-size:.8rem}"
            "table{width:100%;border-collapse:collapse}"
            "th{text-align:left;color:#64748b;font-size:.75rem;padding:8px;border-bottom:1px solid #334155}"
            "td{padding:10px 8px;border-bottom:1px solid #1e293b;font-size:.85rem}"
            "tr:hover td{background:#334155}"
            ".mini-bar{height:6px;background:#38bdf8;border-radius:3px}"
            ".toggle{color:#38bdf8;margin-right:6px}"
            "pre{white-space:pre-wrap;word-break:break-all;font-size:.8rem;color:#94a3b8;max-height:300px;overflow-y:auto;padding:10px;border-radius:6px}"
            ".health-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:12px;margin-top:16px}"
            ".health-item{background:#0f172a;padding:12px;border-radius:8px}"
            ".health-name{color:#64748b;font-size:.75rem;margin-bottom:6px}"
            ".health-bar-bg{height:8px;background:#334155;border-radius:4px;overflow:hidden}"
            ".health-bar-fill{height:100%;border-radius:4px;transition:width .5s}"
            ".health-val{color:#e2e8f0;font-size:.85rem;margin-top:4px;text-align:right}"
            ".next-dream{color:#38bdf8;font-size:.85rem;margin-top:12px}"
            ".formula{color:#64748b;font-size:.8rem;margin-top:12px}"
            "</style></head><body>"
            "<h1>🌙 AutoDream Dashboard</h1>"
            "<div class='flex'>"
            "<div class='stat'><div class='stat-value'>"+str(total_cycles)+"</div><div class='stat-label'>运行次数</div></div>"
            "<div class='stat'><div class='stat-value'>"+str(len(files))+"</div><div class='stat-label'>Memory 文件</div></div>"
            "<div class='stat'><div class='stat-value'>"+str(total_pending)+"</div><div class='stat-label'>待处理变更</div></div>"
            "<div class='stat'><div class='stat-value'>"+str(len(logs))+"</div><div class='stat-label'>Dream 日志</div></div>"
            "</div>"
            "<div class='flex' style='margin-top:16px'>"
            "<div class='card' style='flex:0 0 220px'>"
            "<h3>🏥 Memory 健康度</h3>"
            "<div class='gauge-wrap'>"
            "<svg class='gauge' viewBox='0 0 160 160'>"
            "<circle class='gauge-bg' cx='80' cy='80' r='60'/>"
            "<circle class='gauge-fill' cx='80' cy='80' r='60' stroke='"+hc+"' "
            "stroke-dasharray='"+str(round(gauge_c,2))+"' stroke-dashoffset='"+str(round(gauge_o,2))+"'/>"
            "<text class='gauge-text' x='80' y='68'>"+str(round(health))+"</text>"
            "<text class='gauge-sub' x='80' y='92'>"+hl+"</text>"
            "</svg></div>"
            "<div class='next-dream'>上次运行: "+hours_str+"<br>定时: 每天 03:00</div>"
            "</div>"
            "<div class='card' style='flex:1'>"
            "<h3>📊 5 维健康指标</h3>"
            "<div class='health-grid'>"+fb+cb+cob+eb+rb+"</div>"
            "<div class='formula'>公式: (新鲜度×25% + 覆盖度×25% + 连通度×20% + 效率×15% + 可达性×15%) × 100</div>"
            "</div></div>"
            "<div class='card'><h3>⚙️ 触发配置</h3><table>"
            "<tr><td style='width:200px'>累积触发阈值</td><td>"+str(threshold)+" 轮</td></tr>"
            "<tr><td>最小触发间隔</td><td>"+str(min_interval)+" 小时</td></tr>"
            "<tr><td>定时触发</td><td>每天 03:00</td></tr>"
            "<tr><td>最后运行</td><td>"+h(str(last_dream))+"</td></tr>"
            "</table></div>"
            +pending_block+log_block+
            "<div class='card'><h3>📄 Memory 文件</h3>"
            "<table><thead><tr><th>文件名</th><th>行数</th><th>字数</th><th>大小</th><th></th></tr></thead>"
            "<tbody>"+file_rows+"</tbody></table></div>"
            "<script>"
            "function t(id){var el=document.getElementById(id);el.style.display=el.style.display==='none'?'table-row':'none';}"
            "setTimeout(function(){location.reload();},30000);"
            "</script></body></html>")
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f: f.write(html)
    print(f"Generated: {OUTPUT_FILE}")
    print(f"Health: {health:.0f}/100 | Files: {len(files)} | Pending: {total_pending} | Logs: {len(logs)}")

if __name__ == "__main__": main()
DASH_EOF
chmod +x "$SCRIPTS_DIR/generate-dashboard.py"
echo "  generate-dashboard.py"
success "写入 generate-dashboard.py"

# --- dream-state.json ---
python3 -c "
import json, os
path = os.path.expanduser('~/.openclaw/workspace/memory/dream-state.json')
if os.path.exists(path):
    print('SKIP')
else:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    state = {
        'last_dream_time': '2026-04-04T03:00:00+08:00',
        'last_dream_date': '2026-04-04',
        'cumulative_turns': 0,
        'cumulative_threshold': 30,
        'min_interval_hours': 6,
        'total_dream_cycles': 0,
        'health_score': None,
        'last_health_check': None
    }
    with open(path, 'w') as f:
        json.dump(state, f, ensure_ascii=False, indent=2)
    print('CREATED')
" 2>&1
DREAM_STATE_RESULT=$?
if [ $DREAM_STATE_RESULT -eq 0 ]; then
    echo "  dream-state.json"
    success "dream-state.json 就绪"
else
    warn "dream-state.json 可能已存在或其他问题"
fi

#===============================================================================
# 第 4 步：配置 openclaw.json（追加 auto-dream Agent）
#===============================================================================
step "4. 配置 openclaw.json"

# 检查 auto-dream 是否已存在，并决定是否追加
AUTO_DREAM_CHECK=$(python3 -c "
import json, os, sys

json_path = os.path.expanduser('~/.openclaw/openclaw.json')
with open(json_path) as f:
    cfg = json.load(f)

agents_list = cfg.get('agents', {}).get('list', [])

if any(a.get('id') == 'auto-dream' for a in agents_list):
    print('SKIP')
    sys.exit(0)

# 需要追加
auto_dream_agent = {
    'id': 'auto-dream',
    'name': 'AutoDream',
    'workspace': os.path.expanduser('~/.openclaw/workspace-auto-dream'),
    'identity': {'name': 'AutoDream', 'emoji': '🌙'},
    'tools': {
        'allow': ['read', 'edit', 'write', 'session_status'],
        'deny': [
            'exec', 'browser', 'process', 'message', 'subagents',
            'sessions_spawn', 'sessions_send', 'sessions_list',
            'sessions_history', 'sessions_yield', 'canvas', 'pdf',
            'image', 'image_generate', 'web_search', 'web_fetch',
            'tts', 'feishu_doc', 'feishu_wiki', 'feishu_drive',
            'feishu_bitable', 'feishu_chat', 'feishu_app_scopes'
        ]
    }
}

agents_list.append(auto_dream_agent)
with open(json_path, 'w') as f:
    json.dump(cfg, f, ensure_ascii=False, indent=2)
print('ADDED')
" 2>&1)

if [ "$AUTO_DREAM_CHECK" = "SKIP" ]; then
    success "auto-dream Agent 已存在，跳过"
elif [ "$AUTO_DREAM_CHECK" = "ADDED" ]; then
    success "auto-dream Agent 已追加到 openclaw.json"
else
    error "配置 openclaw.json 失败:\n$AUTO_DREAM_CHECK"
fi

#===============================================================================
# 第 5 步：配置 launchd 定时任务
#===============================================================================
step "5. 配置 macOS launchd 定时任务"

if [ -f "$LAUNCHD_PLIST" ]; then
    success "launchd plist 已存在，跳过"
else
    mkdir -p "$(dirname "$LAUNCHD_PLIST")"
    cat > "$LAUNCHD_PLIST" << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.openclaw.auto-dream</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>__SCRIPT_PATH__</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>3</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>__LOG_OUT__</string>
    <key>StandardErrorPath</key>
    <string>__LOG_ERR__</string>
</dict>
</plist>
PLIST_EOF

    # 替换占位符
    sed -i '' "s|__SCRIPT_PATH__|${SCRIPTS_DIR}/trigger-auto-dream.sh|g" "$LAUNCHD_PLIST"
    sed -i '' "s|__LOG_OUT__|${LOG_DIR}/auto-dream.log|g" "$LAUNCHD_PLIST"
    sed -i '' "s|__LOG_ERR__|${LOG_DIR}/auto-dream.err|g" "$LAUNCHD_PLIST"

    info "加载 launchd 服务..."
    if launchctl load "$LAUNCHD_PLIST" 2>/dev/null; then
        success "launchd 服务已加载"
    else
        warn "launchd load 失败（可能需要用户授权），可稍后运行: launchctl load $LAUNCHD_PLIST"
    fi
fi

#===============================================================================
# 第 6 步：打印完成信息
#===============================================================================
echo ""
echo "========================================"
echo -e "${GREEN}${BOLD}✅ AutoDream 安装完成！${NC}"
echo "========================================"
echo ""
echo -e "${BOLD}需要手动确认的步骤（2步）：${NC}"
echo ""
echo -e "  ${YELLOW}①${NC} 重启 Gateway（使 auto-dream Agent 生效）："
echo -e "     ${CYAN}openclaw gateway restart${NC}"
echo ""
echo -e "  ${YELLOW}②${NC} 更新主 Agent 的 AGENTS.md（启动时检查 pending-changes）："
echo -e "     在 AGENTS.md 的 ## Every Session 部分添加："
echo ""
echo '     ## AutoDream 启动检查'
echo '     每次会话开始时，检查 memory/pending-changes/ 目录：'
echo '     1. 列出所有 .md 文件'
echo '     2. 如有内容，读取并向用户展示待处理变更摘要'
echo '     3. 请用户确认要执行哪些变更'
echo '     4. 执行确认的变更后，删除该 pending 文件'
echo ""
echo -e "${BOLD}可选：${NC}"
echo -e "  ${CYAN}openclaw gateway restart${NC}  # 使 auto-dream Agent 生效"
echo ""
echo -e "${BOLD}验证安装：${NC}"
echo -e "  ${CYAN}bash $SCRIPTS_DIR/trigger-auto-dream.sh --check-only${NC}   # 检查状态"
echo -e "  ${CYAN}python3 $SCRIPTS_DIR/parse-sessions.py 2>/dev/null | python3 -c 'import sys,json; d=json.load(sys.stdin); print(f\"Agent: {d[\"agents\"]}, 消息: {d[\"messages\"]}, 信号: {d[\"findings\"]}\")'${NC}"
echo ""
echo -e "${BOLD}查看 Dashboard：${NC}"
echo -e "  打开浏览器: ${HOME_DIR}/.openclaw/workspace/memory/dream-dashboard.html"
echo ""
