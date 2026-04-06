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
REMINDER_CONFIG="${MEMORY_DIR}/autodream-reminder.json"
AGENTS_MD="${WORKSPACE_MAIN}/AGENTS.md"
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

# --- 创建主 agent 的 MEMORY.md（如果不存在）---
if [ ! -f "$WORKSPACE_MAIN/MEMORY.md" ]; then
    cat > "$WORKSPACE_MAIN/MEMORY.md" << 'MEMEOF'
# MEMORY.md - Long-term Memory Index

> Auto-created by OpenClaw AutoDream installer

## Topics
MEMEOF
    echo "  $WORKSPACE_MAIN/MEMORY.md (新建)"
fi

# --- 创建默认 memory 目录（如果不存在）---
mkdir -p "$WORKSPACE_MAIN/memory"

# --- 检测已有的子 Agent workspace 并初始化---
for ws in "${OPENCLAW_DIR}"/workspace-*/; do
    [ -d "$ws" ] || continue
    agent_name=$(basename "$ws" | sed 's/^workspace-//')
    mkdir -p "${ws}memory/pending-changes"
    mkdir -p "${ws}memory/daily"
    if [ ! -f "${ws}MEMORY.md" ]; then
        cat > "${ws}MEMORY.md" << 'MEMEOF'
# MEMORY.md - Memory Index (managed by AutoDream)

> Auto-initialized by OpenClaw AutoDream installer

## Topics
MEMEOF
        echo "  ${ws}MEMORY.md (新建)"
    fi
    echo "  ${ws}memory/pending-changes/"
done
echo "  $WORKSPACE_AUTO_DREAM/memory/pending-changes/"
echo "  $SCRIPTS_DIR/logs/"
echo "  $MEMORY_PENDING/"
echo "  $SKILL_DIR/"
success "目录结构创建完成"

#===============================================================================
# 第 3 步：配置提醒时机
#===============================================================================
step "3. 配置提醒时机"
echo ""
echo "请选择 AutoDream 生成 pending-changes 后的提醒时机："
echo "  1) 手动触发完，当前终端立即提醒"
echo "  2) 每天定时触发完成后提醒（macOS 本地通知）"
echo "  3) 一旦生成 pending，本轮立即提醒（终端 + 本地通知）"
echo "  4) 下一次用户发消息，主 Agent 先检查 pending 再提醒（推荐）"
echo ""
read -r -p "请输入选项 [默认 4]: " REMINDER_CHOICE
case "$REMINDER_CHOICE" in
    1) REMINDER_MODE="manual_after_run"; REMINDER_LABEL="手动触发完立即提醒" ;;
    2) REMINDER_MODE="daily_after_run"; REMINDER_LABEL="每天定时触发完成后提醒" ;;
    3) REMINDER_MODE="immediate_after_pending"; REMINDER_LABEL="生成 pending 后立即提醒" ;;
    4|"") REMINDER_MODE="next_user_message"; REMINDER_LABEL="下一次用户发消息时提醒" ;;
    *) warn "无效选项，已使用默认值 4"; REMINDER_MODE="next_user_message"; REMINDER_LABEL="下一次用户发消息时提醒" ;;
esac

python3 - <<PYCFG
import json, os
path = os.path.expanduser("$REMINDER_CONFIG")
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    json.dump({"mode": "$REMINDER_MODE", "label": "$REMINDER_LABEL"}, f, ensure_ascii=False, indent=2)
PYCFG
success "提醒时机已保存：$REMINDER_LABEL"

