# 子 Agent 架构

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

**群消息直接调度规则（2026-04-04 确认）**：
- 本飞书群（oc_33f53851e81183f1f33ed453398cf25c）：**所有会话**直接调度小学处理，不再做关键词预筛
- 陈老师明确要求：后续每一次会话都直接调度小学

## 飞书文档追加规范
- 避免一次性追加大块 markdown
- 建议分段追加（每次 8–13 个 blocks 左右）
- 若首次追加失败，优先改为分段策略重试

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

---任务要求---
1. 处理用户的课程问题
2. 回答完成后，**必须**调用 feishu_doc (action=append) 将回答内容写入对应项目的复习笔记
3. 复习笔记文档：
   - 项目一：OCfad2VUaodARMxVuxecSl0HnrU
   - 项目二：Xrd0dxmbGooZKNxmBQLcqZb7nCf
   - 项目三：AawWd71ynoU79ZxUcOIcVT5enab
   - 项目四：ClP2dRWZOolICExHtYKcj0cun3x
4. 写入格式：在复习笔记末尾追加内容，记录问题和回答
```

**token 统计**：由 main 附加，格式：`[📊 Tokens: xxx in / xxx out | 模型: xxx]`

**学习档案**：`~/.openclaw/workspace-small-school/learning-profile.md`

**默认课程约定**：陈老师不特殊说明时，默认问题针对【AI/LLM 实战课程】（自建课程）

**复习文档补充规则**：小学回答的 AI 课程 Q&A 内容，由 main（首席牛马官）负责补充到复习文档。小学可能无法稳定调用 feishu_doc，所以 main 在转发小学回复后，应主动将 Q&A 内容追加到对应项目的复习笔记。

---

## Agent 模型配置
| Agent | 模型 | 渠道 |
|-------|------|------|
| 牛马 main | self/claude-opus-4-6 | simpleai Claude API |
| 狗子 (work-assistant) | minimax-portal/MiniMax-M2.5 | MiniMax 官方 |
| 大金主 (invest-advisor) | minimax-portal/MiniMax-M2.5 | MiniMax 官方 |
| 小学 (small-school) | minimax-portal/MiniMax-M2.5 | MiniMax 官方 |
| 麒文 (qiwen) | claude-haiku-4-5-20251001 | 第三方 Claude API |

## 麒文回复规范
- 每次回复末尾必须附带 token 统计（调用 session_status 获取）

## GitHub Push 工作流
- 默认不能擅自 push 到远程
- 需要用户明确授权才能 push
- 流程：用户需求 → 本地修改 → 用户确认 → 授权后 push

## Memory 更新原则
- 代码行为 > Memory 描述（以代码为准）
- Memory 是记忆摘要，不是配置源
- 重要配置需标注版本锚点或有效期
