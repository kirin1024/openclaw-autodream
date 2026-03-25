# AI/LLM 实战课程详细大纲（面向前端开发者）

## 课程定位

**目标人群**：有前端开发经验（Vue），但无AI开发经验

**独特视角**：每节课都从"这个技术在前端怎么用"切入

**学习方式**：理论 + 实战，每课一个可展示成果

---

## 阶段一：AI基础入门（第1-2周）

### 项目一：意图识别技术与实战

**预计时长**：7天

#### 1.1 课程目标
理解NLP是什么，能用AI判断用户说话的目的。

#### 1.2 详细课程内容

**Day 1：NLP与前端的关系**
- 什么是自然语言处理
- 前端场景：搜索推荐、客服机器人、语音助手
- 演示：用现成API体验意图识别

**Day 2：文本特征提取方法**
- TF-IDF：统计词频（前端类比：关键词高亮）
- Word2Vec：词向量（前端类比：emoji向量空间）
- BERT：上下文理解（前端类比：理解用户真实意图vs字面意思）

**Day 3：分类模型对比**
- 传统方法：TF-IDF + 朴素贝叶斯
- 轻量级：FastText
- 时序模型：LSTM
- 大模型：BERT / Qwen
- **前端选型建议**：简单场景用FastText，复杂场景用BERT API

**Day 4：数据处理与标注**
- 数据清洗：去停用词、大小写统一
- 标注工具：Label Studio
- 数据格式：JSONL

**Day 5：模型训练与优化**
- 交叉验证
- 超参数调优
- 模型轻量化：ONNX转换

**Day 6-7：实战项目**

##### 实战：客服意图分类器

**需求**：
```
用户输入一段文字 → 判断属于以下哪种类别：
- 查订单 (order_query)
- 退货退款 (refund)
- 投诉 (complaint)
- 咨询产品 (product咨询)
- 其他 (other)
```

**技术栈**：
- 后端：Python + Transformers
- 前端：Vue + 输入框 + 结果展示

**代码示例**：
```python
# 后端API (FastAPI)
from transformers import pipeline

classifier = pipeline("zero-shot-classification")

def classify_intent(text):
    result = classifier(
        text,
        candidate_labels=["查订单", "退货退款", "投诉", "咨询产品"]
    )
    return result["labels"][0]
```

**前端Demo**：
```
┌─────────────────────────────┐
│  请输入您的问题：           │
│  ┌─────────────────────┐   │
│  │ 我想查一下我的订单   │   │
│  └─────────────────────┘   │
│         [提交]              │
│                             │
│  识别结果：查订单 (92%)    │
│  置信度：92%               │
└─────────────────────────────┘
```

#### 1.3 交付物
- [ ] FastAPI后端服务（意图识别API）
- [ ] Vue前端Demo
- [ ] Docker部署配置

---

### 项目二：文本匹配与智能问答

**预计时长**：7天

#### 2.1 课程目标
实现"用户问问题，系统找答案"的智能问答。

#### 2.2 详细课程内容

**Day 1：文本匹配技术发展**
- 传统搜索：TF-IDF、BM25（基于词频统计）
- 语义搜索：Sentence-BERT（基于向量相似度）
- 大模型搜索：Instructor（带指令的嵌入）

**Day 2：向量数据库**
- 什么是向量
- FAISS、Qdrant、Milvus对比
- 前端类比：就像一个"语义搜索引擎"

**Day 3：智能问答技术演进**
- FAQ匹配：检索式问答
- 阅读理解MRC：从文档中抽答案
- RAG：检索增强生成（本项目重点）

**Day 4：相似度计算**
- 余弦相似度
- 点积相似度
- 如何筛选Top-K结果

**Day 5：实战：FAQ系统架构设计**
- 数据存储：向量库 + 原文档
- 查询流程：用户问题 → 向量化 → 检索 → 返回

**Day 6-7：实战项目**

##### 实战：企业内部FAQ问答系统

**需求**：
```
- 上传FAQ文档（Q&A格式）
- 用户输入问题
- 返回最匹配的答案
```

**技术栈**：
- 后端：Python + sentence-transformers + Qdrant
- 前端：Vue + 搜索框 + 答案卡片