if [ "$REMINDER_MODE" = "next_user_message" ] && [ -f "$AGENTS_MD" ]; then
AUTO_PATCH_RESULT=$(python3 - <<PYAGENTS
import os
from pathlib import Path
path = Path(os.path.expanduser("$AGENTS_MD"))
text = path.read_text()
block = """
## AutoDream 启动检查

每次会话开始时，检查 `memory/pending-changes/` 目录：
1. 列出所有 `.md` 文件
2. 如有内容，读取最新一个 pending 文件并向用户展示待处理变更摘要
3. 请用户确认要执行哪些变更（确认 / 拒绝 / 稍后）
4. 在处理 pending 之前，暂停无关任务，除非用户明确要求跳过
"""
if '## AutoDream 启动检查' not in text:
    anchor = "Don't ask permission. Just do it.\n"
    if anchor in text:
        text = text.replace(anchor, anchor + block)
        path.write_text(text)
        print('PATCHED')
    else:
        print('MISSING_ANCHOR')
else:
    print('EXISTS')
PYAGENTS
)
    if [ "$AUTO_PATCH_RESULT" = "PATCHED" ] || [ "$AUTO_PATCH_RESULT" = "EXISTS" ]; then
        success "已自动为主 Agent 接入“下次用户发消息时提醒”规则（若原先不存在）"
    else
        warn "自动 patch AGENTS.md 失败，请按 README 手动添加 AutoDream 启动检查规则"
    fi
fi

#===============================================================================
# 第 4 步：写入核心文件
#===============================================================================
step "4. 写入核心文件"

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
- **Target Workspace**: `~/.openclaw/workspace-AGENT_NAME/`（从来源 Agent 推断，附在提案末尾）
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

**Target Workspace 推断规则**（必须遵守）：
- 来源是 `main session` → `Target Workspace` = `~/.openclaw/workspace/`
- 来源是 `qiwen session` → `Target Workspace` = `~/.openclaw/workspace-qiwen/`
- 来源是其他 Agent → `Target Workspace` = `~/.openclaw/workspace-{agent名称}/`
- 如果信息是多个 Agent 的汇总 → `Target Workspace` = `~/.openclaw/workspace/`（汇总信息归 main）
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
9. **发现敏感信息时的处理** —— 直接忽略，不摘录、不总结、不改写、不做来源证据引用；如果某条提案依赖敏感信息才能成立，则整条提案放弃
TASK_EOF
echo "  auto-dream-task.md"
success "写入 auto-dream-task.md"

# --- parse-sessions.py ---
cat > "$SCRIPTS_DIR/parse-sessions.py" << 'PARSE_EOF'
#!/usr/bin/env python3
"""
AutoDream Session Parser v3 - 4阶段分析流程 + grep模式匹配
用法: python3 parse-sessions.py [agents_dir] [output_file] [mode]
  mode: transcript (默认) | scan | full | semantic
"""
import json, os, sys, re
from datetime import datetime, timedelta
from pathlib import Path

