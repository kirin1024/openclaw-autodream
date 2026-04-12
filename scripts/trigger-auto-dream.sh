#!/bin/bash
# AutoDream trigger script v4 — 4阶段流程 + grep模式匹配 + 累积触发 + Session健康检查
WORKSPACE_MAIN="$HOME/.openclaw/workspace"
WORKSPACE_AUTO_DREAM="$HOME/.openclaw/workspace-auto-dream"
LOG_DIR="$WORKSPACE_MAIN/scripts/logs"
LOG_FILE="$LOG_DIR/auto-dream.log"
SCRIPTS_DIR="$WORKSPACE_MAIN/scripts"
DREAM_STATE="$WORKSPACE_MAIN/memory/dream-state.json"
REMINDER_CONFIG="$WORKSPACE_MAIN/memory/autodream-reminder.json"
RUN_DATE=$(date '+%Y-%m-%d')
RUN_HOUR=$(date '+%H')
TRIGGER_CONTEXT="scheduled"
for arg in "$@"; do
    case "$arg" in
        --manual)
            TRIGGER_CONTEXT="manual"
            ;;
        --scheduled)
            TRIGGER_CONTEXT="scheduled"
            ;;
    esac
done
if [ "$RUN_HOUR" -lt 6 ]; then
    CONTENT_DATE=$(date -v-1d '+%Y-%m-%d')
else
    CONTENT_DATE="$RUN_DATE"
fi
REMINDER_MODE=$(python3 - <<PY 2>/dev/null
import json, os
path = os.path.expanduser('$REMINDER_CONFIG')
mode = 'next_user_message'
if os.path.exists(path):
    try:
        with open(path) as f:
            mode = json.load(f).get('mode', mode)
    except Exception:
        pass
print(mode)
PY
)
[ -z "$REMINDER_MODE" ] && REMINDER_MODE="next_user_message"

notify_local() {
    local title="$1"
    local body="$2"
    if command -v osascript >/dev/null 2>&1; then
        osascript -e "display notification \"${body//\"/\\\"}\" with title \"${title//\"/\\\"}\"" >/dev/null 2>&1 || true
    fi
}

print_pending_summary() {
    local count="$1"
    local file="$2"
    echo ""
    echo "📋 AutoDream 待确认变更：${count} 条"
    echo "   文件：${file}"
    echo "   归整日期：${CONTENT_DATE}"
    echo "   提醒模式：${REMINDER_MODE}"
    echo ""
}

mkdir -p "$LOG_DIR"
echo "🌙 [$(date '+%Y-%m-%d %H:%M:%S')] AutoDream triggered (v3) | run_date=$RUN_DATE content_date=$CONTENT_DATE reminder_mode=$REMINDER_MODE trigger_context=$TRIGGER_CONTEXT" >> "$LOG_FILE"

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
CONTINUITY_CONTENT=$(cat "$WORKSPACE_AUTO_DREAM/dream-continuity.md" 2>/dev/null || echo "(无 continuity 文件，正常启动)")

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
4. 分析报告写到 memory/kairos-dream-${CONTENT_DATE}.md

## Continuity 参考（Session Reset 恢复信息）

${CONTINUITY_CONTENT}

> 如果 dream-continuity.md 存在，先读取它并参考其中的结论，再开始分析。"

# --- Phase X: Session 健康检查 ---
SESSION_DIR="$HOME/.openclaw/agents/auto-dream/sessions"
CONTINUITY_FILE="$WORKSPACE_AUTO_DREAM/dream-continuity.md"

