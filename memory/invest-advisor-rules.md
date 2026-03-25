# 投资顾问 (大金主) 工作规范

## 持仓价格获取规则

**获取LOF/ETF/场内基金价格时，必须使用场内实时价格，不要用基金净值！**

### 正确方法：东方财富股票行情API

```
https://push2.eastmoney.com/api/qt/stock/get?fields=f43&secid=0.161226
```

**参数说明：**
- `secid=0.XXX` → 场内价格（LOF、ETF、港股通等）
- `secid=1.XXX` → A股主板
- `f43` → 当前价格（单位：厘，需要除以1000才是元）

### 常见持仓的secid

| 标的 | 代码 | secid | 备注 |
|------|------|-------|------|
| 紫金矿业 | 600899 | 1.600899 | A股 |
| 白银161226 | 161226 | 0.161226 | LOF场内 |
| 恒生科技 | 513130 | 0.513130 | ETF场内 |

### 备用方案：Yahoo Finance

如果东方财富API不稳定，可以使用浏览器访问 Yahoo Finance 获取数据：

- 恒生科技ETF：https://finance.yahoo.com/quote/513130.SS
- 白银：https://finance.yahoo.com/quote/SI=F （期货）
- 黄金：https://finance.yahoo.com/quote/GC=F （期货）

在页面上找到当前价格（Current Price）字段即可。

### 重要提醒

- 白银161226的场内价格约3.015元，基金净值约2.33元（溢价约30%）
- 播报时要用场内价格，与用户股票软件一致