AGENTS_DIR = os.path.expanduser("~/.openclaw/agents")
EXCLUDE_AGENTS = {"auto-dream"}
MAX_LINES_PER_FILE = 30
MAX_RESET_FILES = 20
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
    "外部资源": [r"feishu\.cn/docx/",r"feishu\.cn/base/",r"feishu\.cn/wiki/",r"github\.com/[\w-]+/[\w-]+",r"jira.*browse/[A-Z]+-\d+",r"notion\.so",r"docs\.google\.com",r"dingtalk\.com",r"confluence/"],
    "文件创建": [r"Successfully wrote",r"创建.*文件",r"写入.*\.md",r"写入.*\.json",r"写入.*\.py",r"写入.*\.sh",r"新文件",r"new file",r"created file",r"已创建.*文档",r"已写入.*文件"],
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
        # 先收集24小时内的 reset 文件，按时间排序后取最新的 MAX_RESET_FILES 个
        reset_candidates = []
        for filename in sorted(os.listdir(sessions_path)):
            if ".jsonl.reset." not in filename: continue
            filepath = os.path.join(sessions_path, filename)
            try:
                ts_str = filename.split(".jsonl.reset.")[1]
                ts_str = ts_str.replace("Z", "+00:00")
                parts = ts_str.split("T", 1)
                if len(parts) == 2:
                    ts_str = parts[0] + "T" + parts[1].replace("-", ":", 2)
                reset_dt = datetime.fromisoformat(ts_str)
                if reset_dt.tzinfo:
                    reset_dt = reset_dt.replace(tzinfo=None) + timedelta(hours=8)
                if reset_dt >= cutoff:
                    reset_candidates.append((reset_dt, filepath))
            except (ValueError, IndexError):
                if datetime.fromtimestamp(os.path.getmtime(filepath)) >= cutoff:
                    reset_candidates.append((datetime.fromtimestamp(os.path.getmtime(filepath)), filepath))
        reset_candidates.sort(reverse=True)
        reset_paths = {fp for _, fp in reset_candidates[:MAX_RESET_FILES]}

        for filename in sorted(os.listdir(sessions_path)):
            is_reset = ".jsonl.reset." in filename
            if not (filename.endswith(".jsonl") or is_reset): continue
            filepath = os.path.join(sessions_path, filename)
            if is_reset:
                if filepath not in reset_paths: continue
            else:
                if datetime.fromtimestamp(os.path.getmtime(filepath)) < cutoff: continue
            max_l = MAX_LINES_PER_FILE if mode != "semantic" else 100
            msgs, user_turns, chars = extract_messages(filepath, max_lines=max_l)
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
    elif mode == "semantic":
        # 语义模式：输出完整对话原文，交给 auto-dream Agent 自行判断重要性
        # 不做 grep 过滤，保留全部消息上下文，让 LLM 理解语义
        output = f"# 🧠 GATHER — 语义分析输入（最近 24 小时，自 {cutoff_str}）\n\n"
        output += f"**Agent 数**: {len(session_stats)} | **消息数**: {total_messages} | **用户轮次**: {total_turns}\n\n"
        output += f"**每个文件扫描行数**: 100 行（scan/transcript 模式为 30 行）\n\n"
        output += "**指令**：以下对话由各 Agent 的 session 提取而来。请阅读后自行判断哪些信息值得记录到 memory，包括但不限于：\n"
        output += "- 创建了什么外部资源（飞书文档、GitHub 仓库、文件等）\n"
        output += "- 做了哪些重要决策（即使没有明确的'决定了'措辞）\n"
        output += "- 发现并修复了什么问题\n"
        output += "- 调度了哪些子 Agent 做了什么任务\n"
        output += "- 其他日后可能需要参考的信息\n\n"
        output += "---\n\n" + "\n\n".join(all_conversations)
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

SEMANTIC_FILE="/tmp/autodream-semantic-$(date '+%Y%m%d').md"
python3 "$SCRIPTS_DIR/parse-sessions.py" ~/.openclaw/agents "$SEMANTIC_FILE" semantic 2>> "$LOG_FILE"
SEMANTIC_INPUT=$(cat "$SEMANTIC_FILE" 2>/dev/null || echo "(无语义输入)")

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

## Phase 2: GATHER — grep 信号模式匹配

${SCAN_RESULTS}

## Phase 2: GATHER — 语义分析（LLP 自主判断）

${SEMANTIC_INPUT}

---

## Phase 2: GATHER — 完整对话记录（原始备份）

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

# --- 分发 pending-changes 到各 Agent 的 workspace ---
CHANGES=0
PENDING_FILE="$WORKSPACE_MAIN/memory/pending-changes/$CONTENT_DATE.md"
if [ -f "$WORKSPACE_AUTO_DREAM/memory/pending-changes/$CONTENT_DATE.md" ]; then
    mkdir -p "$WORKSPACE_MAIN/memory/pending-changes"
    cp "$WORKSPACE_AUTO_DREAM/memory/pending-changes/$CONTENT_DATE.md" "$PENDING_FILE" 2>/dev/null
    CHANGES=$(grep -c "^## 变更" "$WORKSPACE_AUTO_DREAM/memory/pending-changes/$CONTENT_DATE.md" 2>/dev/null || echo "0")
    echo "📋 待处理变更: $CHANGES 条 | file=$CONTENT_DATE.md" >> "$LOG_FILE"

    # --- 按 Target Workspace 分发 ---
    echo "📦 [multi-agent] 按 Target Workspace 分发..." >> "$LOG_FILE"
    python3 - "$CONTENT_DATE" <<'PYDISTRIBUTE'
import re, os, sys

workspace_main = os.path.expanduser("~/.openclaw/workspace")
workspace_auto_dream = os.path.expanduser("~/.openclaw/workspace-auto-dream")

content_date = sys.argv[1]
if not content_date:
    exit(0)

source_file = os.path.join(workspace_auto_dream, "memory", "pending-changes", f"{content_date}.md")
if not os.path.exists(source_file):
    exit(0)