**代码示例**：
```python
# 向量化
from sentence_transformers import SentenceTransformer

model = SentenceTransformer('paraphrase-multilingual-MiniLM-L12-v2')

def embed_text(text):
    return model.encode(text)

# 检索
def search(query, top_k=3):
    query_vector = embed_text(query)
    results = qdrant.search(
        query_vector=query_vector,
        limit=top_k
    )
    return results
```

**前端Demo**：
```
┌─────────────────────────────────────┐
│  🔍 搜索问题...                     │
│  ┌─────────────────────────────┐   │
│  │ 如何申请年假？               │   │
│  └─────────────────────────────┘   │
│                                     │
│  最匹配的答案：                     │
│  ┌─────────────────────────────┐   │
│  │ 年假申请流程：               │   │
│  │ 1. 登录OA系统               │   │
│  │ 2. 进入"我的假期"           │   │
│  │ 3. 点击"申请年假"           │   │
│  │ 4. 填写日期并提交           │   │
│  └─────────────────────────────┘   │
│  相似度：85%                       │
└─────────────────────────────────────┘
```

#### 2.3 交付物
- [ ] FAQ问答后端API
- [ ] Vue前端Demo
- [ ] 向量数据库配置
- [ ] 部署文档

---

## 阶段二：核心技能（第3-5周）

### 项目三：多模态内容理解与检索

**预计时长**：5天

#### 3.1 课程目标
让AI能理解图片，实现"以图搜图"。

#### 3.2 详细课程内容

**Day 1：多模态基础**
- 什么是多模态
- 应用场景：电商搜索、内容审核、自动驾驶
- 前端场景：图片搜索、视觉问答

**Day 2：CLIP模型原理**
- CLIP如何学习图像-文本对应关系
- 零样本分类能力
- 前端类比：就像给图片打"语义标签"

**Day 3：图像特征提取**
- ViT（Vision Transformer）
- ResNet特征
- 向量表示

**Day 4：向量检索实战**
- 特征存储：FAISS
- 相似度匹配
- 结果排序

**Day 5：实战项目**

##### 实战：商品图片搜索

**需求**：
```
- 上传一张图片
- 返回相似商品
```

**技术栈**：
- 后端：Python + CLIP + FAISS
- 前端：Vue + 图片上传 + 网格展示

**代码示例**：
```python
import torch
from transformers import CLIPProcessor, CLIPModel

model = CLIPModel.from_openai("openai/clip-vit-base-patch32")
processor = CLIPProcessor.from_openai("openai/clip-vit-base-patch32")

def search_similar_images(query_image):
    # 提取图片向量
    inputs = processor(images=query_image, return_tensors="pt")
    image_features = model.get_image_features(**inputs)
    
    # 检索
    results = faiss.search(image_features, k=10)
    return results
```

#### 3.3 交付物
- [ ] 图片搜索后端API
- [ ] Vue前端Demo（拖拽上传）
- [ ] 示例图片库

---

### 项目四：RAG与大模型智能客服（⭐重点）

**预计时长**：10天

#### 4.1 课程目标
搭建可回答私域问题的智能客服，解决大模型幻觉问题。

#### 4.2 详细课程内容

**Day 1：为什么需要RAG**
- 大模型的局限性：知识截止、幻觉、私域知识
- RAG工作流程图解
- 适用场景

**Day 2：文档处理**
- PDF解析：PyPDF2、pdfplumber
- Word解析：python-docx
- 网页解析：BeautifulSoup
- 文本分Chunk：如何科学切分长文档

**Day 3：向量化**
- Embedding模型选择
- BGE、M3E介绍
- 批量向量化

**Day 4：向量检索**
- 相似度检索
- 混合检索（BM25 + 向量）
- 重排序：Cross-Encoder

**Day 5：大模型集成**
- API调用：OpenAI、文心一言
- 本地部署：Ollama
- Prompt设计技巧

**Day 6-8：实战项目**

##### 实战：企业知识库问答系统

**需求**：
```
- 上传企业文档（PDF/Word/MD）
- 用户提问，基于文档回答
- 附上参考来源
```

**完整技术栈**：
```
文档处理：PyPDF2 → 文本分Chunk → BGE向量化 → Qdrant存储
                          ↓
用户问题 → 向量化 → Qdrant检索 → 上下文组装 → GPT-4生成 → 返回答案
```

