/**
 * 股票/基金价格监控服务 V4
 * 修复基金API，多API备用
 */

const https = require('https');
const http = require('http');
const fs = require('fs');
const path = require('path');

// ============ 配置 =============

const STOCKS = {
  '515070': {
    name: 'AI ETF 515070',
    type: 'fund',
    intervals: [
      { min: 1.92, max: 1.95, desc: '区间1' },
      { min: 1.88, max: 1.90, desc: '区间2' },
      { min: 1.95, max: 1.99, desc: '区间3' },
    ]
  },
  '601899': {
    name: '紫金矿业 601899',
    type: 'stock',
    intervals: [
      { min: 36.40, max: 36.60, desc: '区间1' },
      { min: 36.00, max: 36.20, desc: '区间2' },
      { min: 35.50, max: 35.70, desc: '区间3' },
      { min: 36.03, max: 37.23, desc: '大区间' },
    ]
  },
  '159740': {
    name: '恒生科技 ETF 159740',
    type: 'fund',
    intervals: [
      { min: 0.635, max: 0.640, desc: '区间1' },
      { min: 0.620, max: 0.625, desc: '区间2' },
      { min: 0.645, max: 0.653, desc: '区间3' },
    ]
  },
  '513310': {
    name: '513310 半导体',
    type: 'fund',
    intervals: [
      { min: 3.92, max: 3.95, desc: '区间1' },
      { min: 3.88, max: 3.90, desc: '区间2' },
      { min: 3.99, max: 4.02, desc: '区间3' },
    ]
  }
};

const SCRIPT_DIR = '/Users/Alika/.openclaw/workspace/scripts';
const STATE_FILE = path.join(SCRIPT_DIR, 'monitor-state.json');
const LOG_FILE = path.join(SCRIPT_DIR, 'monitor.log');

const CHAT_ID = 'oc_8144de65dd50e1424c2597b0d70fb3ba';
const NOTIFY_USER_ID = 'ou_da03f98d8f609803f95c2bb2205e1323';
const POLL_INTERVAL = 5 * 60 * 1000;

// ============ 多API数据源 ============

/**
 * 东方财富 - 股票API
 */
async function fetchStockFromEastmoney(code) {
  return new Promise((resolve, reject) => {
    const url = `https://push2.eastmoney.com/api/qt/stock/get?secid=1.${code}&fields=f43,f44,f45,f46,f47,f48,f49,f50,f51,f52,f57,f58,f59,f60,f169,f170,f171`;
    const req = https.get(url, { timeout: 10000 }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          if (json.data && json.data.f43) {
            resolve({ source: '东方财富(股票)', price: json.data.f43 / 1000 });
          } else {
            reject(new Error('东方财富股票数据解析失败'));
          }
        } catch (e) {
          reject(e);
        }
      });
    });
    req.on('error', reject);
    req.setTimeout(10000, () => { req.destroy(); reject(new Error('东方财富股票请求超时')); });
  });
}

/**
 * 东方财富 - 基金API (从详情页HTML解析)
 */
async function fetchFundFromEastmoney(code) {
  return new Promise((resolve, reject) => {
    const url = `https://fund.eastmoney.com/${code}.html`;
    const req = https.get(url, { timeout: 15000 }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          // 从HTML中提取单位净值 fix_dwjz
          const match = data.match(/fix_dwjz[^>]*>(\d+\.\d+)</);
          if (match) {
            resolve({ source: '东方财富(基金)', price: parseFloat(match[1]) });
          } else {
            reject(new Error('东方财富基金数据解析失败'));
          }
        } catch (e) {
          reject(e);
        }
      });
    });
    req.on('error', reject);
    req.setTimeout(15000, () => { req.destroy(); reject(new Error('东方财富基金请求超时')); });
  });
}

/**
 * 新浪财经 - 股票API
 */
