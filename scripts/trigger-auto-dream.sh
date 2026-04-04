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
