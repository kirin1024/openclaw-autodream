# MEMORY.md - Chen 的长期记忆

- 任何任务如果过程中需要打开浏览器的，任务完成后必须关闭对应的浏览器tab
- **持仓产品价格**：一律获取**场内实时价格**（不是场外净值），通过财经网站（东方财富/同花顺）ETF行情页面抓取

## 持仓记录

### 紫金矿业 (601899)
- 持仓：1100股
- 成本：35.9476元
- 关注价位：33元以下可考虑加仓
- 止损位：32元

### 白银161226
- 持仓：1000股
- 成本：3.6003元
- 不记一次性的小事，只记：
  - 长期目标和重要项目
  - 明确的偏好（比如工具/风格/安全边界）
  - 重要决策及其原因

---

## 待完成项目

### AI/LLM 实战课程
- **图片来源**：memory/ai-course/course-source-image.jpg
- **课程内容**：10个完整项目（见图片详情）
- **当前进度**：项目1已完成网页，项目2-10待开发
- **目标**：帮助有前端经验的开发者快速上手AI/LLM应用开发
- **课程来源**：10个实战项目大纲（见附件图片）
- **状态**：待开始
- **当前阶段**：概念讲解已完成（语音+文档）
- **飞书文档**：[AI课程/项目1-意图识别](https://feishu.cn/docx/OCfad2VUaodARMxVuxecSl0HnrU)
- **复习笔记**：[AI课程复习笔记-项目一](https://feishu.cn/docx/VjIQdXCOgoe1k4xW3pzcMUBenph)（用于复习和检查学习掌握情况）
- **飞书文档**：项目二 [文本匹配与智能问答](https://feishu.cn/docx/Xrd0dxmbGooZKNxmBQLcqZb7nCf)
- **飞书文档**：项目三 [多模态内容理解与检索](https://feishu.cn/docx/BG7Xdd2t8om9Q5xazvicoNdAnvc)
- **飞书文档**：项目四 [企业级智能客服系统RAG](https://feishu.cn/docx/ClP2dRWZOolICExHtYKcj0cun3x)
- **执行方式**：每次对话推进1-2个项目
- **教学风格要求**：
  - 风格生动有趣，避免枯燥
  - 结合前端背景类比讲解
  - 每个知识点配合真实使用案例
  - 逐个讲解技术点，配合代码示例
- **复习笔记记录规则**：
  - 讲解过程中陈老师问的问题和回答内容，需记录到复习笔记（无需在对话里直接回复显示）
  - **自动规则**：针对某个课程项目提问后，回答自动记录到对应项目的复习笔记（如果不存在就新建）
- **课程复习笔记汇总**：
  - 项目一：https://feishu.cn/docx/VjIQdXCOgoe1k4xW3pzcMUBenph
  - 项目二：https://feishu.cn/docx/Ng6gdNQp4oBCoPx7tGSclISdnTg
  - 项目三：https://feishu.cn/docx/AawWd71ynoU79ZxUcOIcVT5enab

### 定时任务要求
- **A股收盘简报**：需要增加AI ETF 515070（华夏中证人工智能主题ETF）的表现
- **课程内容设计**：

#### 定制化课程大纲（面向前端开发者）

**阶段一：基础入门（第1-2周）**
- 项目1：意图识别技术与实战 ✅ 已完成
  - 前端视角：把NLP理解为"用户行为分析"
  - 实战：用BERT做简单文本分类
- 项目2：文本匹配与智能问答 ✅ 已完成
  - 前端视角：类似搜索补全、智能提示
  - 实战：搭建简单FAQ系统

**阶段二：核心技能（第3-5周）**
- 项目3：多模态内容理解 🔥 进行中
  - 前端视角：图像识别 + 文字理解
  - 实战：用CLIP做图片相似度匹配
  - 已学：CLIP模型、多模态融合技术、Transformer/ViT
- 项目4：RAG与智能客服 ⏳ 待开始
  - **重点推荐**！前端最常用
  - 实战：搭建企业知识库问答系统

**阶段三：进阶实战（第6-8周）**
- 项目5：PDF智能公式与计算
- 项目6：Agent与自动化工作流
- 项目7：Dify低代码开发

**阶段四：高级应用（第9-10周）**
- 项目8：ChatBI智能分析
- 项目9：信息抽取与知识图谱
- 项目10：金融研报生成系统

#### 关键提醒
- 每次开始新项目前，先确认：陈老师你目前的前端基础（React/Vue? Node?）
- 每个项目需要明确：学完能做什么"可展示"的成果
- 建议从项目4（RAG智能客服）开始，对前端最实用

## 待完成项目

### 个人持仓管理系统
- **关键词**：个人投资系统、持仓管理系统、asset-monitor
- **需求文档**：`memory/projects/asset-monitor-requirements.md`
- **状态**：需求讨论完成，待实现
- **执行 agent**：大金主（invest-advisor）
- **当前阶段**：第一阶段（持仓统计）

---

## 子 Agent 消息发送规则（2026-03-24 确认，适用所有子 Agent）

**规则**：所有子 agent（狗子、小学、大金主等）均不得直接发送飞书消息到群，须由首席牛马官作为消息代理。

**原因**：子 agent 用 `runtime=subagent` 模式时无法直接发送飞书消息（dmPolicy 沙盒限制）。

**架构**：
1. 群消息 → 路由到首席牛马官（main）
2. main 调度对应子 agent 获取内容
3. 子 agent 返回内容给 main
4. main 在内容末尾附加 Token 统计后发送到飞书群

**Token 统计**：由 main（首席牛马官）执行，格式：`[📊 Tokens: xxx in / xxx out | 模型: xxx]`

---

## 小学（AI课程助教）架构（2026-03-25）

**实际机制**：`sessions_spawn` 临时唤起模式，非持续监听

**路由流程**：
1. 群消息 → main（关键词识别）
2. 命中课程关键词 → main spawn 小学（mode=run）
3. 小学处理完 → announce 结果回 main
4. main 发送到群 + 附加 token 统计

**路由触发关键词**（命中则转发小学处理）：
- 通用：课程、项目、学习、教程、答疑、AI、LLM
- 项目词：项目1-10、RAG、CLIP、意图识别、文本匹配、多模态、智能客服
- 技术词：知识库、向量数据库、Embedding、Transformer、BERT
- Coursera/TensorFlow：tensorflow、coursera、andrew ng
- 飞书文档：意图识别、智能问答、多模态、RAG

**消息格式**：
```
【课程问题】
发送者：{sender_name}
内容：{message_content}

---学习档案---
{learning-profile.md 内容}
```

**token 统计**：由 main 附加，格式：`[📊 Tokens: xxx in / xxx out | 模型: xxx]`

**学习档案**：`~/.openclaw/workspace-small-school/learning-profile.md`

**默认课程约定**：陈老师不特殊说明时，默认问题针对【AI/LLM 实战课程】（自建课程）