with open(source_file) as f:
    content = f.read()

# 提取每条变更的 Target Workspace
changes = re.split(r"(?=^## \w*Change \d+|## 变更多\d+：|\*\*Change\*\*\s*\d+：)", content, flags=re.MULTILINE)

targets = {}
for block in changes:
    match = re.search(r"[Tt]arget [Ww]orkspace[：:]*\s*\S*`?(~\/[^`\s]+)", block)
    if match:
        target_ws = os.path.expanduser(match.group(1).rstrip("/").strip())
        targets.setdefault(target_ws, []).append(block)
    else:
        targets.setdefault(workspace_main, []).append(block)

for target_ws, blocks in targets.items():
    if target_ws == workspace_main:
        continue  # main 已经拷贝过了

    target_dir = os.path.join(target_ws, "memory", "pending-changes")
    target_file = os.path.join(target_dir, f"{content_date}.md")
    os.makedirs(target_dir, exist_ok=True)

    if os.path.exists(target_file):
        with open(target_file) as f:
            existing = f.read()
    else:
        existing = f"# Pending Changes (from AutoDream) — {content_date}\n\n"

    new_content = existing
    for block in blocks:
        if block.strip() and block.strip() not in existing:
            new_content += block + "\n\n"

    with open(target_file, "w") as f:
        f.write(new_content)

    agent_name = os.path.basename(target_ws).replace("workspace-", "")
    print(f"  ✅ {agent_name}: {len(blocks)} 条变更 → pending-changes/")
PYDISTRIBUTE
fi

if [ -f "$WORKSPACE_AUTO_DREAM/memory/kairos-dream-$CONTENT_DATE.md" ]; then
    cp "$WORKSPACE_AUTO_DREAM/memory/kairos-dream-$CONTENT_DATE.md" "$WORKSPACE_MAIN/memory/kairos-dream-$CONTENT_DATE.md" 2>/dev/null
fi

case "$REMINDER_MODE" in
    manual_after_run)
        if [ "$TRIGGER_CONTEXT" = "manual" ] && [ "$CHANGES" -gt 0 ]; then
            print_pending_summary "$CHANGES" "$PENDING_FILE"
        fi
        ;;
    daily_after_run)
        if [ "$TRIGGER_CONTEXT" = "scheduled" ] && [ "$CHANGES" -gt 0 ]; then
            notify_local "AutoDream 已完成" "${CONTENT_DATE} 有 ${CHANGES} 条待确认变更"
        fi
        ;;
    immediate_after_pending)
        if [ "$CHANGES" -gt 0 ]; then
            print_pending_summary "$CHANGES" "$PENDING_FILE"
            notify_local "AutoDream 待确认变更" "${CONTENT_DATE} 有 ${CHANGES} 条待确认变更"
        fi
        ;;
    next_user_message|*)
        echo "⏭️ 待提醒：下次用户发消息时检查 pending-changes" >> "$LOG_FILE"
        ;;
esac

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
if ! python3 "$SCRIPTS_DIR/generate-dashboard.py" >> "$LOG_FILE" 2>&1; then
    echo "⚠️ [$(date '+%Y-%m-%d %H:%M:%S')] Dashboard 生成失败" >> "$LOG_FILE"
fi

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
"""AutoDream Dashboard Generator — v2 with multi-agent support"""
import json, os
from datetime import datetime
from pathlib import Path

WORKSPACE = os.path.expanduser("~/.openclaw/workspace")
OPENCLAW_DIR = os.path.expanduser("~/.openclaw")
DREAM_STATE_FILE = f"{WORKSPACE}/memory/dream-state.json"
MEMORY_DIR = f"{WORKSPACE}/memory"
OUTPUT_FILE = f"{WORKSPACE}/memory/dream-dashboard.html"

# --- Multi-agent discovery ---
def discover_agents():
    """发现所有子 agent 的 workspace"""
    agents = {"main": {"dir": WORKSPACE, "emoji": "🏠"}}
    for d in sorted(Path(OPENCLAW_DIR).glob("workspace-*")):
        if d.name == "workspace-auto-dream":
            continue  # auto-dream 不在 dashboard 展示
        name = d.name.replace("workspace-", "")
        agents[name] = {"dir": str(d), "emoji": "🤖"}
    return agents