**代码架构**：
```python
# RAG核心流程
class RAGSystem:
    def __init__(self):
        self.embedding_model = load_bge_model()
        self.vector_store = QdrantClient()
        self.llm = ChatOpenAI()
    
    def ingest(self, documents):
        chunks = self.chunk_documents(documents)
        vectors = self.embedding_model.encode(chunks)
        self.vector_store.add(vectors, chunks)
    
    def query(self, question):
        question_vector = self.embedding_model.encode(question)
        context = self.vector_store.search(question_vector)
        
        prompt = f"""基于以下上下文回答问题。
        
上下文：
{context}

问题：{question}
"""
        answer = self.llm.chat(prompt)
        return answer
```

**前端Demo**：
```
┌─────────────────────────────────────────────────┐
│  🤖 企业智能客服                                │
│  ┌─────────────────────────────────────────┐   │
│  │                                         │   │
│  │  你们公司的年假政策是什么？              │   │
│  │                                         │   │
│  └─────────────────────────────────────────┘   │
│                                                 │
│  根据您上传的文档，回答如下：                   │
│                                                 │
│  公司年假政策如下：                             │
│  1. 入职满1年享5天年假                         │
│  2. 入职满3年享10天年假                         │
│  3. 入职满5年享15天年假                         │
│                                                 │
│  📎 参考来源：员工手册第3章                     │
└─────────────────────────────────────────────────┘
```

**Day 9-10：生产优化**
- 缓存策略
- 多轮对话
- 追问功能
- 部署上线

#### 4.3 交付物
- [ ] RAG后端API
- [ ] Vue前端Demo（对话界面）
- [ ] 部署配置（Docker + Nginx）
- [ ] 使用文档
- [ ] 代码仓库

---

### 项目五：PDF方程式识别与计算

**预计时长**：7天

#### 5.1 课程目标
从PDF中提取数学公式并进行计算。

#### 5.2 详细课程内容

**Day 1：PDF解析基础**
- PyPDF2、pdfminer使用
- 提取文本和布局

**Day 2-3：公式检测**
- 图像处理基础
- 形态学处理检测公式区域
- PaddleOCR使用

**Day 4：公式识别**
- Mathpix API使用
- LaTeX格式转换
- 公式渲染：KaTeX / MathJax

**Day 5：自然语言转公式**
- 用LLM解析"计算x的平方加1"
- Prompt设计

**Day 6-7：实战项目**

##### 实战：数学作业批改助手

**功能**：
```
- 上传包含数学题的PDF
- 自动识别公式
- 判断答案对错
- 打分
```

#### 5.3 交付物
- [ ] PDF解析工具
- [ ] 公式识别API
- [ ] 批改前端Demo

---

## 阶段三：进阶实战（第6-8周）

### 项目六：Agent与自动化工作流

**预计时长**：7天

#### 6.1 课程目标
让AI能使用工具，完成复杂任务。

#### 6.2 详细课程内容

**Day 1：Agent基础**
- 什么是Agent
- Agent vs 普通问答

**Day 2：LangChain核心**
- Chains
- Agents
- Tools
- Memory

**Day 3：提示工程进阶**
- Chain-of-Thought
- ReAct
- Self-consistency

**Day 4：Function Calling**
- 定义工具
- API集成
- 天气查询、搜索等

**Day 5-7：实战项目**

##### 实战：旅行规划Agent

**功能**：
```
输入：我想去日本玩5天，预算5000元
输出：
- 行程安排（每天去哪）
- 酒店推荐
- 预算分配
- 注意事项
```

**技术栈**：
- LangChain
- SerpAPI（搜索）
- 天气API

#### 6.3 交付物
- [ ] 旅行规划Agent
- [ ] Web界面
- [ ] 代码仓库

---

### 项目七：Dify智能开发与应用

**预计时长**：7天

#### 7.1 课程目标
用Dify可视化快速构建AI应用。

#### 7.2 详细课程内容

**Day 1：Dify介绍**
- 什么是Dify
- 对比LangChain
- 安装部署

**Day 2：基础操作**
- 创建应用
- Prompt编排
-变量使用

