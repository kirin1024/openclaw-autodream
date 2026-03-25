#!/bin/bash
# 股票监控定时任务 - 每5分钟执行一次

SCRIPT_DIR="/Users/Alika/.openclaw/workspace/scripts"
LOG_FILE="/Users/Alika/.openclaw/workspace/scripts/monitor.log"

cd $SCRIPT_DIR

# 执行监控脚本
node stock-monitor.js >> $LOG_FILE 2>&1