async function fetchFromSina(code) {
  return new Promise((resolve, reject) => {
    const url = `https://hq.sinajs.cn/list=sh${code}`;
    const req = https.get(url, { timeout: 10000 }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const match = data.match(/="([0-9.]+)"/);
          if (match) {
            resolve({ source: '新浪财经', price: parseFloat(match[1]) });
          } else {
            reject(new Error('新浪数据解析失败'));
          }
        } catch (e) {
          reject(e);
        }
      });
    });
    req.on('error', reject);
    req.setTimeout(10000, () => { req.destroy(); reject(new Error('新浪请求超时')); });
  });
}

/**
 * 网易财经 - 股票API
 */
async function fetchFrom163(code) {
  return new Promise((resolve, reject) => {
    const url = `http://quotes.money.163.com/service/chddata.html?code=0${code}&fields=TCLOSE;HIGH;LOW;TOPEN;LCLOSE;CHG;PCHG;TURNOVER;VOTURNOVER;VATURNOVER`;
    const req = http.get(url, { timeout: 10000 }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const lines = data.trim().split('\n');
          if (lines.length >= 2) {
            const lastRow = lines[lines.length - 1].split(',');
            const price = parseFloat(lastRow[3]);
            if (!isNaN(price)) {
              resolve({ source: '网易财经', price });
            } else {
              reject(new Error('网易数据解析失败'));
            }
          } else {
            reject(new Error('网易无数据'));
          }
        } catch (e) {
          reject(e);
        }
      });
    });
    req.on('error', reject);
    req.setTimeout(10000, () => { req.destroy(); reject(new Error('网易请求超时')); });
  });
}

/**
 * 获取价格 - 尝试多个API
 */
async function fetchPrice(code) {
  const config = STOCKS[code];
  const type = config.type;
  
  const apis = [];
  
  if (type === 'stock') {
    apis.push(() => fetchStockFromEastmoney(code));
    apis.push(() => fetchFromSina(code));
    apis.push(() => fetchFrom163(code));
  } else {
    apis.push(() => fetchFundFromEastmoney(code));
  }
  
  let lastError = null;
  for (const apiFn of apis) {
    try {
      const result = await apiFn();
      return result;
    } catch (e) {
      lastError = e;
      log(`  ${code} API失败: ${e.message}, 尝试下一个...`);
    }
  }
  
  throw new Error(`所有API都失败: ${lastError?.message}`);
}

// ============ 工具函数 ============

function checkIntervals(price, intervals) {
  const triggered = [];
  for (const interval of intervals) {
    if (price >= interval.min && price <= interval.max) {
      triggered.push(interval.desc);
    }
  }
  return triggered;
}

function isTradingTime() {
  const now = new Date();
  const hour = now.getHours();
  const minute = now.getMinutes();
  const day = now.getDay();
  if (day === 0 || day === 6) return false;
  return (
    (hour === 9 && minute >= 30) || 
    (hour >= 10 && hour < 11) || 
    (hour === 11 && minute <= 30) ||
    (hour >= 13 && hour < 15)
  );
}

function isMarketClose() {
  const now = new Date();
  const hour = now.getHours();
  const minute = now.getMinutes();
  const day = now.getDay();
  if (day >= 1 && day <= 5) {
    return hour === 15 && minute >= 0 && minute < 5;
  }
  return false;
}

function getTodayDate() {
  return new Date().toISOString().split('T')[0];
}

function loadState() {
  try {
    if (fs.existsSync(STATE_FILE)) {
      return JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'));
    }
  } catch (e) {}
  return {
    triggered: {},
    dailyTriggered: [],
    lastNotifyTime: null,
    waitingForAck: false,
    notifiedToday: false,
    tradingDay: null
  };
}

function saveState(state) {
  fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
}

function log(msg) {
  const now = new Date().toLocaleString();
  const logMsg = `[${now}] ${msg}`;
  console.log(logMsg);
  fs.appendFileSync(LOG_FILE, logMsg + '\n');
}

// ============ Feishu消息 ============

async function sendMessage(text) {
  const { exec } = require('child_process');
  const cmd = `openclaw message send --channel feishu --target "chat:${CHAT_ID}" --message "${text.replace(/"/g, '\\"')}"`;
  return new Promise((resolve) => {
    exec(cmd, (error) => {
      if (error) log('发送消息失败: ' + error.message);
      resolve();
    });
  });
}