**Day 3-4：RAG配置**
- 文档上传
- 文本分块
- 检索设置

**Day 5：工作流**
- 条件分支
- 节点串联
- 多模型组合

**Day 6-7：实战项目**

##### 实战：智能招聘助手

**功能**：
```
- 上传简历PDF
- 自动提取关键信息
- 生成面试问题
```

#### 7.3 交付物
- [ ] Dify工作流
- [ ] 部署的在线应用
- [ ] 使用文档

---

## 阶段四：高级应用（第9-10周）

### 项目八：ChatBI智能分析与可视化

**预计时长**：5天

#### 8.1 课程目标
用自然语言查询数据库。

#### 8.2 详细课程内容

**Day 1：NL2SQL原理**
- 文本转SQL
- Schema理解

**Day 2-3：可视化集成**
- ECharts
- 数据格式化

**Day 4-5：实战项目**

##### 实战：销售数据分析看板

**功能**：
```
自然语言：上个月销售额是多少？
返回：表格 + 图表
```

#### 8.3 交付物
- [ ] NL2SQL API
- [ ] 数据大屏
- [ ] 代码仓库

---

### 项目九：信息抽取与知识图谱

**预计时长**：7天

#### 9.1 课程目标
从文本中提取结构化知识。

#### 9.2 详细课程内容

**Day 1-2：NER**
- 命名实体识别
- BiLSTM-CRF
- LLM抽取

**Day 3-4：知识图谱**
- Neo4j使用
- Cypher查询
- 图谱设计

**Day 5-7：实战项目**

##### 实战：企业知识图谱

**功能**：
```
- 输入：新闻文章
- 输出：提取的实体和关系
- 可视化：图谱展示
```

#### 9.3 交付物
- [ ] Neo4j图谱
- [ ] 问答界面
- [ ] 代码仓库

---

### 项目十：金融研报生成系统

**预计时长**：7天

#### 10.1 课程目标
自动生成金融研究报告。

#### 10.2 详细课程内容

**Day 1-2：多Agent架构**
- 策划Agent
- 数据Agent
- 分析Agent
- 写作Agent

**Day 3-4：MCP协议**
- 什么是MCP
- 工具集成

**Day 5-7：实战项目**

##### 实战：简版研报生成

**输入**：股票代码（如600519）

**输出**：
```
# 贵州茅台研报

## 一、公司概况
...

## 二、财务分析
...

## 三、投资建议
...
```

#### 10.3 交付物
- [ ] 研报生成系统
- [ ] 示例研报
- [ ] 代码仓库

---

## 课程资源清单

### 环境准备

**后端环境**：
- [ ] Python 3.10+
- [ ] Node.js 18+
- [ ] Docker Desktop

**AI工具**：
- [ ] OpenAI API Key（或 文心一言 / Ollama）
- [ ] HuggingFace账号

**数据库**：
- [ ] Qdrant（向量库）
- [ ] Neo4j（图数据库，可选）

### 推荐学习顺序

```
第1周 → 项目1：意图识别（最基础）
第2周 → 项目2：FAQ问答（理解检索）
第3周 → 项目3：多模态（图搜图）
第4-5周 → 项目4：RAG（⭐最重要，立刻能用）
第6周 → 项目6：Agent（进阶）
第7周 → 项目7：Dify（快速出成果）
第8周 → 项目5/8/9/10（按兴趣选）
```

---

## 进度追踪表

| 项目 | 名称 | 状态 | 开始 | 结束 | 备注 |
|------|------|------|------|------|------|
| 1 | 意图识别 | ⬜ | - | - | |
| 2 | 文本匹配与问答 | ⬜ | - | - | |
| 3 | 多模态 | ⬜ | - | - | |
| 4 | RAG智能客服 | ⬜ | - | - | ⭐推荐先学 |
| 5 | PDF公式识别 | ⬜ | - | - | |
| 6 | Agent工作流 | ⬜ | - | - | |
| 7 | Dify低代码 | ⬜ | - | - | |
| 8 | ChatBI | ⬜ | - | - | |
| 9 | 知识图谱 | ⬜ | - | - | |
| 10 | 金融研报 | ⬜ | - | - | |

---

*最后更新：2026-03-17*
