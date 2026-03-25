/**
 * 股票/基金价格监控脚本
 * 每5分钟轮询监控价格，达到目标区间后通知
 * 
 * 监控标的：
 * 1. AI ETF 515070 (基金)
 * 2. 紫金矿业 601899 (股票)
 * 3. 恒生科技 ETF 159740 (基金)
 * 4. 513310 半导体 (基金)
 */

const https = require('https');
const fs = require('fs');
const path = require('path');

// ============ 配置 =============

// 监控标的配置
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
      { min: 36.03, max: 37.23, desc: '大区间' },  // 或关系
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

// 状态文件路径
const STATE_FILE = path.join(__dirname, 'monitor-state.json');

// Feishu通知配置
const FEISHU = {
  // 群ID (当前群)
  chat_id: 'oc_8144de65dd50e1424c2597b0d70fb3ba',
  // 帅帅的user_id
  notify_user_id: 'ou_da03f98d8f609803f95c2bb2205e1323'
};

// ============ 工具函数 =============

/**
 * 获取基金/股票价格 - 使用东方财富API
 */
function fetchPrice(code) {
  return new Promise((resolve, reject) => {
    const isStock = STOCKS[code].type === 'stock';
    let url;
    
    if (isStock) {
      // 股票: sh601899
      url = `https://push2.eastmoney.com/api/qt/stock/get?secid=1.${code}&fields=f43,f44,f45,f46,f47,f48,f49,f50,f51,f52,f57,f58,f59,f60,f169,f170,f171`;
    } else {
      // 基金: 天天基金网
      url = `https://fund.eastmoney.com/pingzhongdata/${code}.js?v=${Date.now()}`;
    }
    
    const req = https.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          if (isStock) {
            const json = JSON.parse(data);
            if (json.data && json.data.f43) {
              // 股票价格 (分转元)
              const price = json.data.f43 / 1000;
              resolve(price);
            } else {
              reject(new Error('股票数据解析失败'));
            }
          } else {
            // 基金净值 - 从JS中提取
            const match = data.match(/,\s*gsz\s*:\s*"([\d.]+)"/);
            if (match) {
              resolve(parseFloat(match[1]));
            } else {
              reject(new Error('基金数据解析失败'));
            }
          }
        } catch (e) {
          reject(e);
        }
      });
    });
    
    req.on('error', reject);
    req.setTimeout(10000, () => {
      req.destroy();
      reject(new Error('请求超时'));
    });
  });
}

/**
 * 检查价格是否在区间内
 */
function checkIntervals(price, intervals) {
  const triggered = [];
  for (const interval of intervals) {
    if (price >= interval.min && price <= interval.max) {
      triggered.push(interval.desc);
    }
  }
  return triggered;
}

/**
 * 加载状态
 */
function loadState() {
  try {
    if (fs.existsSync(STATE_FILE)) {
      return JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'));
    }
  } catch (e) {
    console.error('加载状态失败:', e);
  }
  return {};
}

/**
 * 保存状态
 */
function saveState(state) {
  fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
}

/**
 * 发送Feishu消息
 */
function sendFeishuMessage(message) {
  return new Promise((resolve, reject) => {
    // 这里需要通过OpenClaw的message工具发送
    // 由于是定时任务，我们把通知写入一个队列文件，由主进程处理
    const queueFile = path.join(__dirname, 'notify-queue.json');
    try {
      let queue = [];
      if (fs.existsSync(queueFile)) {
        queue = JSON.parse(fs.readFileSync(queueFile, 'utf8'));
      }
      queue.push({
        time: new Date().toISOString(),
        message
      });
      fs.writeFileSync(queueFile, JSON.stringify(queue, null, 2));
      console.log('通知已加入队列:', message);
      resolve();
    } catch (e) {
      reject(e);
    }
  });
}

// ============ 主逻辑 =============

async function checkAll() {
  const now = new Date();
  const hour = now.getHours();
  const minute = now.getMinutes();
  
  // 检查是否在交易时段 (A股: 9:30-11:30, 13:00-15:00)
  const isTradingTime = (
    (hour === 9 && minute >= 30) || (hour >= 10 && hour < 11) || (hour === 11 && minute <= 30) ||
    (hour >= 13 && hour < 15)
  );
  
  if (!isTradingTime) {
    console.log(`[${now.toLocaleString()}] 非交易时段，跳过`);
    return;
  }
  
  console.log(`[${now.toLocaleString()}] 开始检查...`);
  
  const state = loadState();
  if (!state.triggered) state.triggered = {};
  
  let notifyList = [];
  
  for (const [code, config] of Object.entries(STOCKS)) {
    try {
      const price = await fetchPrice(code);
      console.log(`${config.name}: ${price}`);
      
      const triggeredIntervals = checkIntervals(price, config.intervals);
      
      if (triggeredIntervals.length > 0) {
        // 检查是否已通知过
        const triggerKey = `${code}-${triggeredIntervals.join(',')}`;
        
        if (!state.triggered[triggerKey]) {
          const msg = `【价格提醒】${config.name} 当前价格: ${price}，触发区间: ${triggeredIntervals.join('、')}`;
          notifyList.push(msg);
          state.triggered[triggerKey] = true;
          console.log(`  -> 触发通知: ${msg}`);
        } else {
          console.log(`  -> 已通知过，跳过`);
        }
      }
    } catch (e) {
      console.error(`${config.name} 获取价格失败:`, e.message);
    }
  }
  
  // 保存状态
  saveState(state);
  
  // 发送通知
  if (notifyList.length > 0) {
    const fullMessage = '\n' + notifyList.join('\n');
    console.log('准备发送通知:', fullMessage);
    
    // 输出通知消息（供主进程发送）
    console.log('=== NOTIFY_START ===');
    console.log(fullMessage);
    console.log('=== NOTIFY_END ===');
  }
}

// 立即执行一次
checkAll().then(() => {
  console.log('检查完成');
}).catch(e => {
  console.error('检查失败:', e);
  process.exit(1);
});