# 统计当前 session 大小（不含 .reset.* 文件）
total_size=$(find "$SESSION_DIR" -name "*.jsonl" -not -name "*.reset.*" -exec du -k {} + 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
echo "📊 [Session Health] auto-dream session size: ${total_size}KB" >> "$LOG_FILE"

if [ "$total_size" -gt 5000 ]; then
    echo "⚠️ [Session Health] session 超过 5MB (${total_size}KB)，触发 reset" >> "$LOG_FILE"

    # 提取上次的 dream-state 关键信息写入 continuity 文件
    python3 - "$DREAM_STATE" "$CONTINUITY_FILE" "$CONTENT_DATE" "$total_size" << 'PYEOF'
import json, sys, os
state_file, continuity_file, last_date, session_kb = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

if os.path.exists(state_file):
    state = json.load(open(state_file))
    total_cycles = state.get('total_dream_cycles', 0)
    last_dream_time = state.get('last_dream_time', 'unknown')
else:
    total_cycles, last_dream_time = 0, 'unknown'

content = f"""# Dream Continuity — Last State

> ⚠️ 此文件由 trigger-auto-dream.sh 自动生成。Reset 后 auto-dream Agent 读此文件恢复关键上下文。

## 上次运行信息
- 最后成功运行: {last_dream_time}
- 总运行次数: {total_cycles}
- Session 大小触发 reset: {session_kb}KB
- Reset 日期: {last_date}

## 重要结论（从上次 pending-changes 提取）
请从 memory/pending-changes/{last_date}.md 中提取 HIGH 可信度的变更结论，写入下方：

暂无（如果 pending 文件为空或只有低可信度变更）

## 注意事项
- 本文件在每次 session reset 后由 trigger-auto-dream.sh 自动生成
- auto-dream Agent 启动时应首先读取并参考此文件
"""

os.makedirs(os.path.dirname(continuity_file), exist_ok=True)
with open(continuity_file, 'w') as f:
    f.write(content)
print(f"✅ continuity 文件已写入: {continuity_file}")
PYEOF

    # 通知 gateway 压缩 session（创建 reset 标记文件）
    reset_ts=$(date '+%Y-%m-%dT%H-%M-%S')
    touch "$SESSION_DIR/session.reset.${reset_ts}.triggered"
    echo "🧹 [Session Health] reset 标记已创建: session.reset.${reset_ts}.triggered" >> "$LOG_FILE"
fi

# --- 重新读取 continuity（Phase X 可能刚创建了新文件）---
CONTINUITY_FINAL=$(cat "$WORKSPACE_AUTO_DREAM/dream-continuity.md" 2>/dev/null || echo "(无 continuity 文件)")

# --- 追加 continuity 到任务消息 ---
CONTINUITY_APPEND="## Continuity 参考（Session Reset 恢复信息）\n\n${CONTINUITY_FINAL}\n\n> 如果 dream-continuity.md 存在，先读取它并参考其中的结论，再开始分析。"

# --- 触发 auto-dream Agent ---
openclaw agent --agent auto-dream --message "${FULL_TASK}

${CONTINUITY_APPEND}" --json >> "$LOG_FILE" 2>&1

# --- 分发 pending-changes 到各 Agent 的 workspace ---
CHANGES=0
PENDING_FILE="$WORKSPACE_MAIN/memory/pending-changes/$CONTENT_DATE.md"

if [ -f "$WORKSPACE_AUTO_DREAM/memory/pending-changes/$CONTENT_DATE.md" ]; then
    mkdir -p "$WORKSPACE_MAIN/memory/pending-changes"
    cp "$WORKSPACE_AUTO_DREAM/memory/pending-changes/$CONTENT_DATE.md" "$PENDING_FILE" 2>/dev/null
    CHANGES=$(grep -c "^## 变更" "$WORKSPACE_AUTO_DREAM/memory/pending-changes/$CONTENT_DATE.md" 2>/dev/null || echo "0")
    echo "📋 待处理变更: $CHANGES 条 | file=$CONTENT_DATE.md" >> "$LOG_FILE"

    # --- 按 Target Workspace 分发 pending-changes ---
    echo "📦 [multi-agent] 开始按 Target Workspace 分发..." >> "$LOG_FILE"
    python3 -c '
import re, os, shutil, json, glob

workspace_main = os.path.expanduser("~/.openclaw/workspace")
workspace_auto_dream = os.path.expanduser("~/.openclaw/workspace-auto-dream")
content_date = "'"$CONTENT_DATE"'"
source_file = os.path.join(workspace_auto_dream, "memory", "pending-changes", f"{content_date}.md")

if not os.path.exists(source_file):
    exit(0)

with open(source_file) as f:
    content = f.read()

# 提取每条变更的 Target Workspace
changes = re.split(r"(?=^## Change \d+|变更多\d+：|\*\*Change\*\*\s*\d+：)" , content, flags=re.MULTILINE)

targets = {}
for block in changes:
    match = re.search(r"[Tt]arget [Ww]orkspace[：:]*\s*\S*`?(~\/[^`\s]+)" , block)
    if match:
        target_ws = os.path.expanduser(match.group(1).rstrip("/").strip())
        targets.setdefault(target_ws, []).append(block)
    else:
        targets.setdefault(workspace_main, []).append(block)

for target_ws, blocks in targets.items():
    if target_ws == workspace_main:
        continue  # main 的 pending 已经拷贝了

    target_dir = os.path.join(target_ws, "memory", "pending-changes")
    target_file = os.path.join(target_dir, f"{content_date}.md")
    os.makedirs(target_dir, exist_ok=True)

    # 如果目标已有文件，追加；否则创建
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
    print(f"  ✅ {agent_name}: {len(blocks)} 条变更 → {target_file}")
' 2>&1 >> "$LOG_FILE"
fi

# --- 分发 kairos-dream 分析报告 ---
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
