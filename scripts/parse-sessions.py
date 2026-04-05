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
    elif mode == "semantic":
        # 语义模式：输出完整对话原文，交给 auto-dream Agent 自行判断重要性
        # 不做 grep 过滤，保留全部消息上下文，让 LLM 理解语义
        output = f"# 🧠 GATHER — 语义分析输入（最近 24 小时，自 {cutoff_str}）\n\n"
        output += f"**Agent 数**: {len(session_stats)} | **消息数**: {total_messages} | **用户轮次**: {total_turns}\n\n"
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
