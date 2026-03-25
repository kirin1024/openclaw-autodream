#!/bin/bash

# 帅帅持仓播报脚本
# 每天11点盘中、收盘播报

cd /Users/Alika/.openclaw/workspace

# 读取持仓数据
source memory/shuaishua-holdings.md 2>/dev/null || exit 1

# 播报格式
MESSAGE="📊 帅帅持仓播报\n\n"

# 紫金矿业 (600899)
if [ -n "$ZIJIN_COST" ]; then
    ZIJIN_PRICE=$(curl -s "https://push2.eastmoney.com/api/qt/stock/get?fields=f43,f44,f45,f46,f47,f48,f50,f51,f52,f57&secid=1.600899" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('f43',0))" 2>/dev/null || echo "0")
    if [ "$ZIJIN_PRICE" != "0" ] && [ -n "$ZIJIN_PRICE" ]; then
        ZIJIN_PL=$(echo "scale=2; ($ZIJIN_PRICE - $ZIJIN_COST) * $ZIJIN_QTY" | bc)
        ZIJIN_PL_PCT=$(echo "scale=2; ($ZIJIN_PRICE - $ZIJIN_COST) / $ZIJIN_COST * 100" | bc)
        MESSAGE+="🌕 紫金矿业: 现价 ${ZIJIN_PRICE}元 (成本${ZIJIN_COST})\n"
        MESSAGE+="   持仓${ZIJIN_QTY}股，浮动盈亏: ${ZIJIN_PL}元 (${ZIJIN_PL_Pct}%)\n\n"
    fi
fi

# 白银161226
if [ -n "$BAIYIN_COST" ]; then
    BAIYIN_PRICE=$(curl -s "https://push2.eastmoney.com/api/qt/stock/get?fields=f43,f44,f45,f46,f47,f48,f50,f51,f52,f57&secid=0.161226" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('f43',0))" 2>/dev/null || echo "0")
    if [ "$BAIYIN_PRICE" != "0" ] && [ -n "$BAIYIN_PRICE" ]; then
        BAIYIN_PL=$(echo "scale=2; ($BAIYIN_PRICE - $BAIYIN_COST) * $BAIYIN_QTY" | bc)
        BAIYIN_PL_PCT=$(echo "scale=2; ($BAIYIN_PRICE - $BAIYIN_COST) / $BAIYIN_COST * 100" | bc)
        MESSAGE+="🥈 白银161226: 净值 ${BAIYIN_PRICE}元 (成本${BAIYIN_COST})\n"
        MESSAGE+="   持仓${BAIYIN_QTY}股，浮动盈亏: ${BAIYIN_PL}元 (${BAIYIN_PL_Pct}%)\n\n"
    fi
fi

# 恒生科技指数
if [ -n "$HSTECH_CODE" ]; then
    HSTECH_PRICE=$(curl -s "https://push2.eastmoney.com/api/qt/stock/get?fields=f43,f44,f45,f46,f47,f48,f50,f51,f52,f57&secid=${HSTECH_CODE}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('f43',0))" 2>/dev/null || echo "0")
    if [ "$HSTECH_PRICE" != "0" ] && -n "$HSTECH_PRICE" ]; then
        MESSAGE+="📈 恒生科技: 现价 ${HSTECH_PRICE}元\n"
        MESSAGE+="   (成本和持仓量待补充)\n\n"
    fi
fi

# 发送飞书消息
openclaw message send --channel feishu --target chat:oc_8144de65dd50e1424c2597b0d70fb3ba --message "$MESSAGE"

echo "播报完成: $(date)"