def scan_agent_memory(agent_name, agent_dir):
    """扫描一个 agent 的 memory 状态"""
    memory_dir = os.path.join(agent_dir, "memory")
    memory_md = os.path.join(agent_dir, "MEMORY.md")
    
    # Topic files
    topic_files = []
    if os.path.exists(memory_dir):
        for f in sorted(Path(memory_dir).rglob("*.md")):
            rel = str(f.relative_to(memory_dir))
            with open(f) as fp:
                content = fp.read()
            topic_files.append({
                "name": rel,
                "path": str(f),
                "lines": len(content.splitlines()),
                "words": len(content.split()),
                "mtime": os.path.getmtime(f),
                "preview": content[:300].replace("\n", " "),
                "size_kb": os.path.getsize(f) / 1024
            })
    
    # Pending changes
    pending_dir = os.path.join(memory_dir, "pending-changes")
    pending_files = []
    total_pending = 0
    if os.path.exists(pending_dir):
        for pf in sorted(Path(pending_dir).glob("*.md")):
            with open(pf) as fp:
                content = fp.read()
            changes = content.count("## 变更") + content.count("## Change")
            total_pending += changes
            pending_files.append({
                "name": pf.name,
                "date": pf.name.replace(".md", ""),
                "changes": changes,
                "preview": content[:200].replace("\n", " ")
            })
    
    # MEMORY.md
    has_index = os.path.exists(memory_md)
    if has_index:
        with open(memory_md) as f:
            index_lines = len(f.readlines())
    else:
        index_lines = 0
    
    # 计算每日新增（基于 mtime）
    today = datetime.now().date()
    daily_new = []
    for tf in topic_files:
        mtime = datetime.fromtimestamp(tf["mtime"]).date()
        if mtime == today:
            daily_new.append(tf)
    
    return {
        "topic_files": topic_files,
        "pending_files": pending_files,
        "total_pending": total_pending,
        "has_index": has_index,
        "index_lines": index_lines,
        "daily_new": daily_new,
        "file_count": len(topic_files)
    }

def load_dream_state():
    if os.path.exists(DREAM_STATE_FILE):
        with open(DREAM_STATE_FILE) as f: return json.load(f)
    return {}

def load_dream_logs():
    logs = []
    for f in sorted(Path(MEMORY_DIR).glob("kairos-dream-*.md")):
        with open(f) as fp:
            content = fp.read()
        logs.append({"date": f.name.replace("kairos-dream-","").replace(".md",""), "content": content, "preview": content[:300].replace("\n"," ")})
    return logs