async function sendAtMessage(text) {
  const msg = `${text} <at id=all></at>`;
  await sendMessage(msg);
}

// ============ 主逻辑 ============

let state = loadState();

const today = getTodayDate();
if (state.tradingDay !== today) {
  log('新交易日开始，重置状态');
  state.tradingDay = today;
  state.dailyTriggered = [];
  state.notifiedToday = false;
  state.waitingForAck = false;
  state.lastNotifyTime = null;
  saveState(state);
}

async function checkAll() {
  const now = new Date();
  const hour = now.getHours();
  const minute = now.getMinutes();
  
  if (!isTradingTime()) {
    log('非交易时段，跳过');
    if (isMarketClose()) {
      await sendDailySummary();
    }
    return;
  }
  
  log('开始检查...');
  
  let notifyList = [];
  
  for (const [code, config] of Object.entries(STOCKS)) {
    try {
      const result = await fetchPrice(code);
      const { source, price } = result;
      log(`${config.name}: ${price} (数据源: ${source})`);
      
      const triggeredIntervals = checkIntervals(price, config.intervals);
      
      if (triggeredIntervals.length > 0) {
        const triggerKey = `${code}-${triggeredIntervals.join(',')}`;
        
        if (!state.triggered[triggerKey]) {
          const msg = `【价格提醒】${config.name} 当前价格: ${price}，触发区间: ${triggeredIntervals.join('、')}`;
          notifyList.push(msg);
          state.triggered[triggerKey] = true;
          state.dailyTriggered.push({
            time: now.toLocaleString(),
            name: config.name,
            price,
            intervals: triggeredIntervals
          });
          state.waitingForAck = true;
          state.lastNotifyTime = now.getTime();
          log(`触发通知: ${msg}`);
        } else {
          log(`已通知过，跳过`);
        }
      }
    } catch (e) {
      log(`${config.name} 获取价格失败: ${e.message}`);
    }
  }
  
  saveState(state);
  
  if (notifyList.length > 0) {
    const fullMessage = '\n' + notifyList.join('\n');
    await sendAtMessage(fullMessage);
  }
  
  if (state.waitingForAck && state.lastNotifyTime) {
    const timeSinceLastNotify = Date.now() - state.lastNotifyTime;
    if (timeSinceLastNotify >= POLL_INTERVAL) {
      const retryMsg = '\n【价格提醒】尚未收到回复，每5分钟通知一次，请及时关注！';
      await sendAtMessage(retryMsg);
      state.lastNotifyTime = Date.now();
      saveState(state);
      log('重发通知给帅帅');
    }
  }
}

async function sendMarketOpenNotice() {
  if (!state.notifiedToday) {
    const msg = `【开盘】股票基金监控任务已开始，每5分钟轮询一次，价格触及区间会@帅帅 通知。`;
    await sendMessage(msg);
    state.notifiedToday = true;
    saveState(state);
    log('已发送开盘通知');
  }
}

async function sendDailySummary() {
  const summary = state.dailyTriggered;
  let msg;
  
  if (summary.length > 0) {
    msg = `【收盘】今日监控总结：\n`;
    for (const item of summary) {
      msg += `- ${item.name} ${item.price} (触发 ${item.intervals.join('、')})\n`;
    }
  } else {
    msg = `【收盘】今日监控总结：未触及任何监控区间。`;
  }
  
  await sendMessage(msg);
  state.waitingForAck = false;
  state.notifiedToday = false;
  saveState(state);
  log('已发送收盘总结');
}

// ============ 启动 ============

log('股票监控服务V4已启动 (基金API已修复)');

// 立即执行
(async () => {
  if (isTradingTime()) {
    await sendMarketOpenNotice();
  }
  await checkAll();
})();

setInterval(async () => {
  if (isTradingTime()) {
    await sendMarketOpenNotice();
  }
  await checkAll();
}, POLL_INTERVAL);

setInterval(async () => {
  if (isMarketClose()) {
    await sendDailySummary();
  }
}, 60000);

process.on('SIGINT', () => {
  log('监控服务已停止');
  process.exit(0);
});