def calculate_health_score(agent_data):
    """计算某个 agent 的健康度"""
    scores = {"freshness": 0.0, "coverage": 0.0, "coherence": 0.0, "efficiency": 0.5, "reachability": 0.3}
    files = agent_data["topic_files"]
    if not files:
        return scores, 0.0
    recent = sum(1 for f in files if f["words"] > 100)
    scores["freshness"] = min(1.0, recent / max(1, len(files)))
    scores["coverage"] = sum(1 for f in files if f["words"] > 50) / max(1, len(files))
    scores["coherence"] = sum(1 for f in files if f["lines"] > 5) / max(1, len(files))
    if agent_data["has_index"]:
        scores["efficiency"] = max(0, 1.0 - (agent_data["index_lines"] - 50) / 150.0)
    scores["reachability"] = 0.7 if files else 0.3
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
    agents = discover_agents()
    logs = load_dream_logs()
    
    # 扫描所有 agent
    agent_data = {}
    for name, info in agents.items():
        agent_data[name] = scan_agent_memory(name, info["dir"])
    
    last_dream = state.get("last_dream_time", "从未")
    total_cycles = state.get("total_dream_cycles", 0)
    
    # --- Agent 卡片 ---
    agent_cards_html = ""
    agent_summary_data = []  # 用于总结
    
    for name, info in agents.items():
        data = agent_data[name]
        emoji = info["emoji"]
        scores, health = calculate_health_score(data)
        
        if health >= 80: hc, hl = "#10B981", "优秀"
        elif health >= 60: hc, hl = "#F59E0B", "良好"
        elif health >= 40: hc, hl = "#EF4444", "一般"
        else: hc, hl = "#6B7280", "需整理"
        
        # 今日新增
        daily_new_count = len(data["daily_new"])
        daily_new_html = ""
        if daily_new_count > 0:
            for f in data["daily_new"]:
                daily_new_html += f'<div class="daily-item">📄 {h(f["name"])} ({f["lines"]}行)</div>'
        
        # 待处理变更
        pending_html = ""
        if data["pending_files"]:
            for pf in data["pending_files"]:
                pending_html += (f'<tr onclick="t(\'p-{name}-{pf["date"]}\')" style="cursor:pointer">'
                    f'<td>📋 {pf["date"]}</td><td><span class="badge">{pf["changes"]} 条</span></td>'
                    f'<td><span class="toggle">▶</span> {h(pf["preview"][:100])}…</td></tr>'
                    f'<tr id="p-{name}-{pf["date"]}" class="detail" style="display:none">'
                    f'<td colspan="3"><pre>{h(pending_html[:2000]) if pending_html else ""}</pre></td></tr>')
        
        # 记忆文件列表（最近修改的前 5 个）
        recent_files = sorted(data["topic_files"], key=lambda x: x["mtime"], reverse=True)[:5]
        files_html = ""
        for f in recent_files:
            age_days = (datetime.now().timestamp() - f["mtime"]) / 86400
            if age_days < 1:
                age_label = "今天"
            elif age_days < 7:
                age_label = f"{int(age_days)}天前"
            else:
                age_label = f"{int(age_days)}天前"
            size_bar = min(100, f["words"] // 10)
            files_html += (f'<tr><td>📄 {h(f["name"])}</td><td>{f["lines"]} 行</td>'
                f'<td>{age_label}</td>'
                f'<td><div class="mini-bar" style="width:{size_bar}px"></div></td></tr>')
        
        # Pending section and files section
        pending_section = "<div class='section-title'>📋 待处理变更</div><table><thead><tr><th>日期</th><th>条数</th><th>摘要</th></tr></thead><tbody>" + pending_html + "</tbody></table>"
        files_section = "<div class='section-title'>📄 最近修改的记忆文件</div><table><thead><tr><th>文件</th><th>行数</th><th>时间</th><th>大小</th></tr></thead><tbody>" + files_html + "</tbody></table>"
        
        # 5维指标
        fb = bar(scores["freshness"], "#10B981", "新鲜度")
        cb = bar(scores["coverage"], "#38bdf8", "覆盖度")
        cob = bar(scores["coherence"], "#8B5CF6", "连通度")
        eb = bar(scores["efficiency"], "#F59E0B", "效率")
        rb = bar(scores["reachability"], "#EC4899", "可达性")
        
        gauge_c = 2 * 3.14159 * 60
        gauge_o = gauge_c * (1 - health / 100)
        
        agent_cards_html += f'''
        <div class="agent-card">
            <div class="agent-header">
                <span class="agent-emoji">{emoji}</span>
                <h3>{name}</h3>
                <span class="badge health-badge" style="background:{hc}">{hl} {round(health)}分</span>
            </div>
            <div class="agent-stats">
                <div class="mini-stat">
                    <div class="mini-stat-value">{data["file_count"]}</div>
                    <div class="mini-stat-label">记忆文件</div>
                </div>
                <div class="mini-stat">
                    <div class="mini-stat-value">{data["total_pending"]}</div>
                    <div class="mini-stat-label">待处理</div>
                </div>
                <div class="mini-stat">
                    <div class="mini-stat-value">{daily_new_count}</div>
                    <div class="mini-stat-label">今日新增</div>
                </div>
            </div>
            {"" if not daily_new_html else f'<div class="daily-section"><div class="section-title">📅 今日新增</div>{daily_new_html}</div>'}
            {pending_section if data["pending_files"] else ""}
            {files_section if recent_files else "<div class='empty-state'>暂无记忆文件</div>"}
            <div class="health-section">
                <div class="section-title">📊 5 维健康指标</div>
                <div class="health-grid">{fb}{cb}{cob}{eb}{rb}</div>
            </div>
        </div>'''
        
        agent_summary_data.append({
            "name": name,
            "emoji": emoji,
            "file_count": data["file_count"],
            "pending": data["total_pending"],
            "daily_new": daily_new_count,
            "health": round(health)
        })
    
    # --- 主 Dashboard ---
    try:
        if "T" in str(last_dream):
            last_dt = datetime.fromisoformat(str(last_dream).replace("Z","+00:00"))
            hours_since = (datetime.now() - last_dt.replace(tzinfo=None)).total_seconds() / 3600
            hours_str = f"{hours_since:.1f} 小时前"
        else: hours_str = str(last_dream)
    except: hours_str = str(last_dream)
    
    total_files = sum(d["file_count"] for d in agent_data.values())
    total_pending = sum(d["total_pending"] for d in agent_data.values())
    
    html = ("<!DOCTYPE html><html lang='zh-CN'><head>"
            "<meta charset='UTF-8'><meta name='viewport' content='width=device-width,initial-scale=1.0'>"
            "<title>🌙 AutoDream Dashboard</title>"
            "<style>"
            "*{margin:0;padding:0;box-sizing:border-box}"
            "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#0f172a;color:#e2e8f0;padding:20px}"
            "h1{color:#e2e8f0;margin-bottom:20px;font-size:1.5rem}"
            "h3{color:#e2e8f0;font-size:1rem;margin-bottom:10px}"
            ".card,.agent-card{background:#1e293b;border-radius:12px;padding:20px;margin-bottom:16px;border:1px solid #334155}"
            ".flex{display:flex;gap:16px;flex-wrap:wrap}"
            ".stat{background:#0f172a;border-radius:8px;padding:16px;flex:1;min-width:140px}"
            ".stat-value{font-size:2rem;font-weight:700;color:#38bdf8}"
            ".stat-label{color:#64748b;font-size:.8rem;margin-top:4px}"
            ".badge{background:#38bdf8;color:#0f172a;padding:2px 8px;border-radius:12px;font-size:.75rem;font-weight:600}"
            ".agent-header{display:flex;align-items:center;gap:10px;margin-bottom:16px}"
            ".agent-emoji{font-size:1.5rem}"
            ".health-badge{margin-left:auto}"
            ".agent-stats{display:flex;gap:12px;margin-bottom:16px}"
            ".mini-stat{background:#0f172a;padding:10px;border-radius:8px;flex:1;text-align:center}"
            ".mini-stat-value{font-size:1.2rem;font-weight:700;color:#38bdf8}"
            ".mini-stat-label{font-size:.7rem;color:#64748b;margin-top:2px}"
            ".daily-section{margin-bottom:12px}"
            ".daily-item{background:#0f172a;padding:6px 10px;border-radius:6px;font-size:.8rem;margin-bottom:4px;color:#10B981}"
            ".section-title{color:#64748b;font-size:.8rem;font-weight:600;margin-bottom:8px;margin-top:12px}"
            ".empty-state{color:#64748b;font-size:.8rem;text-align:center;padding:20px}"
            ".health-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(100px,1fr));gap:8px}"
            ".health-item{background:#0f172a;padding:8px;border-radius:6px}"
            ".health-name{color:#64748b;font-size:.7rem;margin-bottom:4px}"
            ".health-bar-bg{height:6px;background:#334155;border-radius:3px;overflow:hidden}"
            ".health-bar-fill{height:100%;border-radius:3px;transition:width .5s}"
            ".health-val{color:#e2e8f0;font-size:.75rem;margin-top:2px;text-align:right}"
            "table{width:100%;border-collapse:collapse}"
            "th{text-align:left;color:#64748b;font-size:.75rem;padding:6px 8px;border-bottom:1px solid #334155}"
            "td{padding:8px;border-bottom:1px solid #1e293b;font-size:.8rem}"
            "tr:hover td{background:#334155}"
            ".mini-bar{height:5px;background:#38bdf8;border-radius:3px}"
            ".toggle{color:#38bdf8;margin-right:6px}"
            "pre{white-space:pre-wrap;word-break:break-all;font-size:.75rem;color:#94a3b8;max-height:200px;overflow-y:auto;padding:8px;border-radius:4px}"
            ".detail td{background:#0f172a}"
            ".health-section{margin-top:12px;border-top:1px solid #334155;padding-top:12px}"
            "</style></head><body>"
            "<h1>🌙 AutoDream Dashboard — 多 Agent 记忆管理</h1>"
            "<div class='flex'>"
            "<div class='stat'><div class='stat-value'>"+str(total_cycles)+"</div><div class='stat-label'>运行次数</div></div>"
            "<div class='stat'><div class='stat-value'>"+str(len(agents))+"</div><div class='stat-label'>Agent 数</div></div>"
            "<div class='stat'><div class='stat-value'>"+str(total_files)+"</div><div class='stat-label'>记忆文件</div></div>"
            "<div class='stat'><div class='stat-value'>"+str(total_pending)+"</div><div class='stat-label'>待处理变更</div></div>"
            "<div class='stat'><div class='stat-value'>"+hours_str+"</div><div class='stat-label'>上次运行</div></div>"
            "</div>"
            "<div class='card'><h3>📊 各 Agent 概览</h3>"
            "<table><thead><tr><th>Agent</th><th>记忆文件</th><th>待处理</th><th>今日新增</th><th>健康度</th></tr></thead><tbody>")
    for d in agent_summary_data:
        html += f"<tr><td>{d['emoji']} {d['name']}</td><td>{d['file_count']}</td><td>{d['pending']}</td><td>{d['daily_new']}</td><td><span class='badge' style='background:{('#10B981' if d['health']>=60 else '#F59E0B' if d['health']>=40 else '#EF4444')}'>{d['health']}分</span></td></tr>"
    html += "</tbody></table></div>"
    html += agent_cards_html
    html += ("<script>"
             "function t(id){var el=document.getElementById(id);el.style.display=el.style.display==='none'?'table-row':'none';}"
             "setTimeout(function(){location.reload();},30000);"
             "</script></body></html>")
    
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        f.write(html)
    
    print(f"Generated: {OUTPUT_FILE}")
    print(f"Agents: {len(agents)} | Files: {total_files} | Pending: {total_pending}")

if __name__ == "__main__":
    main()
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
# 第 5 步：配置 openclaw.json（追加 auto-dream Agent）
#===============================================================================
step "5. 配置 openclaw.json"

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
# 第 6 步：配置 launchd 定时任务
#===============================================================================
step "6. 配置 macOS launchd 定时任务"

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
# 第 7 步：打印完成信息
#===============================================================================
echo ""
echo "========================================"
echo -e "${GREEN}${BOLD}✅ AutoDream 安装完成！${NC}"
echo "========================================"
echo ""
echo -e "${BOLD}需要手动确认的步骤（1步）：${NC}"
echo ""
echo -e "  ${YELLOW}①${NC} 重启 Gateway（使 auto-dream Agent 生效）："
echo -e "     ${CYAN}openclaw gateway restart${NC}"
echo ""
echo -e "${BOLD}已配置的提醒时机：${NC} ${REMINDER_LABEL}"
echo -e "  配置文件：${CYAN}${REMINDER_CONFIG}${NC}"
echo -e "  说明：1/3 适合手动运行时立即反馈，2 适合每日定时提醒，4 适合主 Agent 在下次对话时优先提醒。"
echo ""
echo -e "${BOLD}验证安装：${NC}"
echo -e "  ${CYAN}bash $SCRIPTS_DIR/trigger-auto-dream.sh --check-only${NC}   # 检查状态"
echo -e "  ${CYAN}python3 $SCRIPTS_DIR/parse-sessions.py 2>/dev/null | python3 -c 'import sys,json; d=json.load(sys.stdin); print(f\"Agent: {d[\"agents\"]}, 消息: {d[\"messages\"]}, 信号: {d[\"findings\"]}\")'${NC}"
echo ""
echo -e "${BOLD}查看 Dashboard：${NC}"
echo -e "  打开浏览器: ${HOME_DIR}/.openclaw/workspace/memory/dream-dashboard.html"
echo ""